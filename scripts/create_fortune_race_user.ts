import { prisma } from "../src/lib/db";
import bcrypt from "bcryptjs";
import { SignJWT } from "jose";

const secretKey = process.env.SESSION_SECRET;
if (!secretKey) throw new Error("SESSION_SECRET 환경변수가 설정되지 않았습니다.");
const encodedKey = new TextEncoder().encode(secretKey);

async function signUserToken(payload: { userId: number; nickname: string }): Promise<string> {
  return new SignJWT(payload).setProtectedHeader({ alg: "HS256" }).setIssuedAt().setExpirationTime("30d").sign(encodedKey);
}

async function main() {
  const email = "fortune_period_race@example.com";
  const passwordHash = await bcrypt.hash("TestPass1234!", 10);
  const user = await prisma.user.upsert({
    where: { email },
    update: { passwordHash, status: "active" },
    create: { email, nickname: "운세동시성테스트", passwordHash, gender: "female", status: "active" },
  });
  await prisma.userProfile.upsert({
    where: { userId: user.id },
    update: { birthDate: "1995-08-20", birthTime: "09:15", isLunar: false },
    create: { userId: user.id, birthDate: "1995-08-20", birthTime: "09:15", isLunar: false },
  });
  const token = await signUserToken({ userId: user.id, nickname: user.nickname });
  console.log(JSON.stringify({ id: user.id, token }));
}
main().catch((e) => { console.error(e); process.exitCode = 1; }).finally(() => prisma.$disconnect());
