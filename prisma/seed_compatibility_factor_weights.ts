// 04A F-3 compatibility_factor_weights 시드 데이터
// 05_Admin_System_Design.md §3.6 "매칭/궁합 관리" — 5차 소단위(궁합 요소
// 가중치 설정). 04A 명시 5종 factor_type(saju/mbti/interest/value/
// activity_pattern)을 모두 시딩하며, 활성(is_active=true) 항목의 weight
// 합계가 1.00이 되도록 구성한다(04A "합 1.00 권장" 명시 충족 상태로 초기화).
import "dotenv/config";
import { PrismaClient } from "../src/generated/prisma/client";
import { PrismaBetterSqlite3 } from "@prisma/adapter-better-sqlite3";

const adapter = new PrismaBetterSqlite3({
  url: process.env.DATABASE_URL ?? "file:./prisma/dev.db",
});
const prisma = new PrismaClient({ adapter });

async function main() {
  const weights = [
    { factorType: "saju", weight: 0.35, isActive: true },
    { factorType: "mbti", weight: 0.25, isActive: true },
    { factorType: "interest", weight: 0.2, isActive: true },
    { factorType: "value", weight: 0.15, isActive: true },
    { factorType: "activity_pattern", weight: 0.05, isActive: true },
  ];
  for (const w of weights) {
    await prisma.compatibilityFactorWeight.create({
      data: { ...w, createdBy: "system", updatedBy: "system" },
    });
  }
  console.log(`CompatibilityFactorWeights created: ${weights.length}건 (합계: ${weights.reduce((s, w) => s + w.weight, 0).toFixed(2)})`);

  await prisma.$disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
