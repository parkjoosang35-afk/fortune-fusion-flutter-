// [소원방 3대 개선 - Phase04] "오늘의 3가지 완성" 콤보 보너스 PointPolicy 신규 등록.
//
// [배경] 복주머니 "받기" 채널을 기존 6개(중 다수가 실제 행동 없이 즉시 지급되는
// 문제가 있었음)에서 10채널로 재설계하면서, 마지막 10번째 채널로 "제단 참배 +
// 오늘의 촛불 + 모두의 소원방 둘러보기" 3가지를 모두 완료했을 때 지급되는 콤보
// 보너스를 신설한다. 판정 로직은 src/lib/luck-pouch-engine.ts의
// maybeGrantDailyWishComboBonus()가 담당하고, 이 seed는 그 판정이 참조하는
// PointPolicy.daily_wish_combo 레코드(amount=3, dailyLimit=1)만 등록한다.
//
// dailyLimit=1은 이 정책에서는 실질적으로 사용되지 않는다(콤보 판정 자체가
// "오늘 이미 지급했는지"를 PointHistory에서 직접 조회해 중복을 막으므로) —
// 그래도 관리자 화면에 "1일 1회" 정책으로 일관되게 노출되도록 1로 채운다.
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
}> = [{ sourceType: "daily_wish_combo", amount: 3, dailyLimit: 1, isActive: true }];

async function main() {
  console.log("[seed_wish_combo_phase04] point_policies 시딩...");
  let created = 0;
  let skipped = 0;
  for (const p of POLICIES) {
    const existing = await prisma.pointPolicy.findUnique({ where: { sourceType: p.sourceType } });
    if (existing) {
      skipped++;
      continue;
    }
    await prisma.pointPolicy.create({
      data: { ...p, createdBy: "system_seed_phase04", updatedBy: "system_seed_phase04" },
    });
    created++;
  }
  console.log(`[seed_wish_combo_phase04]    -> ${created}건 생성, ${skipped}건 기존 skip`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
