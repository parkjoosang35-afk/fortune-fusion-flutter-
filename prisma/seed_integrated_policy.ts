// [신규] 열림패스/행복머니/복주머니 통합정책 목업 데이터 시딩
// - happy_money_products: 행복머니 충전 상품
// - luck_pouch_rules: 복주머니 적립/소비/구매 규칙 (기존 Flutter WishRoomRewardConfig 값과
//   최대한 일치시켜 백엔드-앱 정책 불일치를 방지)
// - feature_asset_bindings: 화면(FeatureScope)별 필요 자산 매핑 — 하드코딩 금지 원칙의 핵심
// - pass_policies: 기존 4건에 scope/happyMoneyPrice 등 신규 필드 값을 채워 넣는다(update)
import "dotenv/config";
import { PrismaClient } from "../src/generated/prisma/client";
import { PrismaBetterSqlite3 } from "@prisma/adapter-better-sqlite3";

const adapter = new PrismaBetterSqlite3({
  url: process.env.DATABASE_URL ?? "file:./prisma/dev.db",
});
const prisma = new PrismaClient({ adapter });

const FORTUNE_SCOPES =
  "fortune_today,fortune_tarot,fortune_saju,fortune_compatibility,fortune_face_palm,fortune_theme";

const HAPPY_MONEY_PRODUCTS = [
  {
    name: "행복머니 3,000원 충전",
    cashPrice: 3000,
    happyMoneyAmount: 3000,
    bonusAmount: 0,
    isActive: true,
    isFeatured: false,
    displayPriority: 1,
    allowedUsageScopes: "pass,subscription,gift",
    isEventGrantable: true,
    isManualGrantable: true,
  },
  {
    name: "행복머니 10,000원 충전",
    cashPrice: 10000,
    happyMoneyAmount: 10000,
    bonusAmount: 500,
    isActive: true,
    isFeatured: true,
    displayPriority: 2,
    allowedUsageScopes: "pass,subscription,gift",
    isEventGrantable: true,
    isManualGrantable: true,
  },
  {
    name: "행복머니 30,000원 충전",
    cashPrice: 30000,
    happyMoneyAmount: 30000,
    bonusAmount: 3000,
    isActive: true,
    isFeatured: true,
    displayPriority: 3,
    allowedUsageScopes: "pass,subscription,gift",
    isEventGrantable: true,
    isManualGrantable: true,
  },
  {
    name: "행복머니 50,000원 충전",
    cashPrice: 50000,
    happyMoneyAmount: 50000,
    bonusAmount: 7500,
    isActive: true,
    isFeatured: false,
    displayPriority: 4,
    allowedUsageScopes: "pass,subscription,gift",
    isEventGrantable: true,
    isManualGrantable: true,
  },
];

// 복주머니 규칙: 기존 Flutter WishRoomRewardConfig(치성 1회=+5, 소원등록=+3 등)와
// 최대한 정합성 있게 명명. 정확한 수치는 관리자가 이후 조정 가능(운영 정책값이므로).
const LUCK_POUCH_RULES: Array<{
  name: string;
  ruleType: "earn" | "spend" | "purchase";
  actionType: string;
  targetScope: string | null;
  amount: number;
  cashPrice: number | null;
  dailyLimit: number | null;
  isPurchasable: boolean;
  isManualGrantable: boolean;
  isActive: boolean;
  displayPriority: number;
}> = [
  // ── 적립(earn) ──
  {
    name: "출석 체크 적립",
    ruleType: "earn",
    actionType: "attendance",
    targetScope: "community",
    amount: 5,
    cashPrice: null,
    dailyLimit: 1,
    isPurchasable: false,
    isManualGrantable: true,
    isActive: true,
    displayPriority: 1,
  },
  {
    name: "소원 등록 적립",
    ruleType: "earn",
    actionType: "wish_room_wish",
    targetScope: "wish_room",
    amount: 3,
    cashPrice: null,
    dailyLimit: 5,
    isPurchasable: false,
    isManualGrantable: true,
    isActive: true,
    displayPriority: 2,
  },
  {
    name: "치성 드리기(1회) 적립",
    ruleType: "earn",
    actionType: "wish_room_ritual",
    targetScope: "wish_room",
    amount: 5,
    cashPrice: null,
    dailyLimit: 3,
    isPurchasable: false,
    isManualGrantable: true,
    isActive: true,
    displayPriority: 3,
  },
  {
    name: "이벤트 지급",
    ruleType: "earn",
    actionType: "event",
    targetScope: null,
    amount: 10,
    cashPrice: null,
    dailyLimit: null,
    isPurchasable: false,
    isManualGrantable: true,
    isActive: true,
    displayPriority: 4,
  },
  // ── 소비(spend) ──
  {
    name: "응원(cheer) 사용",
    ruleType: "spend",
    actionType: "cheer",
    targetScope: "wish_board",
    amount: 2,
    cashPrice: null,
    dailyLimit: null,
    isPurchasable: false,
    isManualGrantable: false,
    isActive: true,
    displayPriority: 10,
  },
  {
    name: "공감(empathize) 사용",
    ruleType: "spend",
    actionType: "empathize",
    targetScope: "wish_board",
    amount: 1,
    cashPrice: null,
    dailyLimit: null,
    isPurchasable: false,
    isManualGrantable: false,
    isActive: true,
    displayPriority: 11,
  },
  {
    name: "글 강조(highlight) 사용",
    ruleType: "spend",
    actionType: "highlight",
    targetScope: "wish_board",
    amount: 10,
    cashPrice: null,
    dailyLimit: null,
    isPurchasable: false,
    isManualGrantable: false,
    isActive: true,
    displayPriority: 12,
  },
  {
    name: "노출 강화(expose_boost) 사용",
    ruleType: "spend",
    actionType: "expose_boost",
    targetScope: "wish_board",
    amount: 15,
    cashPrice: null,
    dailyLimit: null,
    isPurchasable: false,
    isManualGrantable: false,
    isActive: true,
    displayPriority: 13,
  },
  {
    // [재화 구조 정리 - 재연결 / 참고용 시드로 유지] 실제 부적 제작 비용은
    // AmuletProduct.pricePoint(카탈로그 가격, /api/public/amulets/purchase에서
    // sourceType="amulet_purchase"로 소비)를 그대로 사용한다. 이 규칙 행은
    // "부적 1개 제작에 대략 얼마가 드는지"를 관리자 화면에서 참고할 수 있도록
    // 남겨두는 안내용 항목이며, 실제 금액 산정에는 관여하지 않는다(상품마다
    // 가격이 달라 단일 고정값으로 강제 연결하면 오히려 기존 카탈로그 가격 정책이
    // 깨지므로, 강제 연결하지 않기로 결정 — 2026-08 재화 구조 정리 세션).
    name: "부적 만들기(참고용 - 실제 가격은 부적 카탈로그 개별 가격 적용)",
    ruleType: "spend",
    actionType: "talisman_make",
    targetScope: "talisman",
    amount: 20,
    cashPrice: null,
    dailyLimit: null,
    isPurchasable: false,
    isManualGrantable: false,
    isActive: true,
    displayPriority: 14,
  },
  // ── 구매(purchase) ──
  // [재화 구조 정리 - 재연결] 실제 카드결제/인앱결제(IAP) 연동은 아직 없으므로,
  // 아래 3개 구간은 "관리자가 특정 유저에게 유상 지급했음을 기록할 때 참고하는
  // 금액-수량 매핑표"로만 기능한다(관리자 수동 지급 시 참고, 실제 PG/IAP 콜백은
  // 별도 구축 필요 — 통합정책 §6/§9 범위 밖).
  {
    name: "복주머니 50개 구매",
    ruleType: "purchase",
    actionType: "purchase",
    targetScope: null,
    amount: 50,
    cashPrice: 1000,
    dailyLimit: null,
    isPurchasable: true,
    isManualGrantable: false,
    isActive: true,
    displayPriority: 20,
  },
  {
    name: "복주머니 150개 구매",
    ruleType: "purchase",
    actionType: "purchase",
    targetScope: null,
    amount: 150,
    cashPrice: 2500,
    dailyLimit: null,
    isPurchasable: true,
    isManualGrantable: false,
    isActive: true,
    displayPriority: 21,
  },
  {
    name: "복주머니 350개 구매",
    ruleType: "purchase",
    actionType: "purchase",
    targetScope: null,
    amount: 350,
    cashPrice: 5000,
    dailyLimit: null,
    isPurchasable: true,
    isManualGrantable: false,
    isActive: true,
    displayPriority: 22,
  },
];

const FEATURE_ASSET_BINDINGS: Array<{
  scope: string;
  featureGroup: string;
  primaryAsset: string;
  secondaryAssets: string | null;
  accessType: string;
  notes: string;
}> = [
  { scope: "fortune_today", featureGroup: "fortune", primaryAsset: "open_pass", secondaryAssets: null, accessType: "mixed_limited", notes: "무료 영역 일부 + 열림패스 시 전체 해제" },
  { scope: "fortune_tarot", featureGroup: "fortune", primaryAsset: "open_pass", secondaryAssets: null, accessType: "open_pass", notes: "타로 상세 결과는 열림패스 필요" },
  { scope: "fortune_saju", featureGroup: "fortune", primaryAsset: "open_pass", secondaryAssets: null, accessType: "open_pass", notes: "사주 상세 결과는 열림패스 필요" },
  { scope: "fortune_compatibility", featureGroup: "fortune", primaryAsset: "open_pass", secondaryAssets: null, accessType: "open_pass", notes: "궁합 상세 결과는 열림패스 필요" },
  { scope: "fortune_face_palm", featureGroup: "fortune", primaryAsset: "open_pass", secondaryAssets: null, accessType: "open_pass", notes: "관상/손금 상세 결과는 열림패스 필요" },
  { scope: "fortune_theme", featureGroup: "fortune", primaryAsset: "open_pass", secondaryAssets: null, accessType: "open_pass", notes: "테마 운세 상세 결과는 열림패스 필요" },
  { scope: "wish_board", featureGroup: "community", primaryAsset: "luck_pouch", secondaryAssets: null, accessType: "luck_pouch", notes: "응원/공감/강조/노출강화는 복주머니 소비" },
  { scope: "wish_room", featureGroup: "community", primaryAsset: "luck_pouch", secondaryAssets: null, accessType: "free", notes: "소원방 입장 자체는 무료, 치성으로 복주머니 적립" },
  { scope: "talisman", featureGroup: "community", primaryAsset: "luck_pouch", secondaryAssets: null, accessType: "luck_pouch", notes: "부적 만들기는 복주머니 소비" },
  { scope: "community", featureGroup: "community", primaryAsset: "luck_pouch", secondaryAssets: null, accessType: "free", notes: "커뮤니티 진입 자체는 무료" },
  { scope: "ai_consulting", featureGroup: "premium_shop", primaryAsset: "happy_money", secondaryAssets: null, accessType: "happy_money", notes: "AI 상담은 행복머니로 결제(향후 확장)" },
  { scope: "subscription", featureGroup: "premium_shop", primaryAsset: "happy_money", secondaryAssets: null, accessType: "happy_money", notes: "구독 상품은 행복머니로 구매" },
  { scope: "gift_shop", featureGroup: "premium_shop", primaryAsset: "happy_money", secondaryAssets: null, accessType: "happy_money", notes: "상품권은 행복머니로 구매" },
];

async function main() {
  console.log("[seed] 1) pass_policies 신규 필드(scope/happyMoneyPrice 등) 백필...");
  const passPolicies = await prisma.passPolicy.findMany({ where: { deletedAt: null } });
  for (const p of passPolicies) {
    let happyMoneyPrice: number | null = null;
    let isFeatured = false;
    let uiCopy: string | null = null;
    if (p.passType === "subscription") {
      happyMoneyPrice = 9900;
      isFeatured = true;
      uiCopy = JSON.stringify({ badge: "추천", subtitle: "구독 회원 전용 24시간 이용권" });
    } else if (p.passType === "event") {
      uiCopy = JSON.stringify({ badge: "이벤트", subtitle: "기간 한정 이벤트 지급 패스" });
    }
    await prisma.passPolicy.update({
      where: { id: p.id },
      data: {
        scope: FORTUNE_SCOPES,
        description: p.description ?? `${p.name} — 오늘의 운세를 포함한 전체 운세 콘텐츠를 ${p.durationMin}분간 자유롭게 이용합니다.`,
        happyMoneyPrice,
        isFeatured,
        uiCopy,
      },
    });
  }
  console.log(`[seed]    -> ${passPolicies.length}건 백필 완료`);

  console.log("[seed] 2) happy_money_products 시딩...");
  for (const product of HAPPY_MONEY_PRODUCTS) {
    const existing = await prisma.happyMoneyProduct.findFirst({ where: { name: product.name } });
    if (existing) {
      await prisma.happyMoneyProduct.update({ where: { id: existing.id }, data: product });
    } else {
      await prisma.happyMoneyProduct.create({ data: product });
    }
  }
  console.log(`[seed]    -> ${HAPPY_MONEY_PRODUCTS.length}건 완료`);

  console.log("[seed] 3) luck_pouch_rules 시딩...");
  for (const rule of LUCK_POUCH_RULES) {
    const existing = await prisma.luckPouchRule.findFirst({
      where: { actionType: rule.actionType, ruleType: rule.ruleType, amount: rule.amount },
    });
    if (existing) {
      await prisma.luckPouchRule.update({ where: { id: existing.id }, data: rule });
    } else {
      await prisma.luckPouchRule.create({ data: rule });
    }
  }
  console.log(`[seed]    -> ${LUCK_POUCH_RULES.length}건 완료`);

  console.log("[seed] 4) feature_asset_bindings 시딩...");
  for (const binding of FEATURE_ASSET_BINDINGS) {
    await prisma.featureAssetBinding.upsert({
      where: { scope: binding.scope },
      update: binding,
      create: binding,
    });
  }
  console.log(`[seed]    -> ${FEATURE_ASSET_BINDINGS.length}건 완료`);

  console.log("[seed] 완료.");
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
