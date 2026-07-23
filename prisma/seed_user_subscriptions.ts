import "dotenv/config";
import { PrismaClient } from "../src/generated/prisma/client";
import { PrismaBetterSqlite3 } from "@prisma/adapter-better-sqlite3";

const adapter = new PrismaBetterSqlite3({
  url: process.env.DATABASE_URL ?? "file:./prisma/dev.db",
});
const prisma = new PrismaClient({ adapter });

function daysFromNow(days: number): Date {
  return new Date(Date.now() + days * 24 * 60 * 60 * 1000);
}
function daysAgo(days: number): Date {
  return new Date(Date.now() - days * 24 * 60 * 60 * 1000);
}

async function main() {
  const subsData = [
    // 1) active - 베이직 월간, 정상 진행중
    {
      userId: 1,
      planId: 1,
      status: "active",
      startedAt: daysAgo(10),
      currentPeriodEnd: daysFromNow(20),
      pgSubscriptionId: "sub_toss_0001",
    },
    // 2) active - 프리미엄 연간
    {
      userId: 2,
      planId: 4,
      status: "active",
      startedAt: daysAgo(30),
      currentPeriodEnd: daysFromNow(335),
      pgSubscriptionId: "sub_toss_0002",
    },
    // 3) active - 베이직 연간
    {
      userId: 3,
      planId: 3,
      status: "active",
      startedAt: daysAgo(5),
      currentPeriodEnd: daysFromNow(360),
      pgSubscriptionId: "sub_iamport_0003",
    },
    // 4) cancelled - 관리자 강제해지된 것으로 가정(과거 이력)
    {
      userId: 4,
      planId: 2,
      status: "cancelled",
      startedAt: daysAgo(60),
      currentPeriodEnd: daysAgo(30),
      pgSubscriptionId: "sub_toss_0004",
    },
    // 5) expired - 기간 만료
    {
      userId: 5,
      planId: 1,
      status: "expired",
      startedAt: daysAgo(90),
      currentPeriodEnd: daysAgo(60),
      pgSubscriptionId: "sub_toss_0005",
    },
    // 6) past_due - 결제 실패로 연체
    {
      userId: 6,
      planId: 2,
      status: "past_due",
      startedAt: daysAgo(40),
      currentPeriodEnd: daysAgo(2),
      pgSubscriptionId: "sub_iamport_0006",
    },
    // 7) active - 프리미엄 월간
    {
      userId: 7,
      planId: 2,
      status: "active",
      startedAt: daysAgo(3),
      currentPeriodEnd: daysFromNow(27),
      pgSubscriptionId: "sub_toss_0007",
    },
    // 8) active - 베이직 월간, pg_subscription_id 없이(수동등록 가정)
    {
      userId: 8,
      planId: 1,
      status: "active",
      startedAt: daysAgo(1),
      currentPeriodEnd: daysFromNow(29),
      pgSubscriptionId: null,
    },
  ];

  for (const s of subsData) {
    await prisma.userSubscription.create({
      data: { ...s, createdBy: "system", updatedBy: "system" },
    });
  }
  console.log(`UserSubscriptions created: ${subsData.length}건`);
  await prisma.$disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
