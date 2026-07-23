// 상점 관리 — 디지털부적 상품 목업 데이터 시딩 스크립트
// 04A H-1 amulet_items + H-2 amulet_grades (마스터)
import "dotenv/config";
import { PrismaClient } from "../src/generated/prisma/client";
import { PrismaBetterSqlite3 } from "@prisma/adapter-better-sqlite3";

const adapter = new PrismaBetterSqlite3({
  url: process.env.DATABASE_URL ?? "file:./prisma/dev.db",
});
const prisma = new PrismaClient({ adapter });

// 04A H-2 명시: common/rare/heroic/legendary
const GRADES = [
  { code: "common", name: "일반", sortOrder: 1 },
  { code: "rare", name: "희귀", sortOrder: 2 },
  { code: "heroic", name: "영웅", sortOrder: 3 },
  { code: "legendary", name: "전설", sortOrder: 4 },
];

const AMULET_ITEMS = [
  {
    name: "행운의 네잎클로버 부적",
    gradeCode: "common",
    effectDescription: "소소한 행운을 불러오는 기본 부적입니다.",
    imageUrl: "https://placehold.co/300x300/22c55e/ffffff?text=Clover+Amulet",
    isAiGenerated: false,
    pricePoint: 500,
    isLimited: false,
  },
  {
    name: "재물운 상승 부적",
    gradeCode: "common",
    effectDescription: "재물운을 은은하게 높여주는 입문용 부적입니다.",
    imageUrl: "https://placehold.co/300x300/eab308/ffffff?text=Wealth+Amulet",
    isAiGenerated: true,
    pricePoint: 800,
    isLimited: false,
  },
  {
    name: "청룡의 수호 부적",
    gradeCode: "rare",
    effectDescription: "청룡의 기운으로 나쁜 기운을 막아주는 부적입니다.",
    imageUrl: "https://placehold.co/300x300/3b82f6/ffffff?text=Azure+Dragon",
    isAiGenerated: true,
    pricePoint: 2000,
    isLimited: false,
  },
  {
    name: "인연의 실타래 부적",
    gradeCode: "rare",
    effectDescription: "좋은 인연을 이어주는 힘이 담긴 부적입니다.",
    imageUrl: "https://placehold.co/300x300/ec4899/ffffff?text=Fate+Thread",
    isAiGenerated: true,
    pricePoint: 2500,
    isLimited: false,
  },
  {
    name: "백호의 용맹 부적",
    gradeCode: "heroic",
    effectDescription: "백호의 기운을 담아 도전에 필요한 용기를 북돋아 줍니다.",
    imageUrl: "https://placehold.co/300x300/64748b/ffffff?text=White+Tiger",
    isAiGenerated: true,
    pricePoint: 5000,
    isLimited: false,
  },
  {
    name: "황금 봉황 승진 부적",
    gradeCode: "legendary",
    effectDescription: "황금 봉황의 기운으로 큰 성취와 승진을 기원하는 한정판 부적입니다.",
    imageUrl: "https://placehold.co/300x300/f59e0b/ffffff?text=Golden+Phoenix",
    isAiGenerated: true,
    pricePoint: 12000,
    isLimited: true,
  },
];

async function seedAmuletGrades(): Promise<Map<string, number>> {
  console.log("[seed_amulets] amulet_grades 시딩...");
  const codeToId = new Map<string, number>();
  let created = 0;
  for (const g of GRADES) {
    const existing = await prisma.amuletGrade.findUnique({ where: { code: g.code } });
    if (existing) {
      codeToId.set(g.code, existing.id);
      continue;
    }
    const row = await prisma.amuletGrade.create({
      data: { ...g, createdBy: "system_seed", updatedBy: "system_seed" },
    });
    codeToId.set(g.code, row.id);
    created++;
  }
  console.log(`[seed_amulets]    -> 등급 ${created}건 생성 (기존 ${GRADES.length - created}건 skip)`);
  return codeToId;
}

async function seedAmuletItems(gradeMap: Map<string, number>) {
  console.log("[seed_amulets] amulet_items 시딩...");
  let created = 0;
  for (const item of AMULET_ITEMS) {
    const existing = await prisma.amuletItem.findFirst({ where: { name: item.name } });
    if (existing) continue;
    const gradeId = gradeMap.get(item.gradeCode);
    if (!gradeId) {
      console.warn(`[seed_amulets] 경고: 등급 코드 ${item.gradeCode}를 찾을 수 없어 스킵합니다.`);
      continue;
    }
    const { gradeCode, ...rest } = item;
    void gradeCode;
    await prisma.amuletItem.create({
      data: { ...rest, gradeId, createdBy: "system_seed", updatedBy: "system_seed" },
    });
    created++;
  }
  console.log(`[seed_amulets]    -> 부적상품 ${created}건 생성 (기존 ${AMULET_ITEMS.length - created}건 skip)`);
}

async function main() {
  console.log("=== 상점관리(디지털부적) 목업 데이터 시딩 시작 ===");
  const gradeMap = await seedAmuletGrades();
  await seedAmuletItems(gradeMap);
  console.log("=== 시딩 완료 ===");
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
