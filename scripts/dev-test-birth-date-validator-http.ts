// [신통방통 정통사주 생년월일검증·일일재조회·어뷰징방지 최종지시서] HTTP 레벨 통합
// 테스트 — 실제 실행 중인 Next.js dev 서버에 PATCH /api/public/auth/profile을
// 호출해 §4 입력 검증이 "출생정보 저장" 지점에서 실제로 동작하는지 확인한다.
// 기존 scripts/dev-test-topics-select-api.ts와 동일한 패턴(server-only 우회,
// JWT 재서명)을 따른다.
import "dotenv/config";
import { prisma } from "../src/lib/db";
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

const BASE_URL = process.env.TEST_BASE_URL ?? "http://localhost:3000";
const ENDPOINT = `${BASE_URL}/api/public/auth/profile`;

let pass = 0;
let fail = 0;

async function ensureTestUser() {
  const user = await prisma.user.upsert({
    where: { email: "birth-date-validator-test@example.com" },
    update: {},
    create: {
      email: "birth-date-validator-test@example.com",
      nickname: "birthdate_validator_tester",
      passwordHash: "test-only-hash",
      status: "active",
    },
  });
  return user;
}

async function patchProfile(token: string, body: Record<string, unknown>) {
  const res = await fetch(ENDPOINT, {
    method: "PATCH",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
    body: JSON.stringify(body),
  });
  const json = await res.json();
  return { status: res.status, json };
}

async function expectOk(label: string, token: string, body: Record<string, unknown>) {
  const { status, json } = await patchProfile(token, body);
  if (status === 200 && json.success) {
    console.log(`✅ ${label} → 200 정상 통과`);
    pass++;
  } else {
    console.error(`❌ ${label} → 기대: 200 성공, 실제: ${status}`, json);
    fail++;
  }
}

async function expectReject(
  label: string,
  token: string,
  body: Record<string, unknown>,
  expectedReason: string
) {
  const { status, json } = await patchProfile(token, body);
  if (status === 400 && json.reason === expectedReason) {
    console.log(`✅ ${label} → ${status} 정상 거부(reason=${json.reason}): ${json.error}`);
    pass++;
  } else {
    console.error(`❌ ${label} → 기대: 400/${expectedReason}, 실제: ${status}/${json.reason}`, json);
    fail++;
  }
}

async function main() {
  console.log(`=== HTTP 통합 테스트: PATCH ${ENDPOINT} ===\n`);

  const user = await ensureTestUser();
  const token = await signUserToken({ userId: user.id, nickname: user.nickname });

  await expectOk("1980-05-10 (정상 과거 날짜) 저장", token, { birth_date: "1980-05-10" });
  await expectReject("2300-10-06 (미래 날짜) 저장 거부", token, { birth_date: "2300-10-06" }, "FUTURE_DATE");
  await expectReject("2026-02-30 (존재하지 않는 날짜) 저장 거부", token, { birth_date: "2026-02-30" }, "DATE_NOT_EXIST");
  await expectReject("1899-12-31 (범위 외) 저장 거부", token, { birth_date: "1899-12-31" }, "OUT_OF_RANGE");

  // 닉네임만 수정(birth_date 미포함) — 검증을 건너뛰고 정상 처리되어야 함(§1 "범위를
  // 임의로 확장하지 않는다" — 기존 값을 건드리지 않는 요청은 재검증하지 않음)
  await expectOk("닉네임만 수정(birth_date 없음, 검증 스킵)", token, {
    nickname: `tester_${Date.now()}`,
  });

  // 거부 후에도 기존 저장값(1980-05-10)이 그대로 유지되는지 확인(검증 실패 시
  // DB write 자체가 일어나지 않아야 함)
  const after = await prisma.userProfile.findUnique({ where: { userId: user.id } });
  if (after?.birthDate === "1980-05-10") {
    console.log("✅ 거부된 요청 이후에도 기존 저장값(1980-05-10) 그대로 유지됨");
    pass++;
  } else {
    console.error(`❌ 거부된 요청이 DB에 반영됨(비정상): birthDate=${after?.birthDate}`);
    fail++;
  }

  console.log(`\n=== 결과: ${pass}개 통과 / ${fail}개 실패 ===`);
  if (fail > 0) {
    console.error("❌ 일부 HTTP 통합 테스트 실패");
    process.exitCode = 1;
  } else {
    console.log("✅ PATCH /api/public/auth/profile 생년월일 검증 통합 테스트 전체 통과");
  }

  await prisma.$disconnect();
}

main().catch((e) => {
  console.error("스크립트 실행 중 오류:", e);
  process.exit(1);
});
