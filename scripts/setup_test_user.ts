import { prisma } from "../src/lib/db";
import bcrypt from "bcryptjs";
import { earnLuckPouch } from "../src/lib/luck-pouch-engine";

async function main() {
  const email = "ra_proto_test@example.com";
  const password = "test1234";
  const passwordHash = await bcrypt.hash(password, 10);

  let user = await prisma.user.findUnique({ where: { email } });
  if (!user) {
    user = await prisma.user.create({
      data: { email, passwordHash, nickname: "ra_proto_test", status: "active" },
    });
    console.log("생성된 유저:", user.id);
  } else {
    console.log("기존 유저 재사용:", user.id);
  }

  let policy = await prisma.passPolicy.findFirst({ where: { grantCount: { not: null } } });
  if (!policy) throw new Error("횟수제 정책이 없습니다");
  const now = new Date();
  const expiresAt = new Date(now.getTime() + 24 * 60 * 60 * 1000);

  // 기존 UserPass 모두 만료 처리 후 새로 2회 지급 (테스트 반복 실행 대비, 깨끗한 상태로)
  await prisma.userPass.updateMany({
    where: { userId: user.id, status: "active" },
    data: { status: "expired" },
  });
  const userPass = await prisma.userPass.create({
    data: {
      userId: user.id,
      policyId: policy.id,
      activatedAt: now,
      expiresAt,
      sourceType: "test_mode",
      status: "active",
      grantedCount: 2,
      remainingCount: 2,
      grantSource: "COUPANG_DAILY",
    },
  });
  console.log("UserPass 생성:", userPass.id, "remaining=", userPass.remainingCount);

  await prisma.$transaction(async (tx) => {
    await earnLuckPouch(tx, { userId: user!.id, amount: 300, sourceType: "manual", memo: "프로토타입 테스트용" });
  });
  const wallet = await prisma.wallet.findFirst({ where: { userId: user.id, currencyType: "POINT" } });
  console.log("복주머니 잔액:", wallet?.balance);
  console.log("USER_ID=" + user.id);
  console.log("EMAIL=" + email);
  console.log("PASSWORD=" + password);
}

main().then(() => process.exit(0)).catch((e) => { console.error(e); process.exit(1); });
