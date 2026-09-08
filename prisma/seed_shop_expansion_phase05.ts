// [상점 확장 Phase05] 사용자 요청 "인장/부적/촛불을 각 10개로 늘려달라"에 따라
// 기존 인장(5)/촛불(4)/부적(3) 카탈로그에 각각 5/6/7종을 추가해 모두 10종으로
// 맞춘다. 기존 항목은 그대로 두고(가격/기간/displayPriority 변경 없음),
// 신규 itemCode만 추가한다(append-only — seed_pouch_expansion_phase02.ts와
// 동일한 idempotent 패턴: itemCode가 이미 있으면 skip).
//
// [가격/기간 설계 원칙] 기존 계열(가격이 높을수록 보유기간도 길다)을 그대로
//따르되, 각 카테고리에 1~2개의 "rare"(고가/장기) 품목을 추가해 상점에
// 목표감을 부여한다. description에는 항상 "N일간 보유/지속 효과"를 명시해
// 구매 전 사용법을 알 수 있게 한다(기존 방침 유지).
//
// [실행] npx tsx prisma/seed_shop_expansion_phase05.ts
import "dotenv/config";
import { PrismaClient } from "../src/generated/prisma/client";
import { PrismaBetterSqlite3 } from "@prisma/adapter-better-sqlite3";

const adapter = new PrismaBetterSqlite3({
  url: process.env.DATABASE_URL ?? "file:./prisma/dev.db",
});
const prisma = new PrismaClient({ adapter });

const SHOP_ITEMS: Array<{
  itemType: "seal" | "candle" | "talisman";
  itemCode: string;
  nameKo: string;
  descriptionKo: string;
  price: number;
  durationDays: number | null;
  displayPriority: number;
}> = [
  // ── 인장(seal) 신규 5종 (기존 5종: displayPriority 1~5) ──
  { itemType: "seal", itemCode: "seal_bamboo", nameKo: "대나무 도장", descriptionKo: "곧은 절개를 상징하는 대나무를 새긴 도장 · 10일간 보유 효과", price: 20, durationDays: 10, displayPriority: 6 },
  { itemType: "seal", itemCode: "seal_pearl", nameKo: "진주 도장", descriptionKo: "귀한 진주를 품은 우아한 도장 · 21일간 보유 효과", price: 45, durationDays: 21, displayPriority: 7 },
  { itemType: "seal", itemCode: "seal_tiger", nameKo: "호랑이 도장", descriptionKo: "강인한 기운을 지닌 호랑이 문양 도장 · 30일간 보유 효과", price: 55, durationDays: 30, displayPriority: 8 },
  { itemType: "seal", itemCode: "seal_phoenix", nameKo: "봉황 도장", descriptionKo: "상서로운 봉황을 새긴 귀한 도장 · 35일간 보유 효과", price: 75, durationDays: 35, displayPriority: 9 },
  { itemType: "seal", itemCode: "seal_dragon", nameKo: "용 도장", descriptionKo: "하늘을 나는 용의 위엄을 새긴 최상급 도장 · 45일간 보유 효과", price: 90, durationDays: 45, displayPriority: 10 },

  // ── 촛불(candle) 신규 6종 (기존 4종: displayPriority 1~4) ──
  { itemType: "candle", itemCode: "candle_pine", nameKo: "송화초", descriptionKo: "솔향이 은은하게 감도는 초 · 14일간 보유 효과", price: 45, durationDays: 14, displayPriority: 5 },
  { itemType: "candle", itemCode: "candle_plum", nameKo: "매화초", descriptionKo: "매화 꽃잎을 닮은 화사한 초 · 18일간 보유 효과", price: 55, durationDays: 18, displayPriority: 6 },
  { itemType: "candle", itemCode: "candle_moon", nameKo: "달빛초", descriptionKo: "달빛처럼 차분하게 밝혀주는 초 · 25일간 보유 효과", price: 70, durationDays: 25, displayPriority: 7 },
  { itemType: "candle", itemCode: "candle_sunrise", nameKo: "해맞이초", descriptionKo: "새 아침의 기운을 담은 초 · 30일간 보유 효과", price: 85, durationDays: 30, displayPriority: 8 },
  { itemType: "candle", itemCode: "candle_phoenix", nameKo: "봉황초", descriptionKo: "봉황의 기운을 품은 귀한 초 · 40일간 보유 효과", price: 110, durationDays: 40, displayPriority: 9 },
  { itemType: "candle", itemCode: "candle_eternal", nameKo: "만년초", descriptionKo: "오래도록 꺼지지 않는 최상급 초 · 60일간 보유 효과", price: 130, durationDays: 60, displayPriority: 10 },

  // ── 부적(talisman) 신규 7종 (기존 3종: displayPriority 1~3) ──
  { itemType: "talisman", itemCode: "talisman_travel", nameKo: "여행 부적", descriptionKo: "먼 길을 안전하게 지켜주는 부적 · 14일간 지속", price: 25, durationDays: 14, displayPriority: 4 },
  { itemType: "talisman", itemCode: "talisman_health", nameKo: "평온 부적", descriptionKo: "마음의 평온을 지켜주는 부적 · 21일간 지속", price: 30, durationDays: 21, displayPriority: 5 },
  { itemType: "talisman", itemCode: "talisman_study", nameKo: "학업 부적", descriptionKo: "집중력을 높여주는 부적 · 21일간 지속", price: 35, durationDays: 21, displayPriority: 6 },
  { itemType: "talisman", itemCode: "talisman_dream", nameKo: "해몽 부적", descriptionKo: "좋은 꿈으로 이끌어주는 부적 · 21일간 지속", price: 40, durationDays: 21, displayPriority: 7 },
  { itemType: "talisman", itemCode: "talisman_love", nameKo: "인연 부적", descriptionKo: "좋은 인연을 이어주는 부적 · 30일간 지속", price: 45, durationDays: 30, displayPriority: 8 },
  { itemType: "talisman", itemCode: "talisman_wealth", nameKo: "재물 부적", descriptionKo: "재물운을 끌어주는 부적 · 30일간 지속", price: 50, durationDays: 30, displayPriority: 9 },
  { itemType: "talisman", itemCode: "talisman_phoenix", nameKo: "불사조 부적", descriptionKo: "어떤 역경도 이겨내게 하는 최상급 부적 · 100일간 지속", price: 120, durationDays: 100, displayPriority: 10 },
];

async function seedShopCatalog() {
  console.log("[seed_shop_expansion_phase05] shop_catalog_items 신규 항목 시딩...");
  let created = 0;
  let skipped = 0;
  for (const item of SHOP_ITEMS) {
    const existing = await prisma.shopCatalogItem.findUnique({ where: { itemCode: item.itemCode } });
    if (existing) {
      skipped++;
      continue;
    }
    await prisma.shopCatalogItem.create({
      data: { ...item, createdBy: "system_seed_phase05", updatedBy: "system_seed_phase05" },
    });
    created++;
  }
  console.log(`[seed_shop_expansion_phase05]    -> ${created}건 생성, ${skipped}건 기존 skip`);
}

async function main() {
  console.log("=== [Phase05] 상점 확장(인장/촛불/부적 각 10종) 시딩 시작 ===");
  await seedShopCatalog();
  const counts = await prisma.shopCatalogItem.groupBy({
    by: ["itemType"],
    _count: { itemType: true },
  });
  console.log("=== 카테고리별 최종 개수:", counts.map((c) => `${c.itemType}=${c._count.itemType}`).join(", "), "===");
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
