// 04A J-8/J-9 쿠폰(coupons/coupon_issues) 시드 데이터
// 05_Admin_System_Design.md §3.4 "쿠폰 관리" — 7차 소단위.
import "dotenv/config";
import { PrismaClient } from "../src/generated/prisma/client";
import { PrismaBetterSqlite3 } from "@prisma/adapter-better-sqlite3";

const adapter = new PrismaBetterSqlite3({
  url: process.env.DATABASE_URL ?? "file:./prisma/dev.db",
});
const prisma = new PrismaClient({ adapter });

async function main() {
  const users = await prisma.user.findMany({ take: 6, orderBy: { id: "asc" } });
  if (users.length === 0) {
    console.error("시드할 회원이 없습니다. 회원 시드를 먼저 실행하세요.");
    process.exit(1);
  }

  const now = new Date();
  const in30d = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);
  const past10d = new Date(now.getTime() - 10 * 24 * 60 * 60 * 1000);
  const past40d = new Date(now.getTime() - 40 * 24 * 60 * 60 * 1000);
  const past5d = new Date(now.getTime() - 5 * 24 * 60 * 60 * 1000);

  // ── 04A J-8 coupons: 4건 (진행중 2, 만료 1, 소진예정 1) ──
  const welcome = await prisma.coupon.create({
    data: {
      code: "WELCOME2026",
      discountType: "rate",
      discountValue: 10,
      validFrom: past10d,
      validTo: in30d,
      usageLimit: 100,
      createdBy: "system",
      updatedBy: "system",
    },
  });

  const saju500 = await prisma.coupon.create({
    data: {
      code: "SAJU500P",
      discountType: "fixed_point",
      discountValue: 500,
      validFrom: past10d,
      validTo: in30d,
      usageLimit: null, // 무제한
      createdBy: "system",
      updatedBy: "system",
    },
  });

  const expired = await prisma.coupon.create({
    data: {
      code: "SUMMER2025",
      discountType: "rate",
      discountValue: 20,
      validFrom: past40d,
      validTo: past5d, // 이미 만료됨
      usageLimit: 50,
      createdBy: "system",
      updatedBy: "system",
    },
  });

  const limited = await prisma.coupon.create({
    data: {
      code: "VIP1000P",
      discountType: "fixed_point",
      discountValue: 1000,
      validFrom: past10d,
      validTo: in30d,
      usageLimit: 3, // 소진 임박(발급 3건 예정)
      createdBy: "system",
      updatedBy: "system",
    },
  });

  console.log("Coupons created:", welcome.code, saju500.code, expired.code, limited.code);

  // ── 04A J-9 coupon_issues: 각 쿠폰별로 회원에게 발급 ──
  // status(Base) 사용값: unused/used/expired
  const issuesData = [
    { couponId: welcome.id, userId: users[0].id, status: "used", usedAt: past5d },
    { couponId: welcome.id, userId: users[1].id, status: "unused", usedAt: null },
    { couponId: welcome.id, userId: users[2].id, status: "unused", usedAt: null },
    { couponId: saju500.id, userId: users[0].id, status: "used", usedAt: past5d },
    { couponId: saju500.id, userId: users[3].id, status: "unused", usedAt: null },
    { couponId: expired.id, userId: users[1].id, status: "expired", usedAt: null },
    { couponId: expired.id, userId: users[4].id, status: "used", usedAt: past40d },
    { couponId: limited.id, userId: users[0].id, status: "unused", usedAt: null },
    { couponId: limited.id, userId: users[1].id, status: "unused", usedAt: null },
    { couponId: limited.id, userId: users[2].id, status: "unused", usedAt: null },
  ];

  for (const d of issuesData) {
    await prisma.couponIssue.create({
      data: {
        couponId: d.couponId,
        userId: d.userId,
        status: d.status,
        usedAt: d.usedAt,
        createdBy: "system",
        updatedBy: "system",
      },
    });
  }

  console.log(`CouponIssues created: ${issuesData.length}건`);
  await prisma.$disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
