// [메인화면 관리자 편집기] page_configs / page_versions / page_sections 초기 시딩
//
// [설계 원칙] 처음부터 스펙의 "예시 섹션 목록"을 그대로 심지 않고,
// 실제 동작 중인 home_screen_cosmic.dart의 8개 실섹션(+AppBar에 고정된
// 열림패스 상태바)을 BLOCK_TYPES 화이트리스트에 매핑해 시딩한다.
// (기존 화면을 재구현하지 않고, 이미 있는 화면을 관리자 데이터로 승격하는
// 이 프로젝트의 일관된 원칙을 그대로 따름.)
//
// 버전 구조: pageKey="home" 에 대해
//   v1 (status=published, publishedAt=now) : 최초 발행 버전
//   v2 (status=draft, v1을 그대로 복제)     : 관리자가 편집할 초기 draft
// PageConfig.currentPublishedVersionId -> v1, currentDraftVersionId -> v2
import "dotenv/config";
import { PrismaClient } from "../src/generated/prisma/client";
import { PrismaBetterSqlite3 } from "@prisma/adapter-better-sqlite3";

const adapter = new PrismaBetterSqlite3({
  url: process.env.DATABASE_URL ?? "file:./prisma/dev.db",
});
const prisma = new PrismaClient({ adapter });

const PAGE_KEY = "home";

// home_screen_cosmic.dart 실제 렌더 순서 그대로 매핑.
// sectionKey는 버전이 바뀌어도(v1->v2->...) 같은 논리적 섹션을 추적하는
// 안정 식별자로 사용한다(중복 삽입/삭제/재정렬 시에도 유지).
const SECTIONS: Array<{
  sectionKey: string;
  blockType: string;
  title: string | null;
  subtitle: string | null;
  description: string | null;
  buttonText: string | null;
  buttonLink: string | null;
  badgeText: string | null;
  stylePreset: string;
  backgroundPreset: string;
  alignmentPreset: string;
  densityPreset: string;
  isPinned: boolean;
  isRequired: boolean;
  linkedAssetType: string | null;
  linkedFeatureScope: string | null;
}> = [
  {
    sectionKey: "pass_status_bar",
    blockType: "pass_promo_bar",
    title: "열림패스",
    subtitle: "AppBar 하단 고정 상태 바",
    description: "현재 열림패스 상태를 항상 보여주는 고정 영역(_AlarmPassStatusBar)",
    buttonText: null,
    buttonLink: null,
    badgeText: null,
    stylePreset: "compact",
    backgroundPreset: "white",
    alignmentPreset: "left",
    densityPreset: "compact",
    isPinned: true,
    isRequired: true,
    linkedAssetType: "open_pass",
    linkedFeatureScope: "pass_status_bar",
  },
  {
    sectionKey: "pass_promo",
    blockType: "pass_promo_bar",
    title: "열림패스로 더 많은 운세를",
    subtitle: "광고 시청 · 제휴 · 구독으로 이용권 받기",
    description: "열림패스가 비활성 상태인 유저에게만 노출되는 CTA 섹션",
    buttonText: "패스 받기",
    buttonLink: "/pass",
    badgeText: "추천",
    stylePreset: "highlighted",
    backgroundPreset: "lavender",
    alignmentPreset: "left",
    densityPreset: "normal",
    isPinned: false,
    isRequired: false,
    linkedAssetType: "open_pass",
    linkedFeatureScope: "pass_promo_section",
  },
  {
    sectionKey: "fortune_category_grid",
    blockType: "category_shortcut_row",
    title: "🔮 운세 카테고리",
    subtitle: null,
    description: "타로/사주/궁합/관상/손금/전체운세 바로가기 그리드",
    buttonText: null,
    buttonLink: "/fortune/categories",
    badgeText: null,
    stylePreset: "default",
    backgroundPreset: "white",
    alignmentPreset: "left",
    densityPreset: "normal",
    isPinned: false,
    isRequired: true,
    linkedAssetType: null,
    linkedFeatureScope: "fortune_category_grid",
  },
  {
    sectionKey: "hero_fortune_summary",
    blockType: "hero_banner",
    title: "오늘의 대표 운세",
    subtitle: "오늘 하루의 흐름을 미리 확인해보세요",
    description: "오늘의 운세 요약 + 오늘의 행운숫자 무료 프리뷰 카드",
    buttonText: "자세히 보기",
    buttonLink: "/fortune/daily",
    badgeText: "무료",
    stylePreset: "premium",
    backgroundPreset: "white",
    alignmentPreset: "left",
    densityPreset: "normal",
    isPinned: false,
    isRequired: true,
    linkedAssetType: null,
    linkedFeatureScope: "daily_fortune_summary",
  },
  {
    sectionKey: "lucky_number",
    blockType: "single_card",
    title: "🔢 오늘의 행운 숫자",
    subtitle: null,
    description: "오늘의 행운 숫자를 보여주는 단일 카드 섹션",
    buttonText: null,
    buttonLink: "/fortune/lucky-number",
    badgeText: null,
    stylePreset: "soft",
    backgroundPreset: "white",
    alignmentPreset: "center",
    densityPreset: "normal",
    isPinned: false,
    isRequired: false,
    linkedAssetType: null,
    linkedFeatureScope: "lucky_number_section",
  },
  {
    sectionKey: "wish_community_preview",
    blockType: "wish_preview_block",
    title: "🌠 지금 인기 있는 소원",
    subtitle: null,
    description: "인기 소원 미리보기 + 커뮤니티 배너",
    buttonText: "더보기",
    buttonLink: "/community/wish",
    badgeText: null,
    stylePreset: "default",
    backgroundPreset: "white",
    alignmentPreset: "left",
    densityPreset: "normal",
    isPinned: false,
    isRequired: false,
    linkedAssetType: null,
    linkedFeatureScope: "wish_community_preview",
  },
  {
    sectionKey: "happy_money_earn",
    blockType: "point_status_bar",
    title: "🍀 행복머니 적립하기",
    subtitle: null,
    description: "출석/미션/글쓰기 등 행복머니 적립 유도 섹션",
    buttonText: "적립하기",
    buttonLink: "/reward/earn",
    badgeText: null,
    stylePreset: "highlighted",
    backgroundPreset: "soft_gray",
    alignmentPreset: "left",
    densityPreset: "normal",
    isPinned: false,
    isRequired: false,
    linkedAssetType: "happy_money",
    linkedFeatureScope: "happy_money_earn_section",
  },
  {
    sectionKey: "happy_money_use",
    blockType: "double_card_grid",
    title: "✨ 행복머니 사용처",
    subtitle: null,
    description: "부적/매칭 등 행복머니 사용처 카드 2열 그리드",
    buttonText: null,
    buttonLink: "/reward/amulet",
    badgeText: null,
    stylePreset: "default",
    backgroundPreset: "white",
    alignmentPreset: "left",
    densityPreset: "normal",
    isPinned: false,
    isRequired: false,
    linkedAssetType: "happy_money",
    linkedFeatureScope: "happy_money_use_section",
  },
  {
    sectionKey: "subscription_promo",
    blockType: "event_banner",
    title: "💎 구독으로 더 큰 혜택",
    subtitle: "구독 프로모션 + 관리자 등록 광고 배너",
    description: "구독 상품 프로모션 배너와 home_bottom 광고 배너 슬롯",
    buttonText: "구독하기",
    buttonLink: "/subscription",
    badgeText: "혜택",
    stylePreset: "black_cta",
    backgroundPreset: "black_emphasis",
    alignmentPreset: "center",
    densityPreset: "normal",
    isPinned: false,
    isRequired: false,
    linkedAssetType: null,
    linkedFeatureScope: "subscription_promo_section",
  },
];

async function upsertPageConfig() {
  console.log(`[seed_page_config_home] 1) page_configs("${PAGE_KEY}") upsert...`);
  const existing = await prisma.pageConfig.findUnique({ where: { pageKey: PAGE_KEY } });
  if (existing) {
    console.log("[seed_page_config_home]    -> 이미 존재함. 재시딩 건너뜀 (id=" + existing.id + ")");
    return existing;
  }
  const config = await prisma.pageConfig.create({ data: { pageKey: PAGE_KEY } });
  console.log(`[seed_page_config_home]    -> 생성 완료 (id=${config.id})`);
  return config;
}

async function createVersionWithSections(
  versionNumber: number,
  status: "draft" | "published",
  publishedAt: Date | null,
) {
  const version = await prisma.pageVersion.create({
    data: {
      pageKey: PAGE_KEY,
      versionNumber,
      status,
      createdBy: "system",
      publishedBy: status === "published" ? "system" : null,
      publishedAt,
    },
  });

  for (let i = 0; i < SECTIONS.length; i++) {
    const s = SECTIONS[i];
    await prisma.pageSection.create({
      data: {
        pageVersionId: version.id,
        sectionKey: s.sectionKey,
        blockType: s.blockType,
        title: s.title,
        subtitle: s.subtitle,
        description: s.description,
        buttonText: s.buttonText,
        buttonLink: s.buttonLink,
        badgeText: s.badgeText,
        stylePreset: s.stylePreset,
        backgroundPreset: s.backgroundPreset,
        alignmentPreset: s.alignmentPreset,
        densityPreset: s.densityPreset,
        isVisible: true,
        status: "visible",
        isPinned: s.isPinned,
        isRequired: s.isRequired,
        sortOrder: i,
        linkedAssetType: s.linkedAssetType,
        linkedFeatureScope: s.linkedFeatureScope,
        createdBy: "system",
        updatedBy: "system",
      },
    });
  }

  console.log(
    `[seed_page_config_home]    -> v${versionNumber}(${status}) 섹션 ${SECTIONS.length}개 생성 완료 (versionId=${version.id})`,
  );
  return version;
}

async function main() {
  const config = await upsertPageConfig();

  // 이미 시딩된 경우(재실행) 버전 생성은 건너뛴다.
  if (config.currentPublishedVersionId || config.currentDraftVersionId) {
    console.log("[seed_page_config_home] 이미 버전이 연결되어 있음. 완료.");
    return;
  }

  console.log("[seed_page_config_home] 2) v1(published) 생성...");
  const v1 = await createVersionWithSections(1, "published", new Date());

  console.log("[seed_page_config_home] 3) v2(draft, v1 복제) 생성...");
  const v2 = await createVersionWithSections(2, "draft", null);

  console.log("[seed_page_config_home] 4) page_configs 포인터 연결...");
  await prisma.pageConfig.update({
    where: { id: config.id },
    data: {
      currentPublishedVersionId: v1.id,
      currentDraftVersionId: v2.id,
    },
  });

  await prisma.pageAuditLog.create({
    data: {
      adminId: "system",
      pageKey: PAGE_KEY,
      actionType: "publish",
      summary: `초기 시딩: v${v1.versionNumber} 발행, v${v2.versionNumber} draft 생성`,
    },
  });

  console.log("[seed_page_config_home] 완료.");
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
