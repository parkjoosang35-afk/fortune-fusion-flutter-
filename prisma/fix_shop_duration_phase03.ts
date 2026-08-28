// [상점 기획 결함 수정 - Phase03] 이미 시딩된 shop_catalog_items 중 seal/candle의
// duration_days가 null(영구 보유)로 잘못 들어간 기존 레코드를 올바른 값으로
// 갱신하고, 이미 구매되어 expires_at이 null인 인벤토리 항목도 "구매 시점 +
// 새 durationDays"로 소급 계산해 채워 넣는다.
//
// [원칙] 카탈로그 price는 절대 변경하지 않는다(경제 밸런스 유지) — durationDays만
// 보정한다. 인벤토리 expiresAt 소급은 "purchasedAt + durationDays"로 계산하되,
// 이미 그 기간이 지났다면 "지금부터 1일" 유예를 준다(사용자가 이미 산 물건이
// 갑자기 소급 만료 처리되어 손해보지 않도록 하는 안전장치).
//
// [실행] npx tsx prisma/fix_shop_duration_phase03.ts
import "dotenv/config";
import { PrismaClient } from "../src/generated/prisma/client";
import { PrismaBetterSqlite3 } from "@prisma/adapter-better-sqlite3";

const adapter = new PrismaBetterSqlite3({
  url: process.env.DATABASE_URL ?? "file:./prisma/dev.db",
});
const prisma = new PrismaClient({ adapter });

const DURATION_FIX: Record<string, number> = {
  seal_jade: 14,
  seal_silver: 21,
  seal_turtle: 30,
  seal_crane: 30,
  seal_gold_leaf: 30,
  candle_lotus: 14,
  candle_incense: 21,
  candle_star: 30,
  candle_jade_wax: 45,
};

async function main() {
  console.log("=== [Phase03] 인장/촛불 기간제 소급 수정 시작 ===");

  // 1) 카탈로그 durationDays 갱신
  let catalogUpdated = 0;
  for (const [itemCode, durationDays] of Object.entries(DURATION_FIX)) {
    const item = await prisma.shopCatalogItem.findUnique({ where: { itemCode } });
    if (!item) {
      console.log(`  [skip] ${itemCode} 카탈로그 없음`);
      continue;
    }
    if (item.durationDays === durationDays) {
      continue;
    }
    await prisma.shopCatalogItem.update({
      where: { itemCode },
      data: { durationDays, updatedBy: "system_fix_phase03" },
    });
    catalogUpdated++;
    console.log(`  [catalog] ${itemCode}: durationDays -> ${durationDays}`);
  }
  console.log(`카탈로그 ${catalogUpdated}건 갱신`);

  // 2) 이미 구매된 인벤토리 중 expiresAt이 null인 seal/candle 항목 소급 계산
  const targets = await prisma.userInventoryItem.findMany({
    where: { expiresAt: null },
    include: { catalogItem: true },
  });
  let inventoryUpdated = 0;
  const now = Date.now();
  for (const row of targets) {
    const durationDays = DURATION_FIX[row.catalogItem.itemCode];
    if (!durationDays) continue; // talisman 등 이미 기간제였던 품목은 손대지 않음
    const naiveExpiry = row.createdAt.getTime() + durationDays * 24 * 60 * 60 * 1000;
    // 이미 지났다면(과거 구매분) 지금부터 1일 유예를 준다 — 소급 손해 방지.
    const expiresAt = new Date(Math.max(naiveExpiry, now + 24 * 60 * 60 * 1000));
    await prisma.userInventoryItem.update({
      where: { id: row.id },
      data: { expiresAt },
    });
    inventoryUpdated++;
    console.log(
      `  [inventory] id=${row.id} ${row.catalogItem.itemCode} -> expiresAt=${expiresAt.toISOString()}`
    );
  }
  console.log(`인벤토리 ${inventoryUpdated}건 소급 갱신`);
  console.log("=== 완료 ===");
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
