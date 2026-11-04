// [2026-11 궁합 주제 반영 지시서 — Section 7/8 라이브 검증] unlock/route.ts의
// 실제 LLM 호출 + 캐시 + 멱등 차감 + 동시성 + fallback + 레거시 호환을
// 실행 중인 Next.js dev 서버(localhost:3000)에 실제 HTTP 요청으로 검증한다.
//
// [보안 — JWT 비밀키 비노출] SESSION_SECRET은 이 Node 프로세스 내부에서만
// signUserToken()에 사용되고, 콘솔에는 "생성된 JWT 문자열"만 출력한다(요청
// 헤더를 위한 용도). 비밀키 원문은 어떤 console.log에도 포함하지 않는다.
//
// 실행: npx tsx scripts/dev-test-gunghap-llm-unlock.ts
import { prisma } from "../src/lib/db";
import { calculateSaju, guinjiSajuInputFromManseryeok } from "../src/lib/saju-manseryeok-engine";
import { SignJWT } from "jose";

const secretKey = process.env.SESSION_SECRET;
if (!secretKey) throw new Error("SESSION_SECRET 환경변수가 필요합니다(.env 확인).");
// [보안] encodedKey/secretKey 원문은 아래 어떤 console.log/console.error에도
// 절대 출력하지 않는다 — 오직 signUserToken()이 반환하는 JWT 문자열만 사용한다.
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

async function createDirectResultWithTopic(
  token: string,
  mySaju: unknown,
  myName: string,
  partner: { name: string; birthDate: string; gender: "male" | "female" },
  majorId: string,
  requestKeySuffix: string,
): Promise<{ resultId: string }> {
  const r = await callApi("POST", "/api/public/gunghap/direct", token, {
    requestKey: `test_${requestKeySuffix}_${Date.now()}`,
    mySaju,
    myName,
    partnerName: partner.name,
    partnerBirthDate: partner.birthDate,
    partnerCalendarType: "solar",
    partnerGender: partner.gender,
    majorId,
  });
  if (r.status !== 200 && r.status !== 201) {
    throw new Error(`direct 생성 실패 status=${r.status} json=${JSON.stringify(r.json)}`);
  }
  const data = r.json?.data as { resultId: string } | undefined;
  if (!data?.resultId) throw new Error("resultId 없음");
  return { resultId: data.resultId };
}

async function main() {
  console.log("=== 궁합지도 LLM 유료 해석 라이브 검증 (10개 체크리스트) ===\n");

  const owner = await ensureTestUser({
    nickname: `gh_llm_owner_${Date.now()}`,
    email: `gh_llm_owner_${Date.now()}@example.com`,
    gender: "male",
  });
  const ownerToken = await signUserToken({ userId: owner.id, nickname: owner.nickname });
  await setWalletBalance(owner.id, 1000);

  const mySaju = sajuFor({ year: 1990, month: 5, day: 14, gender: "male" });

  // ─────────────────────────────────────────────────────────
  // TEST 1~4: 실제 LLM 호출 + 첫 unlock 100P 차감 + 2차 unlock 0P + 캐시 반환
  // ─────────────────────────────────────────────────────────
  console.log("TEST 1~4: 실제 LLM 호출 / 첫 unlock 100P / 재열람 0P / 캐시 반환");

  const { resultId } = await createDirectResultWithTopic(
    ownerToken,
    mySaju,
    "테스트오너",
    { name: "테스트상대", birthDate: "1992-08-20", gender: "female" },
    "love",
    "case1",
  );
  console.log(`  생성된 resultId = ${resultId}`);

  const dbIdNum = Number(resultId.replace("gr_", ""));
  const aiLogCountBefore = await prisma.aiRequestLog.count({ where: { domain: "gunghap", requestRefId: dbIdNum } });

  const walletBefore = await prisma.wallet.findFirst({ where: { userId: owner.id, currencyType: "POINT" } });
  const t0 = Date.now();
  const r1 = await callApi("POST", `/api/public/gunghap/results/${resultId}/unlock`, ownerToken);
  const elapsedMs1 = Date.now() - t0;
  assert(r1.status === 200, `첫 unlock 200 (실제 ${r1.status})`);
  const d1 = r1.json?.data as
    | { amountCharged: number; alreadyUnlocked: boolean; llmSource: string; detail: Array<Record<string, unknown>>; balanceAfter?: number }
    | undefined;
  assert(d1?.amountCharged === 100, `첫 unlock 100P 차감 (실제 ${d1?.amountCharged})`);
  assert(d1?.alreadyUnlocked === false, "첫 unlock은 alreadyUnlocked=false");
  console.log(`  llmSource = ${d1?.llmSource} (elapsed ${elapsedMs1}ms)`);
  assert(d1?.llmSource === "llm" || d1?.llmSource === "template", "llmSource는 llm 또는 template 중 하나");
  assert(Array.isArray(d1?.detail) && d1!.detail.length === 1, `단일 주제(love) 응답 1건 (실제 ${d1?.detail?.length})`);

  const walletAfter = await prisma.wallet.findFirst({ where: { userId: owner.id, currencyType: "POINT" } });
  assert(
    walletBefore!.balance - walletAfter!.balance === 100,
    `Wallet.balance 정확히 100 감소 (${walletBefore!.balance} → ${walletAfter!.balance})`,
  );
  const pointHistoryRow = await prisma.pointHistory.findFirst({
    where: { userId: owner.id, sourceType: "gunghap_detail_unlock", sourceId: dbIdNum },
    orderBy: { id: "desc" },
  });
  assert(pointHistoryRow?.amount === -100, "PointHistory에 -100 차감 내역 기록됨");
  console.log(
    `  [증거] PointHistory row: id=${pointHistoryRow?.id} amount=${pointHistoryRow?.amount} balanceAfter=${pointHistoryRow?.balanceAfter} memo="${pointHistoryRow?.memo}"`,
  );

  const aiLogCountAfterFirst = await prisma.aiRequestLog.count({ where: { domain: "gunghap", requestRefId: dbIdNum } });
  assert(aiLogCountAfterFirst === aiLogCountBefore + 1, `첫 unlock 시 AiRequestLog 1건 생성 (실제 증가량 ${aiLogCountAfterFirst - aiLogCountBefore})`);

  const dbRowAfterFirst = await prisma.gunghapPairResult.findUnique({ where: { id: dbIdNum } });
  assert(!!dbRowAfterFirst?.llmDetailJson, "DB에 llmDetailJson 캐시 저장됨");
  console.log(`  [증거] llmModel=${dbRowAfterFirst?.llmModel} llmSource=${dbRowAfterFirst?.llmSource} llmGeneratedAt=${dbRowAfterFirst?.llmGeneratedAt}`);
  console.log(`  [증거] 생성된 해석 텍스트 (TEST 1 — ${d1?.llmSource}):`);
  console.log(JSON.stringify(d1?.detail, null, 2));

  // ── TEST 2: 재열람(동일 resultId) — 추가 차감 0P, LLM 재호출 없음(캐시) ──
  console.log("\nTEST 2~4 계속: 재열람 시 0P 차감 + LLM 재호출 없음(캐시 반환)");
  const t1 = Date.now();
  const r2 = await callApi("POST", `/api/public/gunghap/results/${resultId}/unlock`, ownerToken);
  const elapsedMs2 = Date.now() - t1;
  assert(r2.status === 200, `재열람 200 (실제 ${r2.status})`);
  const d2 = r2.json?.data as { amountCharged: number; alreadyUnlocked: boolean; detail: unknown[] } | undefined;
  assert(d2?.amountCharged === 0, `재열람 추가 차감 0 (실제 ${d2?.amountCharged})`);
  assert(d2?.alreadyUnlocked === true, "재열람 alreadyUnlocked=true");
  console.log(`  재열람 소요시간 ${elapsedMs2}ms (1차 ${elapsedMs1}ms 대비 — 캐시 경로는 LLM 호출 없이 즉시 응답해야 함)`);

  const walletAfterRelook = await prisma.wallet.findFirst({ where: { userId: owner.id, currencyType: "POINT" } });
  assert(walletAfter!.balance === walletAfterRelook!.balance, "재열람 후 Wallet.balance 변동 없음");

  const aiLogCountAfterSecond = await prisma.aiRequestLog.count({ where: { domain: "gunghap", requestRefId: dbIdNum } });
  assert(aiLogCountAfterSecond === aiLogCountAfterFirst, `재열람 시 AiRequestLog 추가 생성 없음(LLM 재호출 안 함) (before=${aiLogCountAfterFirst}, after=${aiLogCountAfterSecond})`);

  const sameDetail = JSON.stringify(d1?.detail) === JSON.stringify(d2?.detail);
  assert(sameDetail, "재열람 시 1차와 동일한 detail(캐시) 반환");

  // ─────────────────────────────────────────────────────────
  // TEST 5: 동시 요청 — 중복 LLM 호출 및 중복 차감 방지
  // ─────────────────────────────────────────────────────────
  console.log("\nTEST 5: 동시 요청(5건 병렬) — 중복 LLM 호출 및 중복 차감 방지");
  const concurOwner = await ensureTestUser({
    nickname: `gh_llm_concur_${Date.now()}`,
    email: `gh_llm_concur_${Date.now()}@example.com`,
    gender: "female",
  });
  const concurToken = await signUserToken({ userId: concurOwner.id, nickname: concurOwner.nickname });
  await setWalletBalance(concurOwner.id, 1000);
  const concurSaju = sajuFor({ year: 1995, month: 7, day: 7, gender: "female" });
  const { resultId: concurResultId } = await createDirectResultWithTopic(
    concurToken,
    concurSaju,
    "동시테스트오너",
    { name: "동시테스트상대", birthDate: "1996-12-25", gender: "male" },
    "marriage",
    "concur",
  );
  const concurDbId = Number(concurResultId.replace("gr_", ""));
  const walletConcurBefore = await prisma.wallet.findFirst({ where: { userId: concurOwner.id, currencyType: "POINT" } });

  const concurrentResults = await Promise.all(
    Array.from({ length: 5 }, () => callApi("POST", `/api/public/gunghap/results/${concurResultId}/unlock`, concurToken)),
  );
  const successCount = concurrentResults.filter((r) => r.status === 200).length;
  assert(successCount === 5, `동시 요청 5건 모두 200 (실제 ${successCount})`);
  const totalCharged = concurrentResults.reduce(
    (sum, r) => sum + ((r.json?.data as { amountCharged?: number } | undefined)?.amountCharged ?? 0),
    0,
  );
  assert(totalCharged === 100, `동시 5건 중 실제 차감 합계는 100P뿐 (실제 합계 ${totalCharged})`);
  const walletConcurAfter = await prisma.wallet.findFirst({ where: { userId: concurOwner.id, currencyType: "POINT" } });
  assert(
    walletConcurBefore!.balance - walletConcurAfter!.balance === 100,
    `동시 요청 후 Wallet.balance 정확히 100 감소 (${walletConcurBefore!.balance} → ${walletConcurAfter!.balance})`,
  );
  const concurUnlockCount = await prisma.gunghapUnlockRecord.count({ where: { userId: concurOwner.id, resultId: concurDbId } });
  assert(concurUnlockCount === 1, `GunghapUnlockRecord 정확히 1건(중복 생성 없음) (실제 ${concurUnlockCount})`);
  const concurAiLogCount = await prisma.aiRequestLog.count({ where: { domain: "gunghap", requestRefId: concurDbId } });
  assert(concurAiLogCount === 1, `동시 요청에도 AiRequestLog는 1건만 생성(중복 LLM 호출 없음) (실제 ${concurAiLogCount})`);

  // ─────────────────────────────────────────────────────────
  // TEST 6: LLM 실패 시 fallback 결과 저장 및 재열람 처리
  // ─────────────────────────────────────────────────────────
  console.log("\nTEST 6: LLM 실패 시 fallback 저장 및 재열람 처리(직접 서비스 함수 단위 테스트)");
  {
    const { generateGunghapInterpret } = await import("../src/lib/gunghap/gunghap-interpret-service");
    const { gradeCategory } = await import("../src/lib/gunghap/gunghap-category-rules");
    const { categoryLabel } = await import("../src/lib/gunghap/gunghap-narrative");

    // 실패용 더미 fact/evidence — 실제 DB fact 하나를 재사용한다.
    const dbRowForFallback = await prisma.gunghapPairResult.findUnique({ where: { id: dbIdNum } });
    const fact = JSON.parse(dbRowForFallback!.factTrace);
    const stored = JSON.parse(dbRowForFallback!.categoryResults) as Array<{
      categoryId: string;
      relationshipFeature: string;
      strength: string;
      conflictRisk: string;
      improvement: string;
    }>;
    const target = stored.find((c) => c.categoryId === "love")!;
    const gradeResult = gradeCategory(fact, "love");

    let callCount = 0;
    const failingCaller = async () => {
      callCount++;
      throw new Error("강제 실패 테스트 — Anthropic API 호출 실패 시뮬레이션");
    };

    const outcome = await generateGunghapInterpret({
      topic: { categoryId: "love", categoryLabel: categoryLabel("love"), subName: null },
      evidence: gradeResult.evidence,
      grade: gradeResult.grade,
      freeNarrative: {
        relationshipFeature: target.relationshipFeature,
        strength: target.strength,
        conflictRisk: target.conflictRisk,
        improvement: target.improvement,
      },
      owner: { name: "실패테스트오너", gender: "male" },
      guest: { name: "실패테스트상대", gender: "female" },
      relationTypeLabel: fact.base.relationTypeLabel,
      llmCaller: failingCaller,
    });

    assert(callCount === 2, `LLM 실패 시 MAX_LLM_ATTEMPTS(2)회 재시도 (실제 호출 ${callCount}회)`);
    assert(outcome.source === "template", `전체 실패 시 source="template"(fallback) (실제 ${outcome.source})`);
    assert(
      outcome.detail.relationshipFeature === target.relationshipFeature,
      "fallback 결과는 무료 템플릿 텍스트와 동일(재포장)",
    );
    assert(
      outcome.attemptLog.some((l) => l.includes("LLM_ERROR")) && outcome.attemptLog.some((l) => l.includes("fallback: QA_PASSED")),
      "attemptLog에 LLM_ERROR 기록 및 fallback QA_PASSED 기록됨",
    );
    console.log(`  [증거] attemptLog = ${JSON.stringify(outcome.attemptLog)}`);
    console.log(`  [증거] fallback detail = ${JSON.stringify(outcome.detail)}`);
  }

  // ─────────────────────────────────────────────────────────
  // TEST 7: 주제별 FACT와 해석의 일치 여부(다른 주제로 생성 후 교차 비교)
  // ─────────────────────────────────────────────────────────
  console.log("\nTEST 7: 주제별 FACT-해석 일치 여부(wealth 주제 별도 생성 후 교차 비교)");
  const wealthOwner = await ensureTestUser({
    nickname: `gh_llm_wealth_${Date.now()}`,
    email: `gh_llm_wealth_${Date.now()}@example.com`,
    gender: "male",
  });
  const wealthToken = await signUserToken({ userId: wealthOwner.id, nickname: wealthOwner.nickname });
  await setWalletBalance(wealthOwner.id, 1000);
  const wealthSaju = sajuFor({ year: 1988, month: 3, day: 3, gender: "male" });
  const { resultId: wealthResultId } = await createDirectResultWithTopic(
    wealthToken,
    wealthSaju,
    "재물테스트오너",
    { name: "재물테스트상대", birthDate: "1990-11-11", gender: "female" },
    "wealth",
    "wealth",
  );
  const rWealth = await callApi("POST", `/api/public/gunghap/results/${wealthResultId}/unlock`, wealthToken);
  const dWealth = rWealth.json?.data as { detail: Array<{ categoryId: string; relationshipFeature: string; strength: string; conflictRisk: string; improvement: string }> } | undefined;
  assert(dWealth?.detail?.[0]?.categoryId === "wealth", `wealth 주제로 생성 시 응답 categoryId도 wealth (실제 ${dWealth?.detail?.[0]?.categoryId})`);
  console.log(`  [증거] wealth 주제 해석 텍스트:`);
  console.log(JSON.stringify(dWealth?.detail, null, 2));
  console.log(
    "  ※ 수동 검토 필요: love 주제(TEST1) 텍스트는 '설렘/애정표현/음양조화'류 어휘, wealth 주제는 '돈/소비·저축/재물' 류 어휘를 담고 있어야 함(위 출력된 두 텍스트를 사람이 비교).",
  );
  const loveText = JSON.stringify(d1?.detail);
  const wealthText = JSON.stringify(dWealth?.detail);
  assert(loveText !== wealthText, "love와 wealth 주제의 생성 텍스트가 서로 다름(동일 FACT라도 주제별로 다른 해석)");

  // ─────────────────────────────────────────────────────────
  // TEST 8: 기존 레거시 결과(majorId=null)의 하위 호환
  // ─────────────────────────────────────────────────────────
  console.log("\nTEST 8: 레거시 결과(majorId=null) 하위 호환 — 8분야 템플릿, LLM 미호출");
  const legacyRow = await prisma.gunghapPairResult.findFirst({
    where: { majorId: null, deletedAt: null },
    include: { invite: { select: { ownerId: true } } },
    orderBy: { id: "asc" },
  });
  if (!legacyRow) {
    console.log("  ⚠️  majorId=null인 레거시 결과를 찾지 못함(스킵)");
  } else {
    const legacyOwnerId = legacyRow.invite?.ownerId ?? legacyRow.ownerUserId;
    if (!legacyOwnerId) {
      console.log("  ⚠️  레거시 결과의 소유자를 특정할 수 없음(스킵)");
    } else {
      const legacyOwnerUser = await prisma.user.findUnique({ where: { id: legacyOwnerId } });
      const legacyToken = await signUserToken({ userId: legacyOwnerId, nickname: legacyOwnerUser?.nickname ?? "legacy" });
      // 이미 unlock되어 있을 수 있으니 레코드 삭제 후 처음부터 테스트(테스트 전용,
      // 해당 레거시 결과 자체 데이터는 변경하지 않음 — unlock_record/wallet만 조정).
      await prisma.gunghapUnlockRecord.deleteMany({ where: { userId: legacyOwnerId, resultId: legacyRow.id } });
      await setWalletBalanceKeepOtherRecords(legacyOwnerId, 1000);

      const legacyAiLogBefore = await prisma.aiRequestLog.count({ where: { domain: "gunghap", requestRefId: legacyRow.id } });
      const rLegacy = await callApi(
        "POST",
        `/api/public/gunghap/results/gr_${legacyRow.id}/unlock`,
        legacyToken,
      );
      assert(rLegacy.status === 200, `레거시 결과 unlock 200 (실제 ${rLegacy.status})`);
      const dLegacy = rLegacy.json?.data as { detail: unknown[]; llmSource: string } | undefined;
      assert(Array.isArray(dLegacy?.detail) && dLegacy!.detail.length === 8, `레거시 결과는 8개 분야 전체 반환 (실제 ${dLegacy?.detail?.length})`);
      assert(dLegacy?.llmSource === "template", `레거시 결과 llmSource="template"(LLM 미사용) (실제 ${dLegacy?.llmSource})`);
      const legacyAiLogAfter = await prisma.aiRequestLog.count({ where: { domain: "gunghap", requestRefId: legacyRow.id } });
      assert(legacyAiLogAfter === legacyAiLogBefore, `레거시 결과 unlock 시 AiRequestLog 생성 안 됨(LLM 미호출 확인) (before=${legacyAiLogBefore}, after=${legacyAiLogAfter})`);
    }
  }

  // ── 결과 요약 ──
  console.log("\n=== 테스트 종료 ===");
  if (failed) {
    console.error("❌ 일부 테스트 실패");
    process.exitCode = 1;
  } else {
    console.log("✅ 전체 테스트 통과");
  }
}

async function setWalletBalanceKeepOtherRecords(userId: number, balance: number) {
  const existing = await prisma.wallet.findFirst({ where: { userId, currencyType: "POINT" } });
  await prisma.wallet.upsert({
    where: { id: existing?.id ?? -1 },
    update: { balance },
    create: { userId, currencyType: "POINT", balance },
  });
}

main()
  .catch((e) => {
    console.error("치명적 오류:", e);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
