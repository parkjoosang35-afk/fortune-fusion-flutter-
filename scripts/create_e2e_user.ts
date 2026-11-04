import { prisma } from "../src/lib/db";
import bcrypt from "bcryptjs";

async function main() {
  const email = "gh_e2e_webcheck@example.com";
  const password = "TestPass1234!";
  const passwordHash = await bcrypt.hash(password, 10);
  const user = await prisma.user.upsert({
    where: { email },
    update: { passwordHash, status: "active" },
    create: { email, nickname: "궁합E2E검수", passwordHash, gender: "male", status: "active" },
  });
  const existing = await prisma.wallet.findFirst({ where: { userId: user.id, currencyType: "POINT" } });
  await prisma.wallet.upsert({
    where: { id: existing?.id ?? -1 },
    update: { balance: 1000 },
    create: { userId: user.id, currencyType: "POINT", balance: 1000 },
  });
  console.log(JSON.stringify({ userId: user.id, email, password }));
}
main().finally(() => prisma.$disconnect());
