// Phase18-3 리워드 관리(지갑/포인트) 목업 데이터 시딩
// 04A C-1~C-4: wallets / point_histories / point_policies / point_expiry_batches
import "dotenv/config";
import { PrismaClient } from "../src/generated/prisma/client";
import { PrismaBetterSqlite3 } from "@prisma/adapter-better-sqlite3";

const adapter = new PrismaBetterSqlite3({
  url: process.env.DATABASE_URL ?? "file:./prisma/dev.db",
});
const prisma = new PrismaClient({ adapter });

// ── 1) point_policies: earn류 4개 + spend류(AI기능 무료/유료 정책) 6개 ──
// earn류: amount=지급액, dailyLimit=1일 최대 지급횟수
// spend류: amount=차감포인트, dailyLimit=1일 무료횟수(초과분부터 차감)
const POLICIES: Array<{
  sourceType: string;
  amount: number;
  dailyLimit: number | null;
  isActive: boolean;
}> = [
  // earn류 (출석/미션/이벤트/커뮤니티)
  { sourceType: "attendance", amount: 10, dailyLimit: 1, isActive: true },
  { sourceType: "mission", amount: 50, dailyLimit: 5, isActive: true },
  { sourceType: "event", amount: 100, dailyLimit: null, isActive: true },
  { sourceType: "community", amount: 5, dailyLimit: 10, isActive: true },
  // spend류 (AI 기능별 무료/유료 정책 — 02§2.4·§3 "1일 N회 무료, 초과시 차감")
  { sourceType: "ai_saju_request", amount: 100, dailyLimit: 1, isActive: true },
  { sourceType: "ai_daily_request", amount: 30, dailyLimit: 1, isActive: true },
  { sourceType: "ai_tarot_request", amount: 80, dailyLimit: 1, isActive: true },
  { sourceType: "ai_face_request", amount: 150, dailyLimit: 1, isActive: true },
  { sourceType: "ai_palm_request", amount: 150, dailyLimit: 1, isActive: true },
  { sourceType: "ai_consultation_message", amount: 20, dailyLimit: 10, isActive: true },
];

async function seedPointPolicies() {
  console.log("[seed_reward] 1) point_policies 시딩...");
  let count = 0;
  for (const p of POLICIES) {
    const existing = await prisma.pointPolicy.findUnique({ where: { sourceType: p.sourceType } });
    if (existing) continue;
    await prisma.pointPolicy.create({
      data: { ...p, createdBy: "system_seed", updatedBy: "system_seed" },
    });
    count++;
  }
  console.log(`[seed_reward]    -> ${count}건 생성 (기존 ${POLICIES.length - count}건 skip)`);
}

// ── 2) wallets: 전체 유저에 대해 1개씩 생성(POINT 화폐) ──
async function seedWallets() {
  console.log("[seed_reward] 2) wallets 시딩...");
  const users = await prisma.user.findMany({ select: { id: true } });
  let count = 0;
  for (const u of users) {
    const existing = await prisma.wallet.findUnique({
      where: { userId_currencyType: { userId: u.id, currencyType: "POINT" } },
    });
    if (existing) continue;
    await prisma.wallet.create({
      data: {
        userId: u.id,
        currencyType: "POINT",
        balance: 0,
        createdBy: "system_seed",
        updatedBy: "system_seed",
      },
    });
    count++;
  }
  console.log(`[seed_reward]    -> ${count}건 생성`);
}

// ── 3) point_histories: 각 유저별 최근 30일 랜덤 적립/차감 이력 생성, balance 트랜잭션 반영 ──
const EARN_SOURCES = ["attendance", "mission", "event", "community"];
const SPEND_SOURCES = [
  "ai_saju_request",
  "ai_daily_request",
  "ai_tarot_request",
  "ai_face_request",
  "ai_palm_request",
  "ai_consultation_message",
];

function randomInt(min: number, max: number) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

async function seedPointHistories() {
  console.log("[seed_reward] 3) point_histories 시딩(최근 30일)...");
  const existingCount = await prisma.pointHistory.count();
  if (existingCount > 0) {
    console.log(`[seed_reward]    -> 이미 ${existingCount}건 존재, skip`);
    return;
  }

  const wallets = await prisma.wallet.findMany();
  const policies = await prisma.pointPolicy.findMany();
  const policyMap = new Map(policies.map((p) => [p.sourceType, p]));

  let totalCount = 0;
  const now = new Date();

  for (const wallet of wallets) {
    let balance = 0;
    const events: Array<{ daysAgo: number; type: "earn" | "spend"; sourceType: string; amount: number }> = [];

    // 30일간 매일 0~3건의 랜덤 이벤트 생성
    for (let daysAgo = 29; daysAgo >= 0; daysAgo--) {
      const eventCountToday = randomInt(0, 3);
      for (let i = 0; i < eventCountToday; i++) {
        const isEarn = Math.random() < 0.55;
        if (isEarn) {
          const sourceType = EARN_SOURCES[randomInt(0, EARN_SOURCES.length - 1)];
          const policy = policyMap.get(sourceType);
          const amount = policy?.amount ?? 10;
          events.push({ daysAgo, type: "earn", sourceType, amount });
        } else {
          const sourceType = SPEND_SOURCES[randomInt(0, SPEND_SOURCES.length - 1)];
          const policy = policyMap.get(sourceType);
          const amount = -(policy?.amount ?? 50);
          events.push({ daysAgo, type: "spend", sourceType, amount });
        }
      }
    }
    // 관리자 수동 지급 1건 추가(포인트조정 화면 데모용)
    if (Math.random() < 0.3) {
      events.push({ daysAgo: randomInt(0, 10), type: "earn", sourceType: "admin_adjust", amount: 200 });
    }

    for (const ev of events) {
      // spend인데 balance 부족하면 skip(음수 방지)
      if (ev.amount < 0 && balance + ev.amount < 0) continue;
      balance += ev.amount;
      const createdAt = new Date(now);
      createdAt.setDate(createdAt.getDate() - ev.daysAgo);
      createdAt.setHours(randomInt(8, 22), randomInt(0, 59), 0, 0);

      await prisma.pointHistory.create({
        data: {
          walletId: wallet.id,
          userId: wallet.userId,
          amount: ev.amount,
          type: ev.type,
          sourceType: ev.sourceType,
          balanceAfter: balance,
          memo: ev.sourceType === "admin_adjust" ? "관리자 프로모션 수동 지급" : null,
          createdAt,
        },
      });
      totalCount++;
    }

    await prisma.wallet.update({
      where: { id: wallet.id },
      data: { balance, balanceSyncedAt: now },
    });
  }

  console.log(`[seed_reward]    -> ${totalCount}건 point_histories 생성, wallets.balance 동기화 완료`);
}

// ── 4) point_expiry_batches: 최근 6개월 매월 1회 배치 실행 이력 ──
async function seedExpiryBatches() {
  console.log("[seed_reward] 4) point_expiry_batches 시딩...");
  const existingCount = await prisma.pointExpiryBatch.count();
  if (existingCount > 0) {
    console.log(`[seed_reward]    -> 이미 ${existingCount}건 존재, skip`);
    return;
  }

  const now = new Date();
  let count = 0;
  for (let monthsAgo = 6; monthsAgo >= 1; monthsAgo--) {
    const targetDate = new Date(now);
    targetDate.setMonth(targetDate.getMonth() - monthsAgo);
    targetDate.setDate(1);

    await prisma.pointExpiryBatch.create({
      data: {
        targetDate,
        expiredAmountTotal: randomInt(500, 5000),
        processedUserCount: randomInt(3, 10),
      },
    });
    count++;
  }
  console.log(`[seed_reward]    -> ${count}건 생성`);
}

async function main() {
  console.log("=== Phase18-3 리워드(지갑/포인트) 목업 데이터 시딩 시작 ===");
  await seedPointPolicies();
  await seedWallets();
  await seedPointHistories();
  await seedExpiryBatches();
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
