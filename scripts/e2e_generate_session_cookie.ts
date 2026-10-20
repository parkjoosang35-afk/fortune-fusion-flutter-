// Playwright E2E 테스트용 — 실제 로그인 폼을 거치지 않고(비밀번호 모름) src/lib/session.ts의
// encryptSession()과 완전히 동일한 알고리즘/시크릿/payload 구조로 유효한 JWT 세션 쿠키를
// 발급한다. "server-only" 패키지 제약으로 session.ts를 직접 import할 수 없어 동일 로직만
// 복제했다(운영 코드인 session.ts 자체는 수정하지 않음 - 최소 변경 원칙).
import { SignJWT } from "jose";

const SESSION_IDLE_TIMEOUT_MINUTES = 30;
const secretKey = process.env.SESSION_SECRET;
if (!secretKey) throw new Error("SESSION_SECRET 환경변수가 없습니다.");
const encodedKey = new TextEncoder().encode(secretKey);

async function main() {
  const token = await new SignJWT({
    adminUserId: 1,
    email: "sksks77777@naver.com",
    name: "sksks77777",
    roleCode: "super_admin",
  })
    .setProtectedHeader({ alg: "HS256" })
    .setIssuedAt()
    .setExpirationTime(`${SESSION_IDLE_TIMEOUT_MINUTES}m`)
    .sign(encodedKey);
  console.log(token);
}

main();
