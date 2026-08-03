// [운세 카테고리 확장] fortune_category_groups / fortune_categories 시딩
//
// [설계 원칙] 이미 구현된 카테고리(사주/타로/오늘의운세/관상/손금/궁합/상담)는
// 기존 route/화면을 그대로 참조하도록 매핑하고, 신규 카테고리(월별운세는
// 사주 입력화면 토픽으로 흡수, 타로 YES/NO·감정관계는 타로 입력화면 확장,
// 이름운세는 신규 화면)의 route도 함께 등록한다.
//
// DOMAIN_LABEL/DOMAIN_ORDER(admin_web/src/lib/ai-prompt-domain-meta.ts)와
// 1:1 대응하는 categoryKey를 사용해 AiPromptTemplate과 자연스럽게 연결된다.
import "dotenv/config";
import { PrismaClient } from "../src/generated/prisma/client";
import { PrismaBetterSqlite3 } from "@prisma/adapter-better-sqlite3";

const adapter = new PrismaBetterSqlite3({
  url: process.env.DATABASE_URL ?? "file:./prisma/dev.db",
});
const prisma = new PrismaClient({ adapter });

const GROUPS = [
  { code: "today", label: "오늘/간편 운세", description: "오늘 하루의 흐름을 빠르게 확인해보세요", displayOrder: 1 },
  { code: "saju", label: "사주 운세", description: "타고난 기운과 인생의 방향을 깊게 해석해보세요", displayOrder: 2 },
  { code: "tarot", label: "타로 운세", description: "지금 마음이 궁금할 때, 카드에게 물어보세요", displayOrder: 3 },
  { code: "compatibility_relation", label: "궁합/관계 운세", description: "나와 상대, 서로의 마음을 확인해보세요", displayOrder: 4 },
  { code: "face_palm", label: "얼굴/손금 운세", description: "얼굴과 손에 담긴 이야기를 읽어보세요", displayOrder: 5 },
  { code: "name_theme", label: "이름/테마 운세", description: "이름에 담긴 기운과 테마 운세를 만나보세요", displayOrder: 6 },
  { code: "consultation_ext", label: "상담/확장형 운세", description: "혼자 고민하지 말고 함께 이야기해요", displayOrder: 7 },
  // [남은 미세조정] "행운/정화"(부적 상점/부적 만들기)는 기존에 이미 동작하는
  // 화면(/reward/amulet, /reward/amulet/generate)이지만 관리자 스키마 밖에
  // 있었다. 새 기능을 만들지 않고, 이미 있는 정적 항목을 그대로 관리자
  // 카테고리로 승격(admin-manageable화)한다.
  { code: "luck_purify", label: "행운/정화", description: "부적과 정화 의식으로 행운의 기운을 더해보세요", displayOrder: 8 },
] as const;

// categoryKey는 AiPromptTemplate.fortuneTypeOrDomain과 동일 값 사용(1:1 매핑)
const CATEGORIES: Array<{
  categoryKey: string;
  slug: string;
  title: string;
  shortDescription: string;
  groupCode: string;
  icon: string;
  displayOrder: number;
  isFeatured: boolean;
  badgeLabel?: string;
  requiresPass: boolean;
  route: string | null;
  resultLengthHint: string;
  relatedCategoryKeys: string[];
}> = [
  {
    categoryKey: "daily",
    slug: "daily-fortune",
    title: "오늘의 운세",
    shortDescription: "오늘 하루의 흐름과 행운 포인트",
    groupCode: "today",
    icon: "wb_sunny_outlined",
    displayOrder: 1,
    isFeatured: true,
    badgeLabel: "대표",
    requiresPass: false,
    route: "/home/daily-fortune-detail",
    resultLengthHint: "200자 이내",
    relatedCategoryKeys: ["saju", "tarot"],
  },
  {
    categoryKey: "saju",
    slug: "saju",
    title: "사주 종합운",
    shortDescription: "타고난 기운과 인생의 방향",
    groupCode: "saju",
    icon: "auto_stories_outlined",
    displayOrder: 1,
    isFeatured: true,
    badgeLabel: "대표",
    requiresPass: true,
    route: "/ai-fortune/saju/input",
    resultLengthHint: "400~500자",
    relatedCategoryKeys: ["saju_wealth", "saju_career", "saju_love", "saju_health", "saju_monthly", "name"],
  },
  {
    categoryKey: "saju_wealth",
    slug: "saju-wealth",
    title: "오행 재운",
    shortDescription: "오행으로 보는 재물의 흐름",
    groupCode: "saju",
    icon: "attach_money_outlined",
    displayOrder: 2,
    isFeatured: false,
    requiresPass: true,
    route: "/ai-fortune/saju/input",
    resultLengthHint: "400~500자",
    relatedCategoryKeys: ["saju", "saju_career"],
  },
  {
    categoryKey: "saju_career",
    slug: "saju-career",
    title: "사주 관운(직업운)",
    shortDescription: "관운과 직업 방향을 사주로 확인",
    groupCode: "saju",
    icon: "work_outline_rounded",
    displayOrder: 3,
    isFeatured: false,
    requiresPass: true,
    route: "/ai-fortune/saju/input",
    resultLengthHint: "400~500자",
    relatedCategoryKeys: ["saju", "saju_wealth"],
  },
  {
    categoryKey: "saju_love",
    slug: "saju-love",
    title: "사주 연애운",
    shortDescription: "사주로 보는 연애와 인연의 흐름",
    groupCode: "saju",
    icon: "favorite_outline_rounded",
    displayOrder: 4,
    isFeatured: false,
    requiresPass: true,
    route: "/ai-fortune/saju/input",
    resultLengthHint: "400~500자",
    relatedCategoryKeys: ["saju", "compatibility"],
  },
  {
    categoryKey: "saju_health",
    slug: "saju-health",
    title: "사주 건강운",
    shortDescription: "사주로 보는 몸과 마음의 균형",
    groupCode: "saju",
    icon: "health_and_safety_outlined",
    displayOrder: 5,
    isFeatured: false,
    requiresPass: true,
    route: "/ai-fortune/saju/input",
    resultLengthHint: "400~500자",
    relatedCategoryKeys: ["saju"],
  },
  {
    categoryKey: "saju_monthly",
    slug: "saju-monthly",
    title: "사주 월별 운세",
    shortDescription: "이번 달의 흐름을 사주로 짚어보기",
    groupCode: "saju",
    icon: "calendar_month_outlined",
    displayOrder: 6,
    isFeatured: false,
    badgeLabel: "NEW",
    requiresPass: true,
    route: "/ai-fortune/saju/input",
    resultLengthHint: "400~500자",
    relatedCategoryKeys: ["saju", "daily"],
  },
  {
    categoryKey: "tarot",
    slug: "tarot",
    title: "타로 종합운",
    shortDescription: "지금 마음과 선택의 해석",
    groupCode: "tarot",
    icon: "style_outlined",
    displayOrder: 1,
    isFeatured: true,
    badgeLabel: "대표",
    requiresPass: true,
    route: "/ai-fortune/tarot/question",
    resultLengthHint: "400~500자(3카드)",
    relatedCategoryKeys: ["tarot_love", "tarot_yesno"],
  },
  {
    categoryKey: "tarot_yesno",
    slug: "tarot-yesno",
    title: "타로 YES/NO",
    shortDescription: "빠른 방향 제시가 필요할 때",
    groupCode: "tarot",
    icon: "help_outline_rounded",
    displayOrder: 2,
    isFeatured: false,
    badgeLabel: "NEW",
    requiresPass: true,
    route: "/ai-fortune/tarot/question",
    resultLengthHint: "400~500자",
    relatedCategoryKeys: ["tarot"],
  },
  {
    categoryKey: "tarot_love",
    slug: "tarot-love",
    title: "타로 감정 관계운",
    shortDescription: "지금 감정과 관계의 흐름 읽기",
    groupCode: "tarot",
    icon: "favorite_border_rounded",
    displayOrder: 3,
    isFeatured: false,
    badgeLabel: "NEW",
    requiresPass: true,
    route: "/ai-fortune/tarot/question",
    resultLengthHint: "400~500자",
    relatedCategoryKeys: ["tarot", "compatibility"],
  },
  {
    categoryKey: "compatibility",
    slug: "compatibility",
    title: "궁합 운세",
    shortDescription: "나와 상대, 서로의 마음과 관계 흐름",
    groupCode: "compatibility_relation",
    icon: "favorite_outline_rounded",
    displayOrder: 1,
    isFeatured: true,
    badgeLabel: "대표",
    requiresPass: true,
    route: "/ai-fortune/compatibility/input",
    resultLengthHint: "400~500자",
    relatedCategoryKeys: ["saju_love", "tarot_love", "name"],
  },
  {
    categoryKey: "name",
    slug: "name-fortune",
    title: "이름 운세(성명학)",
    shortDescription: "이름에 담긴 기운을 성명학으로 해석",
    groupCode: "name_theme",
    icon: "badge_outlined",
    displayOrder: 1,
    isFeatured: false,
    badgeLabel: "NEW",
    requiresPass: true,
    route: "/ai-fortune/name/input",
    resultLengthHint: "400~500자",
    relatedCategoryKeys: ["saju", "compatibility"],
  },
  {
    categoryKey: "face",
    slug: "face",
    title: "관상",
    shortDescription: "얼굴에 담긴 이야기를 읽어보세요",
    groupCode: "face_palm",
    icon: "face_outlined",
    displayOrder: 1,
    isFeatured: true,
    requiresPass: true,
    route: "/ai-fortune/face/capture",
    resultLengthHint: "1,500~2,500자",
    relatedCategoryKeys: ["palm"],
  },
  {
    categoryKey: "palm",
    slug: "palm",
    title: "손금",
    shortDescription: "손바닥 속 손금선이 알려주는 이야기",
    groupCode: "face_palm",
    icon: "back_hand_outlined",
    displayOrder: 2,
    isFeatured: false,
    requiresPass: true,
    route: "/ai-fortune/palm/capture",
    resultLengthHint: "이미지 기반 분석",
    relatedCategoryKeys: ["face"],
  },
  {
    categoryKey: "consultation",
    slug: "consultation",
    title: "AI 상담",
    shortDescription: "혼자 고민하지 말고 함께 이야기해요",
    groupCode: "consultation_ext",
    icon: "chat_bubble_outline_rounded",
    displayOrder: 1,
    isFeatured: false,
    requiresPass: true,
    route: "/ai-fortune/consultation/type",
    resultLengthHint: "300자 이내",
    relatedCategoryKeys: ["daily"],
  },
  // [남은 미세조정] 이미 구현되어 동작 중인 부적 화면을 admin-manageable
  // 카테고리로 승격(신규 기능 아님, 기존 정적 항목 그대로 매핑).
  {
    categoryKey: "amulet",
    slug: "amulet",
    title: "행운의 부적",
    shortDescription: "나에게 필요한 행운의 부적을 만나보세요",
    groupCode: "luck_purify",
    icon: "shield_outlined",
    displayOrder: 1,
    isFeatured: false,
    requiresPass: false,
    route: "/reward/amulet",
    resultLengthHint: "부적 상점",
    relatedCategoryKeys: ["amulet_generate"],
  },
  {
    categoryKey: "amulet_generate",
    slug: "amulet-generate",
    title: "부적 만들기",
    shortDescription: "나만의 맞춤 부적을 직접 만들어보세요",
    groupCode: "luck_purify",
    icon: "auto_fix_high_outlined",
    displayOrder: 2,
    isFeatured: false,
    requiresPass: false,
    route: "/reward/amulet/generate",
    resultLengthHint: "맞춤 생성",
    relatedCategoryKeys: ["amulet"],
  },
];

async function seedGroups() {
  console.log("[seed_fortune_categories] 1) fortune_category_groups 시딩...");
  const map = new Map<string, number>();
  for (const g of GROUPS) {
    const row = await prisma.fortuneCategoryGroup.upsert({
      where: { code: g.code },
      update: {
        label: g.label,
        description: g.description,
        displayOrder: g.displayOrder,
        updatedBy: "system",
      },
      create: {
        code: g.code,
        label: g.label,
        description: g.description,
        displayOrder: g.displayOrder,
        createdBy: "system",
        updatedBy: "system",
      },
    });
    map.set(g.code, row.id);
  }
  console.log(`[seed_fortune_categories]    -> ${map.size}개 그룹 upsert 완료`);
  return map;
}

async function seedCategories(groupMap: Map<string, number>) {
  console.log("[seed_fortune_categories] 2) fortune_categories 시딩...");
  let count = 0;
  for (const c of CATEGORIES) {
    const groupId = groupMap.get(c.groupCode) ?? null;
    await prisma.fortuneCategory.upsert({
      where: { categoryKey: c.categoryKey },
      update: {
        slug: c.slug,
        title: c.title,
        shortDescription: c.shortDescription,
        groupId,
        icon: c.icon,
        displayOrder: c.displayOrder,
        isFeatured: c.isFeatured,
        badgeLabel: c.badgeLabel ?? null,
        requiresPass: c.requiresPass,
        route: c.route,
        resultLengthHint: c.resultLengthHint,
        relatedCategoryKeys: JSON.stringify(c.relatedCategoryKeys),
        updatedBy: "system",
      },
      create: {
        categoryKey: c.categoryKey,
        slug: c.slug,
        title: c.title,
        shortDescription: c.shortDescription,
        groupId,
        icon: c.icon,
        displayOrder: c.displayOrder,
        isFeatured: c.isFeatured,
        badgeLabel: c.badgeLabel ?? null,
        requiresPass: c.requiresPass,
        route: c.route,
        resultLengthHint: c.resultLengthHint,
        relatedCategoryKeys: JSON.stringify(c.relatedCategoryKeys),
        createdBy: "system",
        updatedBy: "system",
      },
    });
    count++;
  }
  console.log(`[seed_fortune_categories]    -> ${count}개 카테고리 upsert 완료`);
}

async function main() {
  const groupMap = await seedGroups();
  await seedCategories(groupMap);
  console.log("[seed_fortune_categories] 완료.");
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
