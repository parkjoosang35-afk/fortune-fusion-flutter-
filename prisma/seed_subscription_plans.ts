import "dotenv/config";
import { PrismaClient } from "../src/generated/prisma/client";
import { PrismaBetterSqlite3 } from "@prisma/adapter-better-sqlite3";

const adapter = new PrismaBetterSqlite3({
  url: process.env.DATABASE_URL ?? "file:./prisma/dev.db",
});
const prisma = new PrismaClient({ adapter });

async function main() {
  // 04A K-3 명시: period는 monthly/yearly. benefits는 JSONB(기능단위 플래그,
  // 확장용) — 문자열 배열로 시딩(애플리케이션 레벨에서 JSON.stringify).
  const plansData = [
    {
      name: "베이직 월간",
      price: 9900,
      period: "monthly",
      benefits: JSON.stringify(["일일 운세 무제한", "광고 제거"]),
      isActive: true,
    },
    {
      name: "프리미엄 월간",
      price: 19900,
      period: "monthly",
      benefits: JSON.stringify(["일일 운세 무제한", "광고 제거", "궁합 분석 무제한", "타로 리딩 3회/일"]),
      isActive: true,
    },
    {
      name: "베이직 연간",
      price: 99000,
      period: "yearly",
      benefits: JSON.stringify(["일일 운세 무제한", "광고 제거", "연간 결제 17% 할인"]),
      isActive: true,
    },
    {
      name: "프리미엄 연간",
      price: 199000,
      period: "yearly",
      benefits: JSON.stringify([
        "일일 운세 무제한",
        "광고 제거",
        "궁합 분석 무제한",
        "타로 리딩 무제한",
        "연간 결제 17% 할인",
      ]),
      isActive: true,
    },
    {
      name: "구 베이직 월간(단종)",
      price: 7900,
      period: "monthly",
      benefits: JSON.stringify(["일일 운세 무제한"]),
      isActive: false,
    },
  ];

  for (const p of plansData) {
    await prisma.subscriptionPlan.create({
      data: { ...p, createdBy: "system", updatedBy: "system" },
    });
  }

  console.log(`SubscriptionPlans created: ${plansData.length}건`);
  await prisma.$disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
