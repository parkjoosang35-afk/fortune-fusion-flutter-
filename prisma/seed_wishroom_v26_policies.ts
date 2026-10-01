// [신통방통 소원방(WishRoom) v2.6] PointPolicy 신규 등록 — §7 EARN 획득처 6종
// + 정성 10회 완료 보너스. 금액/한도는 data/wishroom_data.json(design_handoff
// 패키지, EARN·DEVOTION_RULE 키)을 그대로 따른다(README §10-2: "기획 확정값으로
// 바뀌면 이 JSON만 고칩니다" — 추후 수치가 바뀌면 이 seed의 값도 JSON을 보고
// 맞춰 다시 실행하면 된다. 하드코딩 자체는 이 파일 1곳에만 존재).
//
// sourceType 네이밍: 전부 "wishroom_" 접두사(§ 네이밍 원칙 — 기존 Wish(소원성)
// 계열 sourceType과 충돌 방지).
//
//   wishroom_earn_ad       : 짧은 영상 보기(광고). amount=30, dailyLimit=10 (scope: daily)
//   wishroom_earn_attend   : 오늘의 출석. amount=10, dailyLimit=1 (scope: daily)
//   wishroom_devotion_bonus: 정성 10회 완료 보너스. amount=20, dailyLimit=1 (scope: daily, 방 단위 아님 — 유저 단위 1일 1회)
//   wishroom_earn_m_visit  : 다른 소원방 3곳 둘러보기(미션1). amount=10, dailyLimit=1 (scope: lifetime — "각 1회")
//   wishroom_earn_m_cheer  : 응원 3번 보내기(미션2). amount=20, dailyLimit=1 (scope: lifetime)
//   wishroom_earn_m_msg    : 응원 메시지 남기기(미션3). amount=30, dailyLimit=1 (scope: lifetime)
//
// [참고] wishroom_gift_sent(선물 보내기로 지갑 차감)는 PointPolicy 등록이
// 필요 없다 — 기존 send_pouch(복주머니 보내기) 전례와 동일하게 spendLuckPouch()만
// 호출하면 되고(checkPolicyEligibility 판정 대상 아님), 수신자에게는 Wallet
// 지급이 없다(WishRoom.pouchReceived 카운트만 증가 — 기존 Wish.bokjuCount와
// 동일한 "포인트 아닌 표시용 누적치" 철학).
// [참고] wishroom_support_reward_*(응원 마일스톤 보상)는 전부 아이템 지급이라
// Wallet/PointPolicy 대상이 아니다 — WishRoomSupportRewardClaim + ItemOwned로
// 처리한다(별도 로직, 이 seed와 무관).
import "dotenv/config";
import { PrismaClient } from "../src/generated/prisma/client";
import { PrismaBetterSqlite3 } from "@prisma/adapter-better-sqlite3";

const adapter = new PrismaBetterSqlite3({
  url: process.env.DATABASE_URL ?? "file:./prisma/dev.db",
});
const prisma = new PrismaClient({ adapter });

const POLICIES: Array<{
  sourceType: string;
  amount: number;
  dailyLimit: number | null;
  isActive: boolean;
}> = [
  { sourceType: "wishroom_earn_ad", amount: 30, dailyLimit: 10, isActive: true },
  { sourceType: "wishroom_earn_attend", amount: 10, dailyLimit: 1, isActive: true },
  { sourceType: "wishroom_devotion_bonus", amount: 20, dailyLimit: 1, isActive: true },
  { sourceType: "wishroom_earn_m_visit", amount: 10, dailyLimit: 1, isActive: true },
  { sourceType: "wishroom_earn_m_cheer", amount: 20, dailyLimit: 1, isActive: true },
  { sourceType: "wishroom_earn_m_msg", amount: 30, dailyLimit: 1, isActive: true },
];

async function main() {
  console.log("[seed_wishroom_v26_policies] point_policies 시딩...");
  let created = 0;
  let updated = 0;
  for (const p of POLICIES) {
    const existing = await prisma.pointPolicy.findUnique({ where: { sourceType: p.sourceType } });
    if (existing) {
      await prisma.pointPolicy.update({
        where: { sourceType: p.sourceType },
        data: { amount: p.amount, dailyLimit: p.dailyLimit, isActive: p.isActive, updatedBy: "system_seed_wishroom_v26" },
      });
      updated++;
      continue;
    }
    await prisma.pointPolicy.create({
      data: { ...p, createdBy: "system_seed_wishroom_v26", updatedBy: "system_seed_wishroom_v26" },
    });
    created++;
  }
  console.log(`[seed_wishroom_v26_policies]    -> ${created}건 생성, ${updated}건 갱신`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
