import { prisma } from "../src/lib/db";
import bcrypt from "bcryptjs";
import { earnLuckPouch } from "../src/lib/luck-pouch-engine";

async function main() {
  const email = "wrtest@example.com";
  const password = "test1234";
  const passwordHash = await bcrypt.hash(password, 10);

  let user = await prisma.user.findUnique({ where: { email } });
  if (!user) {
    user = await prisma.user.create({
      data: { email, passwordHash, nickname: "wrtest", status: "active" },
    });
    console.log("생성된 유저:", user.id);
  } else {
    console.log("기존 유저 재사용:", user.id);
  }

  await prisma.$transaction(async (tx) => {
    await earnLuckPouch(tx, { userId: user!.id, amount: 500, sourceType: "manual", memo: "소원방 QA 복주머니 지급" });
  });
  const wallet = await prisma.wallet.findFirst({ where: { userId: user.id, currencyType: "POINT" } });
  console.log("복주머니 잔액:", wallet?.balance);
  console.log("USER_ID=" + user.id);
  console.log("EMAIL=" + email);
  console.log("PASSWORD=" + password);
}

main().then(() => process.exit(0)).catch((e) => { console.error(e); process.exit(1); });
