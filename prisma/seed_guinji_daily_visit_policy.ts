// [귀인지도(Guinji Map) Phase B-4 — PointPolicy 신규 등록: guinji_daily_visit]
//
// 신통방통_귀인지도_최종_개발계획서_v2.0.md §11 "매일 첫 /guinji 방문 → 출석 적립"
// 트리거를 PointPolicy로 등록한다(절대원칙: 모든 지급은 PointPolicy 등록).
// amount=3(기존 attendance 정책과 동일 수준으로 통일 — §11은 구체 금액을 명시하지
// 않았으므로 유사 "1일 1회 방문형" 보상인 attendance(3P)를 기준값으로 삼음),
// dailyLimit=1(하루 1회, KST 자정 기준 — checkPolicyEligibility(scope:'daily')로 강제).
//
// [실행] npx tsx prisma/seed_guinji_daily_visit_policy.ts
import "dotenv/config";
import { PrismaClient } from "../src/generated/prisma/client";
import { PrismaBetterSqlite3 } from "@prisma/adapter-better-sqlite3";

const adapter = new PrismaBetterSqlite3({
  url: process.env.DATABASE_URL ?? "file:./prisma/dev.db",
});
const prisma = new PrismaClient({ adapter });

async function main() {
  console.log("=== [귀인지도 Phase B-4] guinji_daily_visit PointPolicy 시딩 시작 ===");
  const existing = await prisma.pointPolicy.findUnique({ where: { sourceType: "guinji_daily_visit" } });
  if (existing) {
    console.log("=== 이미 존재 — skip ===");
    return;
  }
  await prisma.pointPolicy.create({
    data: {
      sourceType: "guinji_daily_visit",
      amount: 3,
      dailyLimit: 1,
      isActive: true,
      createdBy: "system_seed_guinji",
      updatedBy: "system_seed_guinji",
    },
  });
  console.log("=== 완료: 1건 생성 ===");
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
