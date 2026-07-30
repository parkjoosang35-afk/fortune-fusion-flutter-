// [신규] 알림패스(AlarmPass) 정책 목업 데이터 시딩
// pass_policies: Fortune Fusion 3대 재화 중 ①알림패스(시간제 콘텐츠 열람권)
// 문서3(정책표) 승인 반영: 타입 4종(ad/partner/subscription/event) x 지속시간 3종(1h/3h/24h)
import "dotenv/config";
import { PrismaClient } from "../src/generated/prisma/client";
import { PrismaBetterSqlite3 } from "@prisma/adapter-better-sqlite3";

const adapter = new PrismaBetterSqlite3({
  url: process.env.DATABASE_URL ?? "file:./prisma/dev.db",
});
const prisma = new PrismaClient({ adapter });

const POLICIES: Array<{
  name: string;
  passType: "ad" | "partner" | "subscription" | "event";
  durationMin: number;
  dailyLimit: number | null;
  ctaText: string;
  bannerImageUrl: string | null;
  linkUrl: string | null;
  bonusPoint: number;
  isActive: boolean;
}> = [
  {
    name: "광고 시청 알림패스(1시간)",
    passType: "ad",
    durationMin: 60,
    dailyLimit: 3,
    ctaText: "광고 보고 1시간 무료 이용",
    bannerImageUrl: null,
    linkUrl: null,
    bonusPoint: 0,
    isActive: true,
  },
  {
    name: "파트너 제휴 알림패스(3시간)",
    passType: "partner",
    durationMin: 180,
    dailyLimit: 1,
    ctaText: "제휴 앱 방문하고 3시간 이용권 받기",
    bannerImageUrl: null,
    linkUrl: "https://partner.example.com/offer",
    bonusPoint: 10,
    isActive: true,
  },
  {
    name: "구독 회원 알림패스(24시간)",
    passType: "subscription",
    durationMin: 1440,
    dailyLimit: 1,
    ctaText: "구독 혜택으로 24시간 이용권 자동 지급",
    bannerImageUrl: null,
    linkUrl: null,
    bonusPoint: 0,
    isActive: true,
  },
  {
    name: "이벤트 알림패스(24시간)",
    passType: "event",
    durationMin: 1440,
    dailyLimit: null,
    ctaText: "이벤트 참여하고 24시간 이용권 받기",
    bannerImageUrl: null,
    linkUrl: null,
    bonusPoint: 50,
    isActive: true,
  },
];

async function seedPassPolicies() {
  console.log("[seed_pass_policies] pass_policies 시딩...");
  let count = 0;
  for (const p of POLICIES) {
    const existing = await prisma.passPolicy.findFirst({
      where: { passType: p.passType, durationMin: p.durationMin },
    });
    if (existing) continue;
    await prisma.passPolicy.create({
      data: { ...p, createdBy: "system_seed", updatedBy: "system_seed" },
    });
    count++;
  }
  console.log(`[seed_pass_policies]    -> ${count}건 생성 (기존 ${POLICIES.length - count}건 skip)`);
}

async function main() {
  await seedPassPolicies();
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
