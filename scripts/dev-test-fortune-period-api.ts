// [신통방통 오늘·주간·월간 운세] HTTP API 통합(E2E) 테스트
// GET /api/public/fortune-period/{kind} (생성-or-조회)
// GET /api/public/fortune-period/{kind}/{periodKey} (과거 조회, 생성 안함)
// GET /api/public/fortune-period/{kind}/history (목록)
// 실행 전제: 로컬 dev 서버(localhost:3000) + 로컬 saju_engine(127.0.0.1:8000) 구동 중.
import { SignJWT } from "jose";
import { prisma } from "../src/lib/db";

const BASE = "http://localhost:3000";
const secretKey = process.env.SESSION_SECRET;
if (!secretKey) throw new Error("SESSION_SECRET 환경변수가 필요합니다(.env 확인).");
const encodedKey = new TextEncoder().encode(secretKey);

let pass = 0;
let fail = 0;
function check(label: string, cond: boolean, actual?: unknown) {
  if (cond) {
    pass++;
    console.log(`  ✅ ${label}${actual !== undefined ? ` (실제 ${JSON.stringify(actual)})` : ""}`);
  } else {
    fail++;
    console.log(`  ❌ ${label}${actual !== undefined ? ` (실제 ${JSON.stringify(actual)})` : ""}`);
  }
}

async function signUserToken(userId: number, nickname: string): Promise<string> {
  return new SignJWT({ userId, nickname })
    .setProtectedHeader({ alg: "HS256" })
    .setIssuedAt()
    .setExpirationTime("30d")
    .sign(encodedKey);
}

async function ensureTestUser(nickname: string) {
  const user = await prisma.user.upsert({
    where: { nickname },
    update: { status: "active" },
    create: {
      nickname,
      gender: "male",
      status: "active",
      signupChannel: "app",
    },
  });
  await prisma.userProfile.upsert({
    where: { userId: user.id },
    update: {
      birthDate: "1990-05-15",
      birthTime: "10:30",
      isLunar: false,
      birthTimeUnknown: false,
    },
    create: {
      userId: user.id,
      birthDate: "1990-05-15",
      birthTime: "10:30",
      isLunar: false,
      birthTimeUnknown: false,
    },
  });
  return user;
}

async function callApi(path: string, token: string) {
  const res = await fetch(`${BASE}${path}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  const json = await res.json().catch(() => null);
  return { status: res.status, json };
}

async function main() {
  console.log("=== 오늘·주간·월간 운세 API 통합 테스트 ===\n");

  const testNickname = `fp_api_test_${Date.now()}`;
  const user = await ensureTestUser(testNickname);
  const token = await signUserToken(user.id, testNickname);

  // TEST 1: 비회원(토큰 없음) 접근 차단
  const noAuthRes = await fetch(`${BASE}/api/public/fortune-period/today`);
  check("TEST1 비회원 접근 401", noAuthRes.status === 401, noAuthRes.status);

  // TEST 2: today 최초 생성
  console.log("\nTEST 2: today 최초 생성");
  const r1 = await callApi("/api/public/fortune-period/today", token);
  check("today 200", r1.status === 200, r1.status);
  check("isNew=true(최초 생성)", r1.json?.data?.isNew === true, r1.json?.data?.isNew);
  check("periodKey가 YYYY-MM-DD 형식", /^\d{4}-\d{2}-\d{2}$/.test(r1.json?.data?.periodKey ?? ""), r1.json?.data?.periodKey);
  check("seal 필드 존재", typeof r1.json?.data?.seal === "string", r1.json?.data?.seal);
  check("fields 3개(재물/애정/사업)", r1.json?.data?.fields?.length === 3, r1.json?.data?.fields?.length);
  check("today caution=null", r1.json?.data?.caution === null, r1.json?.data?.caution);

  // TEST 3: today 재조회 -> 캐시, isNew=false
  console.log("\nTEST 3: today 재조회(캐시)");
  const r2 = await callApi("/api/public/fortune-period/today", token);
  check("재조회 200", r2.status === 200, r2.status);
  check("isNew=false(캐시 반환)", r2.json?.data?.isNew === false, r2.json?.data?.isNew);
  check("동일 periodKey", r2.json?.data?.periodKey === r1.json?.data?.periodKey);
  check("동일 summary(같은 결과 반환)", r2.json?.data?.summary === r1.json?.data?.summary);

  // TEST 3.5: DB에 정확히 1건만 생성되었는지(중복 생성 방지)
  const count = await prisma.fortunePeriodResult.count({
    where: { userId: user.id, kind: "today" },
  });
  check("DB에 today 결과 정확히 1건", count === 1, count);

  // TEST 4: week 생성
  console.log("\nTEST 4: week 최초 생성");
  const r3 = await callApi("/api/public/fortune-period/week", token);
  check("week 200", r3.status === 200, r3.status);
  check("week caution 배열(2개)", Array.isArray(r3.json?.data?.caution) && r3.json.data.caution.length === 2);
  check("week flow 3단계(초반/중반/후반)", r3.json?.data?.flow?.map((f: { t: string }) => f.t).join(",") === "초반,중반,후반");

  // TEST 5: month 생성
  console.log("\nTEST 5: month 최초 생성");
  const r4 = await callApi("/api/public/fortune-period/month", token);
  check("month 200", r4.status === 200, r4.status);
  check("month flow 3단계(초순/중순/하순)", r4.json?.data?.flow?.map((f: { t: string }) => f.t).join(",") === "초순,중순,하순");

  // TEST 6: 과거 결과 조회(정확한 periodKey) - 생성 안함
  console.log("\nTEST 6: 과거 결과 조회");
  const todayPeriodKey = r1.json?.data?.periodKey;
  const r5 = await callApi(`/api/public/fortune-period/today/${todayPeriodKey}`, token);
  check("과거 조회 200", r5.status === 200, r5.status);
  check("isPast=true", r5.json?.data?.isPast === true, r5.json?.data?.isPast);

  // TEST 7: 존재하지 않는 periodKey -> 404 (생성 안함, 조회 전용 원칙 확인)
  const r6 = await callApi("/api/public/fortune-period/today/1999-01-01", token);
  check("존재하지 않는 periodKey 404", r6.status === 404, r6.status);
  const countAfter404 = await prisma.fortunePeriodResult.count({
    where: { userId: user.id, kind: "today" },
  });
  check("404 조회로 신규 생성 안됨(여전히 1건)", countAfter404 === 1, countAfter404);

  // TEST 8: history API
  console.log("\nTEST 8: history 목록 조회");
  const r7 = await callApi("/api/public/fortune-period/today/history?limit=6", token);
  check("history 200", r7.status === 200, r7.status);
  check("history에 1건 포함", r7.json?.data?.items?.length === 1, r7.json?.data?.items?.length);

  // TEST 9: 잘못된 kind -> 400
  const r8 = await callApi("/api/public/fortune-period/invalid-kind", token);
  check("잘못된 kind 400", r8.status === 400, r8.status);

  // TEST 10: 사주정보 없는 회원 -> 409 SAJU_REQUIRED
  console.log("\nTEST 10: 사주정보 미등록 회원");
  const noProfileNickname = `fp_api_noprofile_${Date.now()}`;
  const noProfileUser = await prisma.user.create({
    data: { nickname: noProfileNickname, status: "active", signupChannel: "app" },
  });
  const noProfileToken = await signUserToken(noProfileUser.id, noProfileNickname);
  const r9 = await callApi("/api/public/fortune-period/today", noProfileToken);
  check("사주정보 없음 409", r9.status === 409, r9.status);
  check("reason=SAJU_REQUIRED", r9.json?.reason === "SAJU_REQUIRED", r9.json?.reason);

  // 정리
  await prisma.fortunePeriodResult.deleteMany({ where: { userId: { in: [user.id, noProfileUser.id] } } });
  await prisma.userProfile.deleteMany({ where: { userId: { in: [user.id, noProfileUser.id] } } });
  await prisma.user.deleteMany({ where: { id: { in: [user.id, noProfileUser.id] } } });

  console.log(`\n=== 테스트 종료 (통과 ${pass} / 실패 ${fail}) ===`);
  if (fail > 0) {
    console.log("❌ 일부 테스트 실패");
    process.exit(1);
  }
  console.log("✅ 전체 테스트 통과");
}

main()
  .catch((e) => {
    console.error("테스트 실행 중 오류:", e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
