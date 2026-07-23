// 상점 관리 — 복주머니 목업 데이터 시딩 스크립트
// 04A I-1 luckybag_products / I-2 luckybag_grades / I-3 luckybag_reward_pools /
//        I-4 luckybag_seasons / I-5 luckybag_open_logs
import "dotenv/config";
import { PrismaClient } from "../src/generated/prisma/client";
import { PrismaBetterSqlite3 } from "@prisma/adapter-better-sqlite3";

const adapter = new PrismaBetterSqlite3({
  url: process.env.DATABASE_URL ?? "file:./prisma/dev.db",
});
const prisma = new PrismaClient({ adapter });

// 04A I-2 명시: none/common/rare/best
const GRADES = [
  { code: "none", name: "꽝", sortOrder: 1 },
  { code: "common", name: "일반", sortOrder: 2 },
  { code: "rare", name: "희귀", sortOrder: 3 },
  { code: "best", name: "최고", sortOrder: 4 },
];

async function seedLuckybagGrades(): Promise<Map<string, number>> {
  console.log("[seed_luckybag] luckybag_grades 시딩...");
  const codeToId = new Map<string, number>();
  let created = 0;
  for (const g of GRADES) {
    const existing = await prisma.luckybagGrade.findUnique({ where: { code: g.code } });
    if (existing) {
      codeToId.set(g.code, existing.id);
      continue;
    }
    const row = await prisma.luckybagGrade.create({
      data: { ...g, createdBy: "system_seed", updatedBy: "system_seed" },
    });
    codeToId.set(g.code, row.id);
    created++;
  }
  console.log(`[seed_luckybag]    -> 등급 ${created}건 생성 (기존 ${GRADES.length - created}건 skip)`);
  return codeToId;
}

async function seedLuckybagSeasons(): Promise<Map<string, number>> {
  console.log("[seed_luckybag] luckybag_seasons 시딩...");
  const nameToId = new Map<string, number>();
  const SEASONS = [
    {
      name: "2026 설날 복주머니 시즌",
      startAt: new Date("2026-02-01T00:00:00Z"),
      endAt: new Date("2026-02-28T23:59:59Z"),
    },
    {
      name: "2026 여름 행운 이벤트",
      startAt: new Date("2026-07-01T00:00:00Z"),
      endAt: new Date("2026-08-31T23:59:59Z"),
    },
  ];
  let created = 0;
  for (const s of SEASONS) {
    const existing = await prisma.luckybagSeason.findFirst({ where: { name: s.name } });
    if (existing) {
      nameToId.set(s.name, existing.id);
      continue;
    }
    const row = await prisma.luckybagSeason.create({
      data: { ...s, createdBy: "system_seed", updatedBy: "system_seed" },
    });
    nameToId.set(s.name, row.id);
    created++;
  }
  console.log(`[seed_luckybag]    -> 시즌 ${created}건 생성`);
  return nameToId;
}

interface RewardPoolSeed {
  gradeCode: string;
  rewardType: string;
  rewardAmount?: number;
  probability: number;
}

interface ProductSeed {
  name: string;
  pricePoint: number;
  imageUrl: string;
  seasonName?: string;
  rewardPools: RewardPoolSeed[];
}

const PRODUCTS: ProductSeed[] = [
  {
    name: "일반 복주머니",
    pricePoint: 1000,
    imageUrl: "https://placehold.co/300x300/dc2626/ffffff?text=Lucky+Bag",
    rewardPools: [
      { gradeCode: "none", rewardType: "none", probability: 50 },
      { gradeCode: "common", rewardType: "point", rewardAmount: 100, probability: 35 },
      { gradeCode: "rare", rewardType: "point", rewardAmount: 500, probability: 10 },
      { gradeCode: "best", rewardType: "giftcard_fragment", rewardAmount: 1, probability: 5 },
    ],
  },
  {
    name: "고급 복주머니",
    pricePoint: 3000,
    imageUrl: "https://placehold.co/300x300/f59e0b/ffffff?text=Premium+Bag",
    rewardPools: [
      { gradeCode: "none", rewardType: "none", probability: 30 },
      { gradeCode: "common", rewardType: "point", rewardAmount: 300, probability: 40 },
      { gradeCode: "rare", rewardType: "amulet", probability: 25 },
      { gradeCode: "best", rewardType: "giftcard_fragment", rewardAmount: 1, probability: 5 },
    ],
  },
  {
    name: "설날 한정 황금 복주머니",
    pricePoint: 5000,
    imageUrl: "https://placehold.co/300x300/facc15/ffffff?text=Golden+Bag",
    seasonName: "2026 설날 복주머니 시즌",
    rewardPools: [
      { gradeCode: "none", rewardType: "none", probability: 20 },
      { gradeCode: "common", rewardType: "point", rewardAmount: 500, probability: 40 },
      { gradeCode: "rare", rewardType: "amulet", probability: 30 },
      { gradeCode: "best", rewardType: "giftcard_fragment", rewardAmount: 1, probability: 10 },
    ],
  },
];

async function seedLuckybagProducts(
  gradeMap: Map<string, number>,
  seasonMap: Map<string, number>
): Promise<void> {
  console.log("[seed_luckybag] luckybag_products + reward_pools 시딩...");
  let productCreated = 0;
  let poolCreated = 0;

  for (const p of PRODUCTS) {
    // 확률 합계 검증(애플리케이션 레벨) — 시딩 데이터도 반드시 100% 준수
    const sum = p.rewardPools.reduce((acc, rp) => acc + rp.probability, 0);
    if (Math.abs(sum - 100) > 0.0001) {
      console.error(
        `[seed_luckybag] 오류: "${p.name}" 보상풀 확률 합계가 100이 아닙니다 (합계=${sum}). 스킵합니다.`
      );
      continue;
    }

    const existing = await prisma.luckybagProduct.findFirst({ where: { name: p.name } });
    if (existing) continue;

    const seasonId = p.seasonName ? seasonMap.get(p.seasonName) ?? null : null;

    const created = await prisma.luckybagProduct.create({
      data: {
        name: p.name,
        pricePoint: p.pricePoint,
        imageUrl: p.imageUrl,
        seasonId,
        createdBy: "system_seed",
        updatedBy: "system_seed",
      },
    });
    productCreated++;

    for (const rp of p.rewardPools) {
      const gradeId = gradeMap.get(rp.gradeCode);
      if (!gradeId) {
        console.warn(`[seed_luckybag] 경고: 등급 코드 ${rp.gradeCode}를 찾을 수 없어 스킵합니다.`);
        continue;
      }
      await prisma.luckybagRewardPool.create({
        data: {
          luckybagProductId: created.id,
          gradeId,
          rewardType: rp.rewardType,
          rewardAmount: rp.rewardAmount ?? null,
          probability: rp.probability,
          createdBy: "system_seed",
          updatedBy: "system_seed",
        },
      });
      poolCreated++;
    }
  }

  console.log(`[seed_luckybag]    -> 복주머니상품 ${productCreated}건, 보상풀 ${poolCreated}건 생성`);
}

async function seedLuckybagOpenLogs(): Promise<void> {
  console.log("[seed_luckybag] luckybag_open_logs 시딩(조회 전용 샘플)...");

  const existingCount = await prisma.luckybagOpenLog.count();
  if (existingCount > 0) {
    console.log(`[seed_luckybag]    -> 이미 ${existingCount}건 존재, 스킵`);
    return;
  }

  const users = await prisma.user.findMany({ orderBy: { id: "asc" }, take: 10 });
  const products = await prisma.luckybagProduct.findMany({
    where: { deletedAt: null },
    include: { rewardPools: true },
  });

  if (users.length === 0 || products.length === 0) {
    console.warn("[seed_luckybag] 경고: users 또는 luckybag_products가 없어 개봉이력 시딩을 스킵합니다.");
    return;
  }

  let created = 0;
  for (let i = 0; i < 15; i++) {
    const user = users[i % users.length];
    const product = products[i % products.length];
    if (product.rewardPools.length === 0) continue;
    const pool = product.rewardPools[i % product.rewardPools.length];
    const status = i % 10 === 9 ? "failed" : "completed";

    await prisma.luckybagOpenLog.create({
      data: {
        userId: user.id,
        luckybagProductId: product.id,
        rewardPoolId: pool.id,
        rewardResult: JSON.stringify({
          rewardType: pool.rewardType,
          rewardAmount: pool.rewardAmount,
        }),
        status,
        createdAt: new Date(Date.now() - (15 - i) * 3600000),
        createdBy: "system_seed",
        updatedBy: "system_seed",
      },
    });
    created++;
  }
  console.log(`[seed_luckybag]    -> 개봉이력 ${created}건 생성`);
}

async function main() {
  console.log("=== 상점관리(복주머니) 목업 데이터 시딩 시작 ===");
  const gradeMap = await seedLuckybagGrades();
  const seasonMap = await seedLuckybagSeasons();
  await seedLuckybagProducts(gradeMap, seasonMap);
  await seedLuckybagOpenLogs();
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
