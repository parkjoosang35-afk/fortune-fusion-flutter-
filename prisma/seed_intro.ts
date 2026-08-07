import "dotenv/config";
import { PrismaClient } from "../src/generated/prisma/client";
import { PrismaBetterSqlite3 } from "@prisma/adapter-better-sqlite3";

const adapter = new PrismaBetterSqlite3({
  url: process.env.DATABASE_URL ?? "file:./prisma/dev.db",
});
const prisma = new PrismaClient({ adapter });

async function main() {
  // 1) signup_reward PointPolicy 시딩(CAP_EXEMPT 대상 아님 -> 일일상한 영향 없게 하려면
  //    라우트에서 admin_grant로 처리하거나, 별도 처리. 여기서는 정책값(수량) 관리 목적만.)
  const existing = await prisma.pointPolicy.findUnique({ where: { sourceType: "signup_reward" } });
  if (!existing) {
    await prisma.pointPolicy.create({
      data: {
        sourceType: "signup_reward",
        amount: 100,
        dailyLimit: 1,
        isActive: true,
      },
    });
    console.log("[seed_intro] point_policies.signup_reward 생성 완료 (amount=100)");
  } else {
    console.log("[seed_intro] point_policies.signup_reward 이미 존재:", existing);
  }

  // 2) IntroConfig 싱글턴 row(id=1) 생성
  const introExisting = await prisma.introConfig.findUnique({ where: { id: 1 } });
  if (!introExisting) {
    await prisma.introConfig.create({ data: { id: 1 } });
    console.log("[seed_intro] intro_configs id=1 기본값으로 생성 완료");
  } else {
    console.log("[seed_intro] intro_configs id=1 이미 존재");
  }
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
