// [신통방통 정통사주 생년월일검증·일일재조회·어뷰징방지 최종지시서 §4·§8·§10] HTTP
// 통합 테스트 — fortune/saju/route.ts(69종 레거시) 엔드포인트가 복주머니 차감/
// LLM 호출보다 먼저 생년월일 검증으로 차단하는지 확인한다. §10 "검증 실패 시
// 복주머니 차감, 광고 보상 지급, LLM 호출, 사주 계산보다 먼저 종료한다"를
// 실제 요청으로 검증(차단 시 fortuneRequest 레코드가 생성되지 않아야 함).
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
const ENDPOINT = `${BASE_URL}/api/public/fortune/saju`;

let pass = 0;
let fail = 0;

async function ensureTestUser() {
  const user = await prisma.user.upsert({
    where: { email: "fortune-saju-birth-validator-test@example.com" },
    update: {},
    create: {
      email: "fortune-saju-birth-validator-test@example.com",
      nickname: "fortune_saju_birth_tester",
      passwordHash: "test-only-hash",
      status: "active",
    },
  });
  // 지갑도 필요할 수 있으니 확인(차단 케이스는 어차피 지갑에 도달하지 않아야 함)
  return user;
}

async function callSaju(token: string, body: Record<string, unknown>) {
  const res = await fetch(ENDPOINT, {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
    body: JSON.stringify(body),
  });
  const json = await res.json();
  return { status: res.status, json };
}

async function expectReject(
  label: string,
  token: string,
  body: Record<string, unknown>,
  expectedReason: string
) {
  const before = await prisma.fortuneRequest.count({ where: { fortuneType: "saju" } });
  const { status, json } = await callSaju(token, body);
  const after = await prisma.fortuneRequest.count({ where: { fortuneType: "saju" } });

  const statusOk = status === 400 && json.reason === expectedReason;
  const noSideEffect = after === before; // fortuneRequest 레코드가 생성되지 않아야 함(계산/LLM 전 차단)

  if (statusOk && noSideEffect) {
    console.log(`✅ ${label} → ${status} 정상 거부(reason=${json.reason}), fortuneRequest 레코드 생성 안 됨`);
    pass++;
  } else {
    console.error(
      `❌ ${label} → 기대: 400/${expectedReason}+부작용없음, 실제: ${status}/${json.reason}, fortuneRequest ${before}→${after}`,
      json
    );
    fail++;
  }
}

async function main() {
  console.log(`=== HTTP 통합 테스트: POST ${ENDPOINT} (69종 레거시) ===\n`);

  const user = await ensureTestUser();
  const token = await signUserToken({ userId: user.id, nickname: user.nickname });

  await expectReject(
    "2300-10-06 (미래 생년월일) → 복주머니/LLM 호출 전 차단",
    token,
    { birthDate: "2300-10-06", topics: ["종합"] },
    "FUTURE_DATE"
  );
  await expectReject(
    "2026-02-30 (존재하지 않는 날짜) → 차단",
    token,
    { birthDate: "2026-02-30", topics: ["종합"] },
    "DATE_NOT_EXIST"
  );
  await expectReject(
    "1899-12-31 (범위 외) → 차단",
    token,
    { birthDate: "1899-12-31", topics: ["종합"] },
    "OUT_OF_RANGE"
  );
  await expectReject(
    "25:00 잘못된 birthTime 형식 → 차단",
    token,
    { birthDate: "1980-05-10", birthTime: "25:99", topics: ["종합"] },
    "INVALID_TIME"
  );

  console.log(`\n=== 결과: ${pass}개 통과 / ${fail}개 실패 ===`);
  if (fail > 0) {
    console.error("❌ 일부 HTTP 통합 테스트 실패");
    process.exitCode = 1;
  } else {
    console.log("✅ POST /api/public/fortune/saju 생년월일 검증(차단 우선순위) 통합 테스트 전체 통과");
  }

  await prisma.$disconnect();
}

main().catch((e) => {
  console.error("스크립트 실행 중 오류:", e);
  process.exit(1);
});
