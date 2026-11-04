// [신통방통 오늘·주간·월간 운세 — 테스트 전용] API 검증용 테스트 계정 생성.
// 실제/운영 데이터 아님 — 로컬 dev.db에만 생성되는 격리된 테스트 계정.
//
// [server-only 우회] src/lib/user-auth.ts는 "server-only"를 import하므로
// tsx(일반 Node 스크립트)에서 직접 import할 수 없다. JWT 서명 로직 자체는
// user-auth.ts의 signUserToken()과 완전히 동일한 방식(jose SignJWT, HS256,
// 동일 SESSION_SECRET, 동일 payload 모양)으로 이 스크립트 안에서만 재현한다
// — 서명 알고리즘/시크릿을 바꾸거나 다르게 만들지 않으므로 발급된 토큰은
// authenticateRequest()가 검증하는 토큰과 동일하게 통과한다. SESSION_SECRET
// 값 자체는 어디에도 출력하지 않는다.
import { prisma } from "../src/lib/db";
import bcrypt from "bcryptjs";
import { SignJWT } from "jose";

const secretKey = process.env.SESSION_SECRET;
if (!secretKey) throw new Error("SESSION_SECRET 환경변수가 설정되지 않았습니다.");
const encodedKey = new TextEncoder().encode(secretKey);

async function signUserToken(payload: { userId: number; nickname: string }): Promise<string> {
  return new SignJWT(payload)
    .setProtectedHeader({ alg: "HS256" })
    .setIssuedAt()
    .setExpirationTime("30d")
    .sign(encodedKey);
}

async function main() {
  const email = "fortune_period_test@example.com";
  const password = "TestPass1234!";
  const passwordHash = await bcrypt.hash(password, 10);

  // 1) 사주정보 없는 계정 (SAJU_REQUIRED 409 테스트용)
  const userNoProfile = await prisma.user.upsert({
    where: { email },
    update: { passwordHash, status: "active" },
    create: { email, nickname: "운세테스트_무사주", passwordHash, gender: "male", status: "active" },
  });

  // 2) 사주정보 있는 계정 (실제 운세 생성 테스트용)
  const email2 = "fortune_period_test2@example.com";
  const userWithProfile = await prisma.user.upsert({
    where: { email: email2 },
    update: { passwordHash, status: "active" },
    create: { email: email2, nickname: "운세테스트_유사주", passwordHash, gender: "male", status: "active" },
  });
  await prisma.userProfile.upsert({
    where: { userId: userWithProfile.id },
    update: { birthDate: "1990-05-15", birthTime: "14:30", isLunar: false },
    create: { userId: userWithProfile.id, birthDate: "1990-05-15", birthTime: "14:30", isLunar: false },
  });

  const tokenNoProfile = await signUserToken({ userId: userNoProfile.id, nickname: userNoProfile.nickname });
  const tokenWithProfile = await signUserToken({ userId: userWithProfile.id, nickname: userWithProfile.nickname });

  console.log(
    JSON.stringify(
      {
        userNoProfile: { id: userNoProfile.id, token: tokenNoProfile },
        userWithProfile: { id: userWithProfile.id, token: tokenWithProfile },
      },
      null,
      2
    )
  );
}
main()
  .catch((e) => {
    console.error(e);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
