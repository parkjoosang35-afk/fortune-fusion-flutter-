// [친구 초대 "N명 모으면 축하 이벤트" 실제 기능화 — 2026-09]
//
// 기존 Flutter 공유 화면(`guinji_map_share_screen.dart`)의 "3명 모으면
// 축하 이벤트가 열려요" 배너가 실제로는 아무 기능도 연결되지 않은
// 순수 장식 문구였다는 사용자 지적("도대체 뭐야? 이벤트를 기획해서
// 기능을 넣어주던지")을 해결하기 위한 PointPolicy 신규 등록.
//
// - guinji_milestone_3: 지도 소유자의 활성 멤버(참여자)가 3명에 도달하는
//   "그 순간"(GET /guinji/maps/me 조회 시점) 지급되는 1회성 축하 보너스.
//   amount=30, dailyLimit=1 + 호출부(maps/me/route.ts)에서 scope:'lifetime'
//   으로 checkPolicyEligibility를 호출하므로 평생 1회만 지급된다.
//
// [실행] npx tsx prisma/seed_guinji_milestone_policy.ts
import "dotenv/config";
import { PrismaClient } from "../src/generated/prisma/client";
import { PrismaBetterSqlite3 } from "@prisma/adapter-better-sqlite3";

const adapter = new PrismaBetterSqlite3({
  url: process.env.DATABASE_URL ?? "file:./prisma/dev.db",
});
const prisma = new PrismaClient({ adapter });

const POLICIES: Array<{
  sourceType: string;
  amount: number;
  dailyLimit: number | null;
  isActive: boolean;
}> = [
  { sourceType: "guinji_milestone_3", amount: 30, dailyLimit: 1, isActive: true },
];

async function main() {
  console.log("=== [귀인지도 마일스톤] PointPolicy 시딩 시작 ===");
  let created = 0;
  let skipped = 0;
  for (const p of POLICIES) {
    const existing = await prisma.pointPolicy.findUnique({ where: { sourceType: p.sourceType } });
    if (existing) {
      skipped++;
      continue;
    }
    await prisma.pointPolicy.create({
      data: { ...p, createdBy: "system_seed_guinji_milestone", updatedBy: "system_seed_guinji_milestone" },
    });
    created++;
  }
  console.log(`=== 완료: ${created}건 생성, ${skipped}건 기존 skip ===`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
