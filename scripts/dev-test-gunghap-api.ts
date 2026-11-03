// 궁합지도(Gunghap Map) API 통합 테스트 — 개발 승인(API 단계) §4 "필수 테스트"
// 10개 항목을 실제 실행 중인 Next.js dev 서버(localhost:3000)에 HTTP 요청으로
// 검증한다. 운영 코드에서 import되지 않으며, 회귀 점검용으로 보존한다.
//
// 사전조건: `npx next dev`가 :3000에서 떠 있어야 한다(SESSION_SECRET은 .env에서
// 읽는다 — dev-test-topics-select-api.ts와 동일한 "서명 재현" 패턴).
//
// 실행: npx tsx scripts/dev-test-gunghap-api.ts
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

async function ensureTestUser(params: { nickname: string; email: string }) {
  const user = await prisma.user.upsert({
    where: { email: params.email },
    update: {},
    create: {
      email: params.email,
      nickname: params.nickname,
      passwordHash: "test-only-hash",
      status: "active",
    },
  });
  return user;
}

async function setWalletBalance(userId: number, balance: number) {
  await prisma.gunghapUnlockRecord.deleteMany({ where: { userId } });
  const wallet = await prisma.wallet.upsert({
    where: { id: (await prisma.wallet.findFirst({ where: { userId, currencyType: "POINT" } }))?.id ?? -1 },
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

function ownerSajuFor(opts: { year: number; month: number; day: number; gender: "male" | "female" }) {
  const m = calculateSaju({ year: opts.year, month: opts.month, day: opts.day, gender: opts.gender, timeUnknown: true });
  return guinjiSajuInputFromManseryeok(m);
}

async function main() {
  console.log("=== 궁합지도 API 통합 테스트 (개발 승인 §4 — 11개 항목) ===\n");

  const owner = await ensureTestUser({
    nickname: `gunghap_owner_${Date.now()}`,
    email: `gunghap_owner_${Date.now()}@example.com`,
  });
  const otherUser = await ensureTestUser({
    nickname: `gunghap_other_${Date.now()}`,
    email: `gunghap_other_${Date.now()}@example.com`,
  });
  const ownerToken = await signUserToken({ userId: owner.id, nickname: owner.nickname });
  const otherToken = await signUserToken({ userId: otherUser.id, nickname: otherUser.nickname });
  await setWalletBalance(owner.id, 500);
  await setWalletBalance(otherUser.id, 500);

  const ownerSaju = ownerSajuFor({ year: 1990, month: 5, day: 14, gender: "male" });

  // ── TEST 1: 초대 생성 + 토큰 검증 ──
  console.log("TEST 1: 초대 생성 및 토큰 검증");
  const r1 = await callApi("POST", "/api/public/gunghap/invites", ownerToken, {
    ownerName: "테스트초대자",
    saju: ownerSaju,
  });
  assert(r1.status === 201, `초대 생성 201 (실제 ${r1.status})`);
  const inviteData = r1.json?.data as { inviteId: number; token: string; sharePath: string } | undefined;
  assert(!!inviteData?.token && inviteData.token.length >= 16, "토큰이 16자 이상(base64url, 96bit 엔트로피)");
  const token = inviteData!.token;

  // 비회원 초대 생성 시도 → 401
  const r1b = await callApi("POST", "/api/public/gunghap/invites", null, { saju: ownerSaju });
  assert(r1b.status === 401, `비회원 초대 생성 거부 401 (실제 ${r1b.status})`);

  // 동일 사용자가 여러 초대 생성 가능 확인
  const r1c = await callApi("POST", "/api/public/gunghap/invites", ownerToken, { saju: ownerSaju });
  assert(r1c.status === 201, `동일 사용자 2번째 초대 생성 가능 201 (실제 ${r1c.status})`);
  const inviteData2 = r1c.json?.data as { inviteId: number } | undefined;
  assert(inviteData2!.inviteId !== inviteData!.inviteId, "서로 다른 inviteId 발급(다중 초대 허용)");

  // 존재하지 않는 토큰 → 404
  const rBadToken = await callApi("GET", "/api/public/gunghap/g/not-a-real-token-xyz", null);
  assert(rBadToken.status === 404, `존재하지 않는 토큰 404 (실제 ${rBadToken.status})`);

  // 토큰 조회(비회원도 가능 — 게스트 링크 오픈 시나리오)
  const rTokenCheck = await callApi("GET", `/api/public/gunghap/g/${token}`, null);
  assert(rTokenCheck.status === 200, `토큰 조회 200(비회원) (실제 ${rTokenCheck.status})`);
  assert(
    (rTokenCheck.json?.data as { joined?: boolean } | undefined)?.joined === false,
    "참여 전에는 joined=false",
  );

  // ── TEST 2: 게스트 직접 입력 + 서버 사주 계산 ──
  console.log("\nTEST 2: 게스트 직접 입력 및 서버 사주 계산");
  const r2 = await callApi("POST", `/api/public/gunghap/g/${token}/join`, null, {
    name: "게스트1",
    birthDate: "1992-08-20",
    calendarType: "solar",
    birthTime: "10:30",
    gender: "female",
    agreePolicy: true,
    agreeAge14: true,
  });
  assert(r2.status === 201, `게스트 참여 201 (실제 ${r2.status})`);
  const joinData = r2.json?.data as
    | { resultId: string; categories?: unknown[]; unlockCost?: number; dayMasterKr?: string }
    | undefined;
  assert(!!joinData?.resultId, "resultId 발급됨(서버가 실제로 계산·저장함을 증명)");
  assert(!!joinData?.dayMasterKr, "서버가 직접 계산한 일간 정보 포함(클라이언트 입력 아님)");

  // ── TEST 3: 8분야 결과 생성 ──
  console.log("\nTEST 3: 8분야 결과 생성");
  const categories = joinData?.categories as Array<{ categoryId: string; grade: string }> | undefined;
  assert(Array.isArray(categories) && categories.length === 8, `8개 분야 결과 (실제 ${categories?.length})`);
  const expectedIds = ["love", "marriage", "intimacy", "persona", "wealth", "business", "friend", "family"];
  assert(
    expectedIds.every((id) => categories!.some((c) => c.categoryId === id)),
    "8개 분야 전부 포함(love/marriage/intimacy/persona/wealth/business/friend/family)",
  );
  assert(
    categories!.every((c) => typeof c.grade === "string" && !("categoryScore" in c)),
    "무료 응답은 등급만 노출(점수/서술 비노출 — grades-only 원칙)",
  );

  // ── TEST 4: 중복 제출 방지 ──
  console.log("\nTEST 4: 중복 제출 방지(동일 토큰 재제출)");
  const r2dup = await callApi("POST", `/api/public/gunghap/g/${token}/join`, null, {
    name: "다른이름으로재제출",
    birthDate: "2000-01-01",
    calendarType: "solar",
    gender: "male",
    agreePolicy: true,
    agreeAge14: true,
  });
  assert(r2dup.status === 200, `재제출은 200(신규 생성 아님) (실제 ${r2dup.status})`);
  const dupData = r2dup.json?.data as { resultId: string } | undefined;
  assert(dupData?.resultId === joinData?.resultId, "재제출해도 동일 resultId 반환(새 레코드 생성 안 됨)");
  const countCheck = await prisma.gunghapPairResult.count({
    where: { inviteId: inviteData!.inviteId },
  });
  assert(countCheck === 1, `DB에 결과 레코드가 정확히 1건만 존재 (실제 ${countCheck})`);

  // ── TEST 5: 무료 결과 조회 + 권한 검증 ──
  console.log("\nTEST 5: 무료 결과 조회(소유자) 및 권한 검증(타인 차단)");
  const r5 = await callApi("GET", `/api/public/gunghap/results/${joinData!.resultId}`, ownerToken);
  assert(r5.status === 200, `소유자 결과 조회 200 (실제 ${r5.status})`);
  assert(
    (r5.json?.data as { unlocked?: boolean } | undefined)?.unlocked === false,
    "잠금해제 전에는 unlocked=false",
  );
  assert(!("detail" in (r5.json?.data as object)), "잠금해제 전에는 detail(4요소 서술) 미포함");

  const r5forbidden = await callApi("GET", `/api/public/gunghap/results/${joinData!.resultId}`, otherToken);
  assert(r5forbidden.status === 403, `타인 결과 접근 차단 403 (실제 ${r5forbidden.status})`);

  const r5unauth = await callApi("GET", `/api/public/gunghap/results/${joinData!.resultId}`, null);
  assert(r5unauth.status === 401, `비회원 결과 조회 거부 401 (실제 ${r5unauth.status})`);

  const r5notfound = await callApi("GET", `/api/public/gunghap/results/gr_999999999`, ownerToken);
  assert(r5notfound.status === 404, `존재하지 않는 resultId 404 (실제 ${r5notfound.status})`);

  // ── TEST 6: 100P 정상 차감 ──
  console.log("\nTEST 6: 100 복주머니 정상 차감");
  const walletBefore = await prisma.wallet.findFirst({ where: { userId: owner.id, currencyType: "POINT" } });
  const r6 = await callApi("POST", `/api/public/gunghap/results/${joinData!.resultId}/unlock`, ownerToken);
  assert(r6.status === 200, `잠금해제 200 (실제 ${r6.status})`);
  const unlockData = r6.json?.data as
    | { unlocked: boolean; amountCharged: number; detail?: unknown[]; balanceAfter?: number }
    | undefined;
  assert(unlockData?.amountCharged === 100, `정확히 100P 차감 (실제 ${unlockData?.amountCharged})`);
  assert(Array.isArray(unlockData?.detail) && unlockData!.detail!.length === 8, "해금 후 8개 분야 상세 서술 포함");
  const walletAfter = await prisma.wallet.findFirst({ where: { userId: owner.id, currencyType: "POINT" } });
  assert(
    walletBefore!.balance - walletAfter!.balance === 100,
    `Wallet.balance가 정확히 100 감소 (${walletBefore!.balance} → ${walletAfter!.balance})`,
  );
  const historyRow = await prisma.pointHistory.findFirst({
    where: { userId: owner.id, sourceType: "gunghap_detail_unlock" },
    orderBy: { id: "desc" },
  });
  assert(historyRow?.amount === -100, "PointHistory에 -100 차감 내역 기록됨(사용내역)");
  const unlockRecord = await prisma.gunghapUnlockRecord.findFirst({
    where: { userId: owner.id, resultId: Number(joinData!.resultId.replace("gr_", "")) },
  });
  assert(!!unlockRecord, "GunghapUnlockRecord 생성됨(해금 기록)");

  // ── TEST 7: 잔액 부족 처리 ──
  console.log("\nTEST 7: 잔액 부족 시 차감하지 않고 안내");
  const poorUser = await ensureTestUser({
    nickname: `gunghap_poor_${Date.now()}`,
    email: `gunghap_poor_${Date.now()}@example.com`,
  });
  const poorToken = await signUserToken({ userId: poorUser.id, nickname: poorUser.nickname });
  await setWalletBalance(poorUser.id, 50); // 100P 미만

  const poorOwnerSaju = ownerSajuFor({ year: 1985, month: 3, day: 3, gender: "female" });
  const rPoorInvite = await callApi("POST", "/api/public/gunghap/invites", poorToken, { saju: poorOwnerSaju });
  const poorInviteData = rPoorInvite.json?.data as { token: string } | undefined;
  const rPoorJoin = await callApi("POST", `/api/public/gunghap/g/${poorInviteData!.token}/join`, null, {
    name: "잔액부족테스트게스트",
    birthDate: "1988-11-11",
    calendarType: "solar",
    gender: "male",
    agreePolicy: true,
    agreeAge14: true,
  });
  const poorJoinData = rPoorJoin.json?.data as { resultId: string } | undefined;

  const walletPoorBefore = await prisma.wallet.findFirst({ where: { userId: poorUser.id, currencyType: "POINT" } });
  const r7 = await callApi("POST", `/api/public/gunghap/results/${poorJoinData!.resultId}/unlock`, poorToken);
  assert(r7.status === 400, `잔액 부족 400 (실제 ${r7.status})`);
  assert((r7.json as { code?: string })?.code === "INSUFFICIENT_BALANCE", "에러 코드 INSUFFICIENT_BALANCE");
  const walletPoorAfter = await prisma.wallet.findFirst({ where: { userId: poorUser.id, currencyType: "POINT" } });
  assert(walletPoorBefore!.balance === walletPoorAfter!.balance, "잔액 부족 시 Wallet.balance 변동 없음(차감 안 됨)");
  const poorUnlockCount = await prisma.gunghapUnlockRecord.count({ where: { userId: poorUser.id } });
  assert(poorUnlockCount === 0, "잔액 부족 시 GunghapUnlockRecord도 생성되지 않음");

  // ── TEST 8: 중복 차감 방지(동일 사용자 재열람) ──
  console.log("\nTEST 8: 동일 사용자 동일 보고서 재열람 시 중복 차감 방지");
  const walletRelookBefore = await prisma.wallet.findFirst({ where: { userId: owner.id, currencyType: "POINT" } });
  const r8 = await callApi("POST", `/api/public/gunghap/results/${joinData!.resultId}/unlock`, ownerToken);
  assert(r8.status === 200, `재열람 200 (실제 ${r8.status})`);
  const relookData = r8.json?.data as { amountCharged: number; alreadyUnlocked: boolean } | undefined;
  assert(relookData?.amountCharged === 0, `재열람 시 추가 차감 0 (실제 ${relookData?.amountCharged})`);
  assert(relookData?.alreadyUnlocked === true, "alreadyUnlocked=true로 응답");
  const walletRelookAfter = await prisma.wallet.findFirst({ where: { userId: owner.id, currencyType: "POINT" } });
  assert(walletRelookBefore!.balance === walletRelookAfter!.balance, "재열람 후 Wallet.balance 변동 없음");
  const unlockCountAfterRelook = await prisma.gunghapUnlockRecord.count({
    where: { userId: owner.id, resultId: Number(joinData!.resultId.replace("gr_", "")) },
  });
  assert(unlockCountAfterRelook === 1, "GunghapUnlockRecord도 여전히 1건(중복 생성 안 됨)");

  // ── TEST 9: 동시 결제 요청 테스트(race condition) ──
  console.log("\nTEST 9: 동시 결제 요청 — 중복 차감 방지");
  const concurUser = await ensureTestUser({
    nickname: `gunghap_concur_${Date.now()}`,
    email: `gunghap_concur_${Date.now()}@example.com`,
  });
  const concurToken = await signUserToken({ userId: concurUser.id, nickname: concurUser.nickname });
  await setWalletBalance(concurUser.id, 500);
  const concurOwnerSaju = ownerSajuFor({ year: 1995, month: 7, day: 7, gender: "male" });
  const rConcurInvite = await callApi("POST", "/api/public/gunghap/invites", concurToken, { saju: concurOwnerSaju });
  const concurInviteData = rConcurInvite.json?.data as { token: string } | undefined;
  const rConcurJoin = await callApi("POST", `/api/public/gunghap/g/${concurInviteData!.token}/join`, null, {
    name: "동시요청테스트게스트",
    birthDate: "1996-12-25",
    calendarType: "solar",
    gender: "female",
    agreePolicy: true,
    agreeAge14: true,
  });
  const concurJoinData = rConcurJoin.json?.data as { resultId: string } | undefined;

  const walletConcurBefore = await prisma.wallet.findFirst({ where: { userId: concurUser.id, currencyType: "POINT" } });
  const concurrentResults = await Promise.all(
    Array.from({ length: 5 }, () =>
      callApi("POST", `/api/public/gunghap/results/${concurJoinData!.resultId}/unlock`, concurToken),
    ),
  );
  const successCount = concurrentResults.filter((r) => r.status === 200).length;
  assert(successCount === 5, `동시 요청 5건 모두 200 응답(idempotent, 실제 성공 ${successCount}건)`);
  const totalCharged = concurrentResults.reduce(
    (sum, r) => sum + ((r.json?.data as { amountCharged?: number } | undefined)?.amountCharged ?? 0),
    0,
  );
  assert(totalCharged === 100, `5건 동시 요청 중 실제 차감은 합계 100P뿐(나머지는 0) (실제 합계 ${totalCharged})`);
  const walletConcurAfter = await prisma.wallet.findFirst({ where: { userId: concurUser.id, currencyType: "POINT" } });
  assert(
    walletConcurBefore!.balance - walletConcurAfter!.balance === 100,
    `동시 요청 후 Wallet.balance는 정확히 100만 감소 (${walletConcurBefore!.balance} → ${walletConcurAfter!.balance})`,
  );
  const concurUnlockCount = await prisma.gunghapUnlockRecord.count({
    where: { userId: concurUser.id, resultId: Number(concurJoinData!.resultId.replace("gr_", "")) },
  });
  assert(concurUnlockCount === 1, `GunghapUnlockRecord는 정확히 1건만 생성(동시 요청에도 중복 없음) (실제 ${concurUnlockCount})`);

  // ── TEST 10: 비회원/권한없는 접근 차단 (잠금해제 라우트) ──
  console.log("\nTEST 10: 비회원/권한없는 접근 차단(잠금해제)");
  const r10unauth = await callApi("POST", `/api/public/gunghap/results/${joinData!.resultId}/unlock`, null);
  assert(r10unauth.status === 401, `비회원 잠금해제 시도 401 (실제 ${r10unauth.status})`);
  const r10forbidden = await callApi("POST", `/api/public/gunghap/results/${joinData!.resultId}/unlock`, otherToken);
  assert(r10forbidden.status === 403, `타인 결과 잠금해제 시도 403 (실제 ${r10forbidden.status})`);
  const walletOtherCheck = await prisma.wallet.findFirst({ where: { userId: otherUser.id, currencyType: "POINT" } });
  assert(walletOtherCheck!.balance === 500, "권한 없는 시도로는 타인 지갑도 차감되지 않음");

  // ── TEST 11: 윤달/시간모름 테스트 ──
  console.log("\nTEST 11: 윤달/시간모름 지원");
  // 11-1: 시간모름(birthTime 생략) — timeUnknown=true로 정오 가정 계산되어야 함.
  const rLeap1Invite = await callApi("POST", "/api/public/gunghap/invites", ownerToken, { saju: ownerSaju });
  const leap1Token = (rLeap1Invite.json?.data as { token: string }).token;
  const rTimeUnknown = await callApi("POST", `/api/public/gunghap/g/${leap1Token}/join`, null, {
    name: "시간모름게스트",
    birthDate: "1993-04-04",
    calendarType: "solar",
    gender: "female",
    agreePolicy: true,
    agreeAge14: true,
    // birthTime 생략
  });
  assert(rTimeUnknown.status === 201, `시간모름 참여 201 (실제 ${rTimeUnknown.status})`);
  assert(
    (rTimeUnknown.json?.data as { timeUnknown?: boolean } | undefined)?.timeUnknown === true,
    "timeUnknown=true로 정상 처리(정오 가정)",
  );

  // 11-2: 음력 + 윤달(2023년 윤2월 — 실제 윤달 존재 연도)
  const rLeap2Invite = await callApi("POST", "/api/public/gunghap/invites", ownerToken, { saju: ownerSaju });
  const leap2Token = (rLeap2Invite.json?.data as { token: string }).token;
  const rLeapMonth = await callApi("POST", `/api/public/gunghap/g/${leap2Token}/join`, null, {
    name: "윤달게스트",
    birthDate: "2023-02-15",
    calendarType: "lunar",
    isLeapMonth: true,
    birthTime: "09:00",
    gender: "male",
    agreePolicy: true,
    agreeAge14: true,
  });
  assert(rLeapMonth.status === 201, `윤달(음력 2023-02-15 윤달) 참여 201 (실제 ${rLeapMonth.status})`);
  const leapResultId = (rLeapMonth.json?.data as { resultId: string } | undefined)?.resultId;
  const leapDbRow = leapResultId
    ? await prisma.gunghapPairResult.findUnique({ where: { id: Number(leapResultId.replace("gr_", "")) } })
    : null;
  assert(leapDbRow?.guestIsLeapMonth === true, "DB에 guestIsLeapMonth=true로 정확히 저장됨");

  // 11-3: 양력인데 isLeapMonth=true를 보내도 무시되어야 함(절대 원칙)
  const rLeap3Invite = await callApi("POST", "/api/public/gunghap/invites", ownerToken, { saju: ownerSaju });
  const leap3Token = (rLeap3Invite.json?.data as { token: string }).token;
  const rSolarIgnoreLeap = await callApi("POST", `/api/public/gunghap/g/${leap3Token}/join`, null, {
    name: "양력윤달무시게스트",
    birthDate: "1999-09-09",
    calendarType: "solar",
    isLeapMonth: true, // 양력이므로 무시되어야 함
    gender: "female",
    agreePolicy: true,
    agreeAge14: true,
  });
  assert(rSolarIgnoreLeap.status === 201, `양력+isLeapMonth 전송해도 정상 처리 201 (실제 ${rSolarIgnoreLeap.status})`);
  const solarResultId = (rSolarIgnoreLeap.json?.data as { resultId: string } | undefined)?.resultId;
  const solarDbRow = solarResultId
    ? await prisma.gunghapPairResult.findUnique({ where: { id: Number(solarResultId.replace("gr_", "")) } })
    : null;
  assert(solarDbRow?.guestIsLeapMonth === false, "양력일 때는 isLeapMonth=true를 보내도 false로 저장(무시됨)");

  // 11-4: 잘못된 윤달 날짜(존재하지 않는 음력 윤달) → 400 처리 확인(day 범위 검증만 — 실제 윤달 존재 여부는 엔진이 판단)
  const rLeap4Invite = await callApi("POST", "/api/public/gunghap/invites", ownerToken, { saju: ownerSaju });
  const leap4Token = (rLeap4Invite.json?.data as { token: string }).token;
  const rInvalidLunarDay = await callApi("POST", `/api/public/gunghap/g/${leap4Token}/join`, null, {
    name: "잘못된날짜게스트",
    birthDate: "1993-04-35", // day=35는 범위 초과
    calendarType: "lunar",
    gender: "female",
    agreePolicy: true,
    agreeAge14: true,
  });
  assert(rInvalidLunarDay.status === 400, `잘못된 음력 날짜(day=35) 400 거부 (실제 ${rInvalidLunarDay.status})`);

  // ── 결과 요약 ──
  console.log("\n=== 테스트 종료 ===");
  if (failed) {
    console.error("\n❌ 일부 테스트 실패");
    process.exit(1);
  } else {
    console.log("\n✅ 전체 테스트 통과");
  }
}

main()
  .catch((e) => {
    console.error("테스트 실행 중 예외:", e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
