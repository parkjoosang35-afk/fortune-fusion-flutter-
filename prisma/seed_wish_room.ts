// 소원방(Wish Room) 초기 시딩 스크립트.
//
// [설계 원칙 재확인]
// - 복주머니 재화(잔액/원장)는 이 스크립트에서 다루지 않는다(Wallet/PointHistory 재사용).
// - 여기서는 소원방 고유 마스터 데이터만 채운다:
//   1) WishRoomCategory  — Flutter WishCategoryX(8종)와 1:1 대응하는 서버 마스터
//   2) WishRoomConfig    — 관리자가 조정할 소원방 정책 기본값(key-value, wish_config 패턴과 동일)
//   3) WishRoomTheme     — 배경 테마 카탈로그(꾸미기 상점)
//   4) WishRoomObject    — 오브젝트(구슬 이펙트/장식) 카탈로그(꾸미기 상점)
//   5) WishRoomGuideSlide — 최초 진입 가이드 6슬라이드(관리자가 문구/순서/노출여부 편집 가능)
//   6) LuckPouchRule 보강 — wish_room 스코프의 세분화된 지급/차감 규칙 추가
//      (기존 wish_room_wish/wish_room_ritual 2건은 유지, 신규 액션만 추가)
import "dotenv/config";
import { PrismaClient } from "../src/generated/prisma/client";
import { PrismaBetterSqlite3 } from "@prisma/adapter-better-sqlite3";

const adapter = new PrismaBetterSqlite3({
  url: process.env.DATABASE_URL ?? "file:./prisma/dev.db",
});
const prisma = new PrismaClient({ adapter });

// Flutter WishCategory enum(wish_item_model.dart)과 순서/코드 1:1 대응.
const CATEGORIES = [
  { code: "health", label: "건강운", emoji: "🌿", colorHex: "#4ADE80", displayOrder: 1 },
  { code: "wealth", label: "금전운", emoji: "💰", colorHex: "#FBBF24", displayOrder: 2 },
  { code: "exam", label: "합격운", emoji: "📚", colorHex: "#A78BFA", displayOrder: 3 },
  { code: "love", label: "연애운", emoji: "💗", colorHex: "#F472B6", displayOrder: 4 },
  { code: "family", label: "가족운", emoji: "🏡", colorHex: "#FB923C", displayOrder: 5 },
  { code: "achievement", label: "소망성취", emoji: "⭐", colorHex: "#60A5FA", displayOrder: 6 },
  { code: "healing", label: "마음치유", emoji: "🕊️", colorHex: "#93C5FD", displayOrder: 7 },
  { code: "custom", label: "나만의 소원", emoji: "✨", colorHex: "#CBD5E1", displayOrder: 8 },
];

// [관리자 설정 하드코딩 금지 원칙] 모든 소원방 정책 숫자는 이 표로부터만 읽어야 한다.
const CONFIGS: Array<{ key: string; value: string; description: string }> = [
  { key: "wish_room_max_wish_count", value: "3", description: "회원 1인당 동시 보유 가능한 최대 소원 개수(대표1+서브2)." },
  { key: "wish_room_care_daily_free_count", value: "1", description: "하루 무료로 힘주기(돌보기) 가능한 횟수." },
  { key: "wish_room_care_energy_gain", value: "20", description: "힘주기 1회당 증가하는 에너지량." },
  { key: "wish_room_max_energy", value: "300", description: "소원 하나의 최대 에너지치(=growthPoint 상한 기준값)." },
  { key: "wish_room_decay_day1_amount", value: "5", description: "미접속 1일 경과 시 에너지 감소량." },
  { key: "wish_room_decay_day2_amount", value: "10", description: "미접속 2일 경과 시 에너지 감소량." },
  { key: "wish_room_decay_day3_amount", value: "15", description: "미접속 3일 경과 시 에너지 감소량." },
  { key: "wish_room_decay_day7_plus_amount", value: "25", description: "미접속 7일 이상 경과 시(1회) 추가 에너지 감소량." },
  { key: "wish_room_entry_animation_enabled", value: "true", description: "소원방 입장 시 풀 시퀀스 애니메이션(암전→별→은하수→달) ON/OFF." },
  { key: "wish_room_lucky_bag_animation_enabled", value: "true", description: "복주머니 적립 시 풀 연출(개봉/폭발/파티클) ON/OFF." },
  { key: "wish_room_guide_auto_show_on_first_visit", value: "true", description: "최초 진입 시 가이드 레이어 자동 노출 여부." },
  { key: "wish_room_representative_change_cooldown_hours", value: "24", description: "대표 소원 변경 후 재변경까지 대기 시간(시간 단위)." },
];

const THEMES: Array<{
  name: string; previewImageUrl: string | null; backgroundAssetUrl: string | null;
  animationAssetUrl: string | null; pouchPrice: number; isPurchasable: boolean;
  isEventOnly: boolean; displayOrder: number;
}> = [
  { name: "기본 밤하늘", previewImageUrl: null, backgroundAssetUrl: null, animationAssetUrl: null, pouchPrice: 0, isPurchasable: true, isEventOnly: false, displayOrder: 1 },
  { name: "은하수 정원", previewImageUrl: null, backgroundAssetUrl: null, animationAssetUrl: null, pouchPrice: 40, isPurchasable: true, isEventOnly: false, displayOrder: 2 },
  { name: "보름달 사원", previewImageUrl: null, backgroundAssetUrl: null, animationAssetUrl: null, pouchPrice: 60, isPurchasable: true, isEventOnly: false, displayOrder: 3 },
  { name: "별빛 폭포", previewImageUrl: null, backgroundAssetUrl: null, animationAssetUrl: null, pouchPrice: 80, isPurchasable: true, isEventOnly: false, displayOrder: 4 },
  { name: "오로라 성역", previewImageUrl: null, backgroundAssetUrl: null, animationAssetUrl: null, pouchPrice: 120, isPurchasable: true, isEventOnly: false, displayOrder: 5 },
];

const OBJECTS: Array<{
  name: string; category: string; imageUrl: string | null; animationAssetUrl: string | null;
  pouchPrice: number; unlockType: string; unlockThreshold: number | null; displayOrder: number;
}> = [
  { name: "은빛 파동 이펙트", category: "orb_effect", imageUrl: null, animationAssetUrl: null, pouchPrice: 30, unlockType: "purchase", unlockThreshold: null, displayOrder: 1 },
  { name: "황금 파동 이펙트", category: "orb_effect", imageUrl: null, animationAssetUrl: null, pouchPrice: 50, unlockType: "purchase", unlockThreshold: null, displayOrder: 2 },
  { name: "별무리 입자", category: "particle", imageUrl: null, animationAssetUrl: null, pouchPrice: 25, unlockType: "purchase", unlockThreshold: null, displayOrder: 3 },
  { name: "반짝이는 나비", category: "decoration", imageUrl: null, animationAssetUrl: null, pouchPrice: 20, unlockType: "purchase", unlockThreshold: null, displayOrder: 4 },
  { name: "작은 초롱불", category: "decoration", imageUrl: null, animationAssetUrl: null, pouchPrice: 15, unlockType: "purchase", unlockThreshold: null, displayOrder: 5 },
  { name: "달빛 새", category: "decoration", imageUrl: null, animationAssetUrl: null, pouchPrice: 35, unlockType: "purchase", unlockThreshold: null, displayOrder: 6 },
  { name: "특별 각성 연출", category: "special_animation", imageUrl: null, animationAssetUrl: null, pouchPrice: 100, unlockType: "purchase", unlockThreshold: null, displayOrder: 7 },
  { name: "에너지 충전권", category: "energy_charge", imageUrl: null, animationAssetUrl: null, pouchPrice: 10, unlockType: "purchase", unlockThreshold: null, displayOrder: 8 },
];

const GUIDE_SLIDES: Array<{ title: string; body: string; displayOrder: number }> = [
  {
    title: "✨ 소원방이란?",
    body: "소원방은 당신의 소원이 머무는 특별한 공간이에요.\n이곳에서 소원을 만들고, 매일 돌보며 함께 성장해요.",
    displayOrder: 1,
  },
  {
    title: "🌟 소원을 만들어보세요",
    body: "마음속에 품고 있던 소원을 이곳에 빌어보세요.\n당신의 소원은 반짝이는 구슬로 이 방에 머물게 돼요.",
    displayOrder: 2,
  },
  {
    title: "💛 매일 소원에게 힘을 주세요",
    body: "매일 한 번, 소원에게 힘을 줄 수 있어요.\n힘을 줄수록 소원의 에너지가 차오르고 더 밝게 빛나요.",
    displayOrder: 3,
  },
  {
    title: "🎁 복주머니를 모아보세요",
    body: "소원을 돌보고 방문할 때마다 복주머니가 쌓여요.\n복주머니는 소원방을 꾸미는 데 사용할 수 있어요.",
    displayOrder: 4,
  },
  {
    title: "🌙 나만의 소원방을 꾸며보세요",
    body: "모은 복주머니로 배경, 이펙트, 장식을 구매해보세요.\n당신만의 특별한 소원방을 완성할 수 있어요.",
    displayOrder: 5,
  },
  {
    title: "💫 원할 때 소원게시판에 공개하세요",
    body: "소원을 다른 사람들과 나누고 싶다면 공개해보세요.\n소원게시판에서 서로의 소원을 응원할 수 있어요.",
    displayOrder: 6,
  },
];

// [재화 구조 정리 §복주머니 지급/차감 세분화] 기존 wish_room_wish(적립 3)/
// wish_room_ritual(적립 5) 2건은 그대로 유지하고, 아래 신규 actionType만 추가한다.
// 중복 시딩 방지를 위해 (ruleType, actionType, targetScope) 조합으로 존재 여부를 먼저 확인한다.
const LUCK_POUCH_RULES: Array<{
  name: string; ruleType: string; actionType: string; targetScope: string;
  amount: number; dailyLimit: number | null; isPurchasable: boolean; isManualGrantable: boolean;
}> = [
  { name: "소원 돌보기(힘주기) 적립", ruleType: "earn", actionType: "wish_room_care", targetScope: "wish_room", amount: 3, dailyLimit: 1, isPurchasable: false, isManualGrantable: true },
  { name: "소원방 방문 스트릭 보너스", ruleType: "earn", actionType: "wish_room_streak_bonus", targetScope: "wish_room", amount: 5, dailyLimit: 1, isPurchasable: false, isManualGrantable: true },
  { name: "소원 깨우기(회복) 적립", ruleType: "earn", actionType: "wish_room_wake", targetScope: "wish_room", amount: 2, dailyLimit: 1, isPurchasable: false, isManualGrantable: true },
  { name: "소원방 꾸미기 구매 사용", ruleType: "spend", actionType: "wish_room_shop_purchase", targetScope: "wish_room", amount: 0, dailyLimit: null, isPurchasable: false, isManualGrantable: false },
];

async function main() {
  console.log("[seed_wish_room] 1) wish_room_categories 시딩...");
  for (const c of CATEGORIES) {
    await prisma.wishRoomCategory.upsert({
      where: { code: c.code },
      update: { label: c.label, emoji: c.emoji, colorHex: c.colorHex, displayOrder: c.displayOrder },
      create: c,
    });
  }
  console.log(`[seed_wish_room]    -> ${CATEGORIES.length}개 완료`);

  console.log("[seed_wish_room] 2) wish_room_config 시딩...");
  for (const cfg of CONFIGS) {
    await prisma.wishRoomConfig.upsert({
      where: { key: cfg.key },
      update: {}, // 이미 존재하면 관리자가 수정한 값 보존(덮어쓰지 않음)
      create: { key: cfg.key, value: cfg.value, description: cfg.description, updatedBy: "system_seed" },
    });
  }
  console.log(`[seed_wish_room]    -> ${CONFIGS.length}개 완료`);

  console.log("[seed_wish_room] 3) wish_room_themes 시딩...");
  for (const t of THEMES) {
    const existing = await prisma.wishRoomTheme.findFirst({ where: { name: t.name } });
    if (existing) {
      await prisma.wishRoomTheme.update({ where: { id: existing.id }, data: t });
    } else {
      await prisma.wishRoomTheme.create({ data: t });
    }
  }
  console.log(`[seed_wish_room]    -> ${THEMES.length}개 완료`);

  console.log("[seed_wish_room] 4) wish_room_objects 시딩...");
  for (const o of OBJECTS) {
    const existing = await prisma.wishRoomObject.findFirst({ where: { name: o.name } });
    if (existing) {
      await prisma.wishRoomObject.update({ where: { id: existing.id }, data: o });
    } else {
      await prisma.wishRoomObject.create({ data: o });
    }
  }
  console.log(`[seed_wish_room]    -> ${OBJECTS.length}개 완료`);

  console.log("[seed_wish_room] 5) wish_room_guide_slides 시딩...");
  for (const s of GUIDE_SLIDES) {
    const existing = await prisma.wishRoomGuideSlide.findFirst({ where: { displayOrder: s.displayOrder } });
    if (existing) {
      await prisma.wishRoomGuideSlide.update({ where: { id: existing.id }, data: s });
    } else {
      await prisma.wishRoomGuideSlide.create({ data: s });
    }
  }
  console.log(`[seed_wish_room]    -> ${GUIDE_SLIDES.length}개 완료`);

  console.log("[seed_wish_room] 6) luck_pouch_rules(wish_room 세분화) 보강...");
  let ruleCount = 0;
  for (const r of LUCK_POUCH_RULES) {
    const existing = await prisma.luckPouchRule.findFirst({
      where: { ruleType: r.ruleType, actionType: r.actionType, targetScope: r.targetScope },
    });
    if (!existing) {
      await prisma.luckPouchRule.create({ data: r });
      ruleCount++;
    }
  }
  console.log(`[seed_wish_room]    -> ${ruleCount}건 신규 추가(기존 규칙 유지)`);

  console.log("[seed_wish_room] 완료");
}

main()
  .catch((e) => {
    console.error("[seed_wish_room] 실패:", e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
