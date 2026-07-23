// CMS 배너(제휴 광고) 목업 데이터 시딩 스크립트
// 04A N-7 banners — 쿠팡파트너스 등 제휴사 광고 배너 샘플 데이터
import "dotenv/config";
import { PrismaClient } from "../src/generated/prisma/client";
import { PrismaBetterSqlite3 } from "@prisma/adapter-better-sqlite3";

const adapter = new PrismaBetterSqlite3({
  url: process.env.DATABASE_URL ?? "file:./prisma/dev.db",
});
const prisma = new PrismaClient({ adapter });

const SAMPLE_BANNERS = [
  {
    title: "쿠팡파트너스 - 타로 굿즈 모음전",
    imageUrl: "https://placehold.co/720x240/6366f1/ffffff?text=Coupang+Partners",
    linkUrl: "https://link.coupang.com/a/sample-tarot-goods",
    positionCode: "home_top",
    sortOrder: 1,
    isActive: true,
    startAt: new Date("2026-07-01T00:00:00Z"),
    endAt: new Date("2026-12-31T23:59:59Z"),
  },
  {
    title: "쿠팡파트너스 - 운세 다이어리/부적 소품",
    imageUrl: "https://placehold.co/720x240/f59e0b/ffffff?text=Coupang+Partners+2",
    linkUrl: "https://link.coupang.com/a/sample-fortune-diary",
    positionCode: "home_middle",
    sortOrder: 1,
    isActive: true,
    startAt: new Date("2026-07-01T00:00:00Z"),
    endAt: null,
  },
  {
    title: "제휴사 A - 사주 상담 쿠폰",
    imageUrl: "https://placehold.co/720x240/10b981/ffffff?text=Partner+A",
    linkUrl: "https://partner-a.example.com/coupon",
    positionCode: "home_bottom",
    sortOrder: 1,
    isActive: true,
    startAt: null,
    endAt: null,
  },
  {
    title: "제휴사 B - 명상 앱 프로모션 (비활성 예시)",
    imageUrl: "https://placehold.co/720x240/64748b/ffffff?text=Partner+B",
    linkUrl: "https://partner-b.example.com/promo",
    positionCode: "home_middle",
    sortOrder: 2,
    isActive: false,
    startAt: null,
    endAt: null,
  },
];

async function seedBanners() {
  console.log("[seed_banners] banners 시딩...");
  let created = 0;
  for (const b of SAMPLE_BANNERS) {
    const existing = await prisma.banner.findFirst({ where: { title: b.title } });
    if (existing) continue;
    await prisma.banner.create({
      data: { ...b, createdBy: "system_seed", updatedBy: "system_seed" },
    });
    created++;
  }
  console.log(`[seed_banners]    -> ${created}건 생성 (기존 ${SAMPLE_BANNERS.length - created}건 skip)`);
}

async function main() {
  console.log("=== CMS 배너(제휴 광고) 목업 데이터 시딩 시작 ===");
  await seedBanners();
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
