// [2026-11 추가 검수 지시 — "LLM 호출 실패 시 100P 차감 정책 재검토"] 실제
// Anthropic API 키를 일시적으로 무효화한 상태(.env 백업/복원은 호출 스크립트
// 바깥에서 수행)에서, 실제 HTTP unlock 호출이 LLM 전체 실패 → fallback →
// 자동 환불까지 end-to-end로 이어지는지 검증한다. 서비스 함수 단위 테스트
// (TEST 6, dev-test-gunghap-llm-unlock.ts)와 달리, 이 스크립트는 실제
// POST /unlock 라우트를 통해 "실제로 환불이 Wallet/PointHistory에 반영되고
// 응답에 refunded:true가 포함되는지"까지 확인한다.
//
// 실행 전제: .env의 ANTHROPIC_APP_API_KEY가 무효한 값으로 교체된 상태로
// dev 서버가 재시작되어 있어야 한다(실제 LLM 호출이 반드시 실패하도록).
//
// 실행: npx tsx --env-file=.env scripts/dev-test-gunghap-refund.ts
import { prisma } from "../src/lib/db";
import { calculateSaju, guinjiSajuInputFromManseryeok } from "../src/lib/saju-manseryeok-engine";
import { SignJWT } from "jose";

const secretKey = process.env.SESSION_SECRET;
if (!secretKey) throw new Error("SESSION_SECRET 환경변수가 필요합니다(.env 확인).");
const encodedKey = new TextEncoder().encode(secretKey);

async function signUserToken(payload: { userId: number; nickname: string }): Promise<string> {
  return new SignJWT(payload)
    .setProtectedHeader({ alg: "HS256" })
    .setIssuedAt()
    .setExpirationTime("30d")
    .sign(encodedKey);
}

const BASE_URL = "http://localhost:3000";

let failed = false;
function assert(cond: boolean, msg: string) {
  if (cond) {
    console.log(`  ✅ ${msg}`);
  } else {
    console.error(`  ❌ ${msg}`);
    failed = true;
  }
}

async function ensureTestUser(params: { nickname: string; email: string; gender?: string }) {
  const user = await prisma.user.upsert({
    where: { email: params.email },
    update: { gender: params.gender ?? undefined },
    create: {
      email: params.email,
      nickname: params.nickname,
      gender: params.gender ?? null,
      passwordHash: "test-only-hash",
      status: "active",
    },
  });
  return user;
}

async function setWalletBalance(userId: number, balance: number) {
  await prisma.gunghapUnlockRecord.deleteMany({ where: { userId } });
  const existing = await prisma.wallet.findFirst({ where: { userId, currencyType: "POINT" } });
  const wallet = await prisma.wallet.upsert({
    where: { id: existing?.id ?? -1 },
    update: { balance },
    create: { userId, currencyType: "POINT", balance },
  });
  return wallet;
}

async function callApi(
  method: string,
  path: string,
  token: string | null,
  body?: Record<string, unknown>,
): Promise<{ status: number; json: Record<string, unknown> | null }> {
  const headers: Record<string, string> = { "Content-Type": "application/json" };
  if (token) headers["Authorization"] = `Bearer ${token}`;
  const res = await fetch(`${BASE_URL}${path}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });
  const json = (await res.json().catch(() => null)) as Record<string, unknown> | null;
  return { status: res.status, json };
}

function sajuFor(opts: { year: number; month: number; day: number; gender: "male" | "female" }) {
  const m = calculateSaju({ year: opts.year, month: opts.month, day: opts.day, gender: opts.gender, timeUnknown: true });
  return guinjiSajuInputFromManseryeok(m);
}

async function main() {
  console.log("=== 궁합지도 LLM 실패 → 자동 환불 E2E 검증(실제 무효 API 키 사용) ===\n");

  const owner = await ensureTestUser({
    nickname: `gh_refund_owner_${Date.now()}`,
    email: `gh_refund_owner_${Date.now()}@example.com`,
    gender: "male",
  });
  const token = await signUserToken({ userId: owner.id, nickname: owner.nickname });
  await setWalletBalance(owner.id, 1000);

  const mySaju = sajuFor({ year: 1991, month: 6, day: 15, gender: "male" });

  const r0 = await callApi("POST", "/api/public/gunghap/direct", token, {
    requestKey: `test_refund_${Date.now()}`,
    mySaju,
    myName: "환불테스트오너",
    partnerName: "환불테스트상대",
    partnerBirthDate: "1993-09-09",
    partnerCalendarType: "solar",
    partnerGender: "female",
    majorId: "love",
  });
  if (r0.status !== 200 && r0.status !== 201) {
    throw new Error(`direct 생성 실패 status=${r0.status} json=${JSON.stringify(r0.json)}`);
  }
  const resultId = (r0.json?.data as { resultId: string }).resultId;
  const dbIdNum = Number(resultId.replace("gr_", ""));
  console.log(`  생성된 resultId = ${resultId}`);

  const walletBefore = await prisma.wallet.findFirst({ where: { userId: owner.id, currencyType: "POINT" } });
  console.log(`  unlock 호출 전 잔액: ${walletBefore?.balance}`);

  const t0 = Date.now();
  const r1 = await callApi("POST", `/api/public/gunghap/results/${resultId}/unlock`, token);
  const elapsed = Date.now() - t0;
  console.log(`  unlock 응답 ${r1.status} (소요 ${elapsed}ms)`);

  assert(r1.status === 200, `unlock 200 (실제 ${r1.status})`);
  const d1 = r1.json?.data as
    | { amountCharged: number; llmSource: string; refunded: boolean; detail: Array<Record<string, unknown>> }
    | undefined;
  console.log(`  [증거] 응답 전체: ${JSON.stringify(r1.json?.data, null, 2)}`);

  assert(d1?.llmSource === "template", `실제 LLM 호출 실패로 llmSource="template"(fallback) (실제 ${d1?.llmSource})`);
  assert(d1?.refunded === true, `LLM 실패로 인한 자동 환불 플래그 refunded=true (실제 ${d1?.refunded})`);
  assert(Array.isArray(d1?.detail) && d1!.detail.length === 1, "fallback detail도 정상적으로 1건 반환(빈 결과 아님)");

  // ── DB 레벨 검증: Wallet 복구 + PointHistory 환불 기록 ──
  const walletAfter = await prisma.wallet.findFirst({ where: { userId: owner.id, currencyType: "POINT" } });
  assert(
    walletAfter!.balance === walletBefore!.balance,
    `환불로 인해 최종 잔액이 unlock 호출 전과 동일(순액 0 변동) (호출전=${walletBefore?.balance}, 호출후=${walletAfter?.balance})`,
  );

  const chargeHistory = await prisma.pointHistory.findFirst({
    where: { userId: owner.id, sourceType: "gunghap_detail_unlock", sourceId: dbIdNum },
    orderBy: { id: "desc" },
  });
  assert(chargeHistory?.amount === -100, `차감 PointHistory -100 기록 존재(차감 자체는 정상 수행됨) (실제 ${chargeHistory?.amount})`);

  const refundHistory = await prisma.pointHistory.findFirst({
    where: { userId: owner.id, sourceType: "gunghap_detail_unlock_refund", sourceId: dbIdNum },
    orderBy: { id: "desc" },
  });
  assert(refundHistory?.amount === 100, `환불 PointHistory +100 기록 존재 (실제 ${refundHistory?.amount})`);
  assert(refundHistory?.type === "earn", `환불 기록 type="earn" (실제 ${refundHistory?.type})`);
  console.log(
    `  [증거] 환불 PointHistory row: id=${refundHistory?.id} amount=${refundHistory?.amount} type=${refundHistory?.type} balanceAfter=${refundHistory?.balanceAfter} memo="${refundHistory?.memo}"`,
  );

  // ── 재열람 시에도 refunded=true가 유지되는지(캐시 경로, GET + POST 둘 다) ──
  const r2 = await callApi("POST", `/api/public/gunghap/results/${resultId}/unlock`, token);
  const d2 = r2.json?.data as { amountCharged: number; refunded: boolean } | undefined;
  assert(d2?.amountCharged === 0, `재열람 시 추가 차감 없음 (실제 ${d2?.amountCharged})`);
  assert(d2?.refunded === true, `재열람(POST) 시에도 refunded=true 유지(캐시 경로에서도 환불 이력 노출) (실제 ${d2?.refunded})`);

  const r3 = await callApi("GET", `/api/public/gunghap/results/${resultId}`, token);
  const d3 = r3.json?.data as { refunded?: boolean; unlocked?: boolean } | undefined;
  assert(d3?.unlocked === true, "GET 재열람에서도 unlocked=true");
  assert(d3?.refunded === true, `GET 재열람(/results/{resultId})에서도 refunded=true 노출 (실제 ${d3?.refunded})`);

  // ── 환불이 중복으로 2번 일어나지 않는지(멱등) ──
  const refundCountAfterSecondCall = await prisma.pointHistory.count({
    where: { userId: owner.id, sourceType: "gunghap_detail_unlock_refund", sourceId: dbIdNum },
  });
  assert(refundCountAfterSecondCall === 1, `환불은 정확히 1회만 수행됨(재열람으로 중복 환불 없음) (실제 ${refundCountAfterSecondCall}건)`);

  console.log("\n=== 테스트 종료 ===");
  if (failed) {
    console.error("❌ 일부 테스트 실패");
    process.exitCode = 1;
  } else {
    console.log("✅ 전체 테스트 통과");
  }
}

main()
  .catch((e) => {
    console.error("치명적 오류:", e);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
