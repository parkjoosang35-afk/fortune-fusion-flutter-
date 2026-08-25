// [복주머니 확장 Phase02-A] PointPolicy 신규 등록 + 상점 카탈로그(ShopCatalogItem) 시딩.
//
// [배경] bokjumeoni-plan(01-planning.html §09 ROADMAP / 03-dev-spec.html §02)의
// Phase02 스코프 "서버 PointPolicy 신규 등록(9종) + 상점 3화면"을 따르되, 실제
// dev.db 조사 결과와 Flutter 호출부 존재 여부를 반영해 다음과 같이 범위를 조정했다:
//
//  A) [버그 수정] 이미 Flutter BlessingBagPolicyAdapter가 호출 중인데 서버
//     PointPolicy에 없어 "사실상 무제한 지급" 상태였던 3종을 등록한다.
//     금액은 Flutter의 BlessingBagEarnReason.defaultAmount(클라이언트가 이미
//     보내는 실제 값)와 동일하게 맞춘다 — 서버 등록만으로 클라이언트 동작이
//     달라지지 않게 하기 위함(경제 밸런스 임의 변경 금지).
//       - altar_visit(제단 참배): amount=1, dailyLimit=1(1일 1회)
//       - weekly_box_opening(주간 소원함 개봉): amount=2, dailyLimit=1
//         ⚠️ [알려진 한계] checkPolicyEligibility()는 scope 'daily'|'lifetime'만
//         지원한다. Flutter가 scope:'weekly'를 보내도 서버 판정 로직은 'daily'
//         분기로 떨어져 사실상 "1일 1회"로 동작한다(진짜 "7일 1회"가 아님).
//         이 seed는 "무제한 지급"이라는 더 급한 구멍만 막는다 — 진짜 주간 주기
//         전환은 scope enum 확장이 필요한 별도 작업으로 남긴다(Phase02 범위 밖).
//       - wish_fulfilled(소원 성취 축하): amount=3, dailyLimit=null
//         (sourceId=wishId 기반 "건당 1회"로만 제한 — 호출부가 이미 wishSourceId를
//         전달할 수 있게 되어 있음(BlessingBagPolicyAdapter.earnWishFulfilledBonus)).
//         ※ dev-spec 원안은 wish_fulfilled=50(scope:per_wish)이지만, 기존
//         라이브 클라이언트가 이미 3으로 지급 중이므로 금액을 임의로 50으로
//         올리지 않는다. 50원 캠페인으로 개편할지는 DECISIONS NEEDED 사안이므로
//         사용자 승인 후 별도 처리한다.
//
//  B) [선등록] dev-spec 9종 중 아직 Flutter 호출부가 없는(=향후 Phase03/04에서
//     화면이 만들어질) 5종을 미리 등록해둔다. 호출부가 없으므로 지금 당장은
//     아무 동작도 하지 않지만("관리자는 값만 조정, 구조는 고정" 원칙에 따라
//     정책 존재 자체가 나중 구현을 준비), 실수로 하드코딩되는 일을 막는다.
//       - daily_candle(오늘의 촛불 켜기): amount=1, dailyLimit=1
//       - daily_meditation(60초 명상): amount=2, dailyLimit=1
//       - daily_feed_visit(피드 방문): amount=1, dailyLimit=1
//       - wish_comment(응원 댓글): amount=2, dailyLimit=3
//       - wish_100days(100일 지킴): amount=30, dailyLimit=null
//         (per_wish — sourceId=wishId 기반 건당 1회로만 제한, 호출부 구현 시
//         반드시 sourceId를 넘겨야 한다)
//
//  C) [의도적 제외 — 사용자 확인 필요] 아래 2종은 이번 seed에서 제외했다:
//       - invite_accepted: dev-spec은 "월 5회" 제한(maxPerMonth)인데
//         checkPolicyEligibility에는 "월간" scope 개념이 아예 없다(daily/lifetime
//         뿐). 잘못된 값으로 등록하면 의미가 왜곡되므로, 월간 판정 로직이
//         엔진에 추가되기 전까지는 등록을 보류한다.
//       - ad_reward: 이미 별도 체계로 구현된 "AD_WATCH_REWARD"
//         (FortuneAdWatchLog 기반, 광고별 rewardAmount+perUserDailyLimit) 광고
//         적립 시스템과 이름/역할이 겹친다. 두 체계를 어떻게 정리할지는
//         사용자 확인 후 처리한다.
//       - full_moon_bonus: amount=0이며 실제로는 "배수 플래그"(multiplier:2)
//         역할이라 현재 PointPolicy(단순 amount+dailyLimit) 구조로 표현할 수
//         없다. 이달의 편지/보름달 기능(Phase04) 설계 시 별도 필드/테이블
//         확장이 필요하다.
//
// [실행] npx tsx prisma/seed_pouch_expansion_phase02.ts
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
  // A) 버그 수정 — 이미 라이브 호출 중인데 미등록이던 3종
  { sourceType: "altar_visit", amount: 1, dailyLimit: 1, isActive: true },
  { sourceType: "weekly_box_opening", amount: 2, dailyLimit: 1, isActive: true },
  { sourceType: "wish_fulfilled", amount: 3, dailyLimit: null, isActive: true },
  // B) 선등록 — Phase03/04 화면 구현 대기 중인 5종
  { sourceType: "daily_candle", amount: 1, dailyLimit: 1, isActive: true },
  { sourceType: "daily_meditation", amount: 2, dailyLimit: 1, isActive: true },
  { sourceType: "daily_feed_visit", amount: 1, dailyLimit: 1, isActive: true },
  { sourceType: "wish_comment", amount: 2, dailyLimit: 3, isActive: true },
  { sourceType: "wish_100days", amount: 30, dailyLimit: null, isActive: true },
];

async function seedPointPolicies() {
  console.log("[seed_pouch_expansion_phase02] 1) point_policies 시딩...");
  let created = 0;
  let skipped = 0;
  for (const p of POLICIES) {
    const existing = await prisma.pointPolicy.findUnique({ where: { sourceType: p.sourceType } });
    if (existing) {
      skipped++;
      continue;
    }
    await prisma.pointPolicy.create({
      data: { ...p, createdBy: "system_seed_phase02", updatedBy: "system_seed_phase02" },
    });
    created++;
  }
  console.log(`[seed_pouch_expansion_phase02]    -> ${created}건 생성, ${skipped}건 기존 skip`);
}

// ── 상점 카탈로그(ShopCatalogItem) — bokjumeoni-plan §02 "사용처 다섯 갈래" 1·2·4번 ──
// 인장(1) 5종 / 촛불(2) 4종 / 부적(4) 3종. 관리자가 나중에 price/isActive만
// 조정할 수 있도록(구조는 고정, 값만 조정 원칙) 여기서는 최초 1회만 시딩한다.
const SHOP_ITEMS: Array<{
  itemType: "seal" | "candle" | "talisman";
  itemCode: string;
  nameKo: string;
  descriptionKo: string;
  price: number;
  durationDays: number | null;
  displayPriority: number;
}> = [
  // ── 인장(seal) 5종 — 옥30/은40/거북50/학50/금박60 ──
  { itemType: "seal", itemCode: "seal_jade", nameKo: "옥 도장", descriptionKo: "맑고 단단한 옥으로 새긴 감사의 도장", price: 30, durationDays: null, displayPriority: 1 },
  { itemType: "seal", itemCode: "seal_silver", nameKo: "은 도장", descriptionKo: "은은하게 빛나는 은으로 새긴 감사의 도장", price: 40, durationDays: null, displayPriority: 2 },
  { itemType: "seal", itemCode: "seal_turtle", nameKo: "거북 도장", descriptionKo: "장수와 안정을 상징하는 거북 문양 도장", price: 50, durationDays: null, displayPriority: 3 },
  { itemType: "seal", itemCode: "seal_crane", nameKo: "학 도장", descriptionKo: "고고한 학의 모습을 새긴 길상 도장", price: 50, durationDays: null, displayPriority: 4 },
  { itemType: "seal", itemCode: "seal_gold_leaf", nameKo: "금박 도장", descriptionKo: "화려한 금박으로 마감한 귀한 도장", price: 60, durationDays: null, displayPriority: 5 },
  // ── 촛불(candle) 4종 — 연꽃40/향초60/별초80/유촉100 ──
  { itemType: "candle", itemCode: "candle_lotus", nameKo: "연꽃 초", descriptionKo: "은은한 연꽃 향이 감도는 초", price: 40, durationDays: null, displayPriority: 1 },
  { itemType: "candle", itemCode: "candle_incense", nameKo: "향초", descriptionKo: "마음을 가라앉히는 은은한 향을 지닌 초", price: 60, durationDays: null, displayPriority: 2 },
  { itemType: "candle", itemCode: "candle_star", nameKo: "별초", descriptionKo: "밤하늘의 별처럼 반짝이는 초", price: 80, durationDays: null, displayPriority: 3 },
  { itemType: "candle", itemCode: "candle_jade_wax", nameKo: "유촉", descriptionKo: "귀한 재료로 빚은 오래 타는 초", price: 100, durationDays: null, displayPriority: 4 },
  // ── 부적(talisman) 3종 — 지킴100·100일 / 만월60·14일 / 벗20·30일 ──
  { itemType: "talisman", itemCode: "talisman_guardian", nameKo: "지킴 부적", descriptionKo: "100일 동안 소원을 든든히 지켜주는 부적", price: 100, durationDays: 100, displayPriority: 1 },
  { itemType: "talisman", itemCode: "talisman_full_moon", nameKo: "만월 부적", descriptionKo: "14일 동안 보름달의 기운을 담아주는 부적", price: 60, durationDays: 14, displayPriority: 2 },
  { itemType: "talisman", itemCode: "talisman_friend", nameKo: "벗 부적", descriptionKo: "30일 동안 곁을 지켜주는 다정한 벗 부적", price: 20, durationDays: 30, displayPriority: 3 },
];

async function seedShopCatalog() {
  console.log("[seed_pouch_expansion_phase02] 2) shop_catalog_items 시딩...");
  let created = 0;
  let skipped = 0;
  for (const item of SHOP_ITEMS) {
    const existing = await prisma.shopCatalogItem.findUnique({ where: { itemCode: item.itemCode } });
    if (existing) {
      skipped++;
      continue;
    }
    await prisma.shopCatalogItem.create({
      data: { ...item, createdBy: "system_seed_phase02", updatedBy: "system_seed_phase02" },
    });
    created++;
  }
  console.log(`[seed_pouch_expansion_phase02]    -> ${created}건 생성, ${skipped}건 기존 skip`);
}

async function main() {
  console.log("=== [Phase02-A] 복주머니 확장 PointPolicy + 상점 카탈로그 시딩 시작 ===");
  await seedPointPolicies();
  await seedShopCatalog();
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
