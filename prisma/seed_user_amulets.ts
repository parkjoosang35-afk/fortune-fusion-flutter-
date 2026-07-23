// 상점 관리 — 부적 지급/보유 이력 목업 데이터 시딩 스크립트
// 04A H-3 user_amulets / H-4 amulet_usage_logs / H-5 amulet_gifts / H-6 amulet_collections
// 회원 활동 결과 데이터이므로 조회 전용 화면(다음 소단위: shop/amulets 페이지 내 섹션)용 샘플 생성.
import "dotenv/config";
import { PrismaClient } from "../src/generated/prisma/client";
import { PrismaBetterSqlite3 } from "@prisma/adapter-better-sqlite3";

const adapter = new PrismaBetterSqlite3({
  url: process.env.DATABASE_URL ?? "file:./prisma/dev.db",
});
const prisma = new PrismaClient({ adapter });

const SOURCE_TYPES = ["purchase", "event", "gift", "luckybag"] as const;
const STATUSES = ["held", "used", "expired", "gifted"] as const;

function pick<T>(arr: readonly T[], seed: number): T {
  return arr[seed % arr.length];
}

async function seedUserAmulets(): Promise<void> {
  console.log("[seed_user_amulets] user_amulets 시딩...");

  const existingCount = await prisma.userAmulet.count();
  if (existingCount > 0) {
    console.log(`[seed_user_amulets]    -> 이미 ${existingCount}건 존재, 스킵`);
    return;
  }

  const users = await prisma.user.findMany({ orderBy: { id: "asc" }, take: 10 });
  const items = await prisma.amuletItem.findMany({ where: { deletedAt: null }, orderBy: { id: "asc" } });

  if (users.length === 0 || items.length === 0) {
    console.warn("[seed_user_amulets] 경고: users 또는 amulet_items가 없어 시딩을 스킵합니다.");
    return;
  }

  let uaCreated = 0;
  let usageCreated = 0;
  let giftCreated = 0;
  let collectionCreated = 0;

  const createdUserAmulets: { id: number; userId: number; amuletItemId: number; status: string }[] = [];

  // 회원 10명 x 부적상품을 순환 배정하여 user_amulets 20건 생성
  for (let i = 0; i < 20; i++) {
    const user = pick(users, i);
    const item = pick(items, i + 1);
    const sourceType = pick(SOURCE_TYPES, i);
    const status = pick(STATUSES, i);
    const acquiredAt = new Date(Date.now() - (20 - i) * 86400000);
    const expiresAt = status === "expired" ? new Date(Date.now() - 1 * 86400000) : null;

    const ua = await prisma.userAmulet.create({
      data: {
        userId: user.id,
        amuletItemId: item.id,
        acquiredAt,
        expiresAt,
        sourceType,
        status,
        createdBy: "system_seed",
        updatedBy: "system_seed",
      },
    });
    createdUserAmulets.push({ id: ua.id, userId: user.id, amuletItemId: item.id, status });
    uaCreated++;
  }

  console.log(`[seed_user_amulets]    -> user_amulets ${uaCreated}건 생성`);

  // H-4 amulet_usage_logs: status=used 인 건에 대해 사용 로그 1건씩 생성
  const usedOnes = createdUserAmulets.filter((ua) => ua.status === "used");
  for (const ua of usedOnes) {
    await prisma.amuletUsageLog.create({
      data: {
        userAmuletId: ua.id,
        usedContextType: "fortune_request",
        usedContextId: ua.userId,
      },
    });
    usageCreated++;
  }
  console.log(`[seed_user_amulets]    -> amulet_usage_logs ${usageCreated}건 생성`);

  // H-5 amulet_gifts: status=gifted 인 건에 대해 선물 로그 생성 (다른 회원에게)
  const giftedOnes = createdUserAmulets.filter((ua) => ua.status === "gifted");
  for (const ua of giftedOnes) {
    const toUser = users.find((u) => u.id !== ua.userId) ?? users[0];
    await prisma.amuletGift.create({
      data: {
        fromUserId: ua.userId,
        toUserId: toUser.id,
        userAmuletId: ua.id,
        message: "행운이 가득하길 바라며 선물합니다!",
        createdBy: "system_seed",
        updatedBy: "system_seed",
      },
    });
    giftCreated++;
  }
  console.log(`[seed_user_amulets]    -> amulet_gifts ${giftCreated}건 생성`);

  // H-6 amulet_collections: user_id + amulet_item_id 조합의 최초 획득 정보(도감)
  const seen = new Set<string>();
  for (const ua of createdUserAmulets) {
    const key = `${ua.userId}:${ua.amuletItemId}`;
    if (seen.has(key)) continue;
    seen.add(key);
    const existing = await prisma.amuletCollection.findUnique({
      where: { userId_amuletItemId: { userId: ua.userId, amuletItemId: ua.amuletItemId } },
    });
    if (existing) continue;
    await prisma.amuletCollection.create({
      data: {
        userId: ua.userId,
        amuletItemId: ua.amuletItemId,
        totalCount: 1,
        createdBy: "system_seed",
        updatedBy: "system_seed",
      },
    });
    collectionCreated++;
  }
  console.log(`[seed_user_amulets]    -> amulet_collections ${collectionCreated}건 생성`);
}

async function main() {
  console.log("=== 부적 지급/보유 이력 목업 데이터 시딩 시작 ===");
  await seedUserAmulets();
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
