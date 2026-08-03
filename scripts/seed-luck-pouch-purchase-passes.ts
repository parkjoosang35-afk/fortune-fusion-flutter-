// [재화 구조 정리] 복주머니 사용 구간표: 프리패스30분-30, 1시간-50, 24시간-150.
// "복주머니로 구매" 옵션으로 노출할 PassPolicy 3종을 시드한다(1회성 스크립트).
// 실행: cd /home/user/admin_web && npx tsx scripts/seed-luck-pouch-purchase-passes.ts
import { prisma } from "@/lib/db";

const PURCHASE_OPTIONS = [
  { name: "프리패스 30분 (복주머니 구매)", durationMin: 30, happyMoneyPrice: 30 },
  { name: "프리패스 1시간 (복주머니 구매)", durationMin: 60, happyMoneyPrice: 50 },
  { name: "프리패스 24시간 (복주머니 구매)", durationMin: 1440, happyMoneyPrice: 150 },
];

async function main() {
  for (const opt of PURCHASE_OPTIONS) {
    const existing = await prisma.passPolicy.findFirst({
      where: { happyMoneyPrice: opt.happyMoneyPrice, durationMin: opt.durationMin, deletedAt: null },
    });
    if (existing) {
      console.log(`[skip] 이미 존재: ${opt.name} (id=${existing.id})`);
      continue;
    }
    const created = await prisma.passPolicy.create({
      data: {
        name: opt.name,
        passType: "event",
        durationMin: opt.durationMin,
        dailyLimit: null,
        ctaText: "복주머니로 구매",
        bonusPoint: 0,
        isActive: true,
        status: "active",
        description: `복주머니 ${opt.happyMoneyPrice}개로 즉시 구매 가능한 프리패스`,
        happyMoneyPrice: opt.happyMoneyPrice,
        adRewardEnabled: false,
        isFeatured: false,
        displayPriority: opt.happyMoneyPrice,
      },
    });
    console.log(`[created] ${created.name} (id=${created.id}, price=${created.happyMoneyPrice})`);
  }
}

main()
  .then(() => {
    console.log("완료.");
    process.exit(0);
  })
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
