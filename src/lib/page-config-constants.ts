// [메인화면 관리자 편집기] 화이트리스트 상수 + 검증 헬퍼
//
// 이 파일이 "완전 자유 편집 방지"의 실질적 방어선이다. 관리자는 여기 정의된
// blockType/preset/ruleType 값 중에서만 선택할 수 있고, admin API 라우트는
// 요청 바디를 저장하기 전에 항상 이 화이트리스트로 검증한다(서버 레벨 강제 —
// 프론트 폼에서만 제한하면 API 직접 호출로 우회될 수 있으므로 반드시 서버에서도 검증).

// §7 블록 타입 화이트리스트 — Flutter HomePageRenderer가 blockType -> 특정 위젯으로
// 1:1 매핑한다. 여기 없는 값은 저장 자체가 거부된다(새 위젯을 자유롭게 만들 수 없음).
export const BLOCK_TYPES = [
  "hero_banner",
  "text_banner",
  "CTA_banner",
  "single_card",
  "double_card_grid",
  "horizontal_card_scroll",
  "category_shortcut_row",
  "wish_preview_block",
  "ai_consult_banner",
  "pass_promo_bar",
  "point_status_bar",
  "event_banner",
  "featured_content_block",
] as const;
export type BlockType = (typeof BLOCK_TYPES)[number];

export const BLOCK_TYPE_LABELS: Record<BlockType, string> = {
  hero_banner: "히어로 배너",
  text_banner: "텍스트 배너",
  CTA_banner: "CTA 배너",
  single_card: "단일 카드",
  double_card_grid: "2열 카드 그리드",
  horizontal_card_scroll: "가로 스크롤 카드",
  category_shortcut_row: "카테고리 바로가기 행",
  wish_preview_block: "소원 미리보기 블록",
  ai_consult_banner: "AI 상담 배너",
  pass_promo_bar: "열림패스 바",
  point_status_bar: "포인트(행복머니/복주머니) 상태 바",
  event_banner: "이벤트 배너",
  featured_content_block: "추천 콘텐츠 블록",
};

// §8 스타일 프리셋 — 자유 CSS/폰트/패딩 입력 금지, 디자인 시스템 토큰에 미리
// 매핑된 값만 선택 가능.
export const STYLE_PRESETS = [
  "default",
  "soft",
  "highlighted",
  "compact",
  "premium",
  "black_cta",
  "minimal",
] as const;
export type StylePreset = (typeof STYLE_PRESETS)[number];

export const BACKGROUND_PRESETS = ["white", "lavender", "soft_gray", "black_emphasis"] as const;
export type BackgroundPreset = (typeof BACKGROUND_PRESETS)[number];

export const ALIGNMENT_PRESETS = ["left", "center"] as const;
export type AlignmentPreset = (typeof ALIGNMENT_PRESETS)[number];

export const DENSITY_PRESETS = ["normal", "compact"] as const;
export type DensityPreset = (typeof DENSITY_PRESETS)[number];

export const PLATFORM_TARGETS = ["ios", "android", "web"] as const;
export type PlatformTarget = (typeof PLATFORM_TARGETS)[number];

export const SECTION_STATUSES = ["visible", "hidden", "archived"] as const;
export type SectionStatus = (typeof SECTION_STATUSES)[number];

// §9 노출 조건 규칙 타입 — "개발자용 표현식"이 아니라 (ruleType, ruleOperator,
// ruleValue) 3요소 조합으로만 조건을 만들 수 있게 강제하는 화이트리스트.
export const RULE_TYPES = [
  "login_status",
  "non_login",
  "new_user",
  "open_pass_inactive",
  "open_pass_active",
  "happy_money_balance",
  "luck_pouch_insufficient",
  "daily_fortune_viewed",
  "daily_fortune_not_viewed",
  "wish_board_participated",
  "wish_board_not_participated",
  "event_period",
  "platform",
] as const;
export type RuleType = (typeof RULE_TYPES)[number];

export const RULE_TYPE_LABELS: Record<RuleType, string> = {
  login_status: "로그인 상태",
  non_login: "비로그인 사용자",
  new_user: "신규 가입자",
  open_pass_inactive: "열림패스 비활성",
  open_pass_active: "열림패스 활성",
  happy_money_balance: "행복머니 잔액",
  luck_pouch_insufficient: "복주머니 부족",
  daily_fortune_viewed: "오늘의 운세 확인함",
  daily_fortune_not_viewed: "오늘의 운세 미확인",
  wish_board_participated: "소원게시판 참여함",
  wish_board_not_participated: "소원게시판 미참여",
  event_period: "이벤트 기간",
  platform: "플랫폼",
};

export const RULE_OPERATORS = ["equals", "not_equals", "gte", "lte", "in"] as const;
export type RuleOperator = (typeof RULE_OPERATORS)[number];

// ruleType별로 의미 있는 operator만 허용(예: login_status는 in/equals만, balance류는
// gte/lte 위주) — 관리자가 말이 안 되는 조합(예: 로그인상태 gte)을 만들 수 없도록 제한.
export const RULE_TYPE_ALLOWED_OPERATORS: Record<RuleType, readonly RuleOperator[]> = {
  login_status: ["equals", "not_equals", "in"],
  non_login: ["equals"],
  new_user: ["equals"],
  open_pass_inactive: ["equals"],
  open_pass_active: ["equals"],
  happy_money_balance: ["gte", "lte", "equals"],
  luck_pouch_insufficient: ["equals", "lte"],
  daily_fortune_viewed: ["equals"],
  daily_fortune_not_viewed: ["equals"],
  wish_board_participated: ["equals"],
  wish_board_not_participated: ["equals"],
  event_period: ["equals", "in"],
  platform: ["equals", "in", "not_equals"],
};

// §10 첨부파일 용도 — SectionAttachmentBinding.usageType 화이트리스트.
export const ATTACHMENT_USAGE_TYPES = [
  "banner",
  "sub_banner",
  "icon",
  "background",
  "external_link_asset",
  "fallback",
] as const;
export type AttachmentUsageType = (typeof ATTACHMENT_USAGE_TYPES)[number];

// §11 연동 자산 타입 — linkedAssetType 화이트리스트(열림패스/행복머니/복주머니 정책 연동).
export const LINKED_ASSET_TYPES = ["open_pass", "happy_money", "luck_pouch"] as const;
export type LinkedAssetType = (typeof LINKED_ASSET_TYPES)[number];

// §4 텍스트 길이 제한 — 관리자는 "내용"만 편집하고 폰트/사이즈는 절대 건드릴 수 없다.
// 대신 디자인이 깨지지 않도록 길이 제한을 서버에서 강제한다.
export const TEXT_LIMITS = {
  title: 18,
  subtitle: 40,
  description: 80,
  buttonText: 12,
  badgeText: 10,
  bannerCaption: 50,
  emptyStateText: 40,
} as const;

// §18 필수 섹션 — 완전 삭제 금지(hidden까지만 허용). 실제 강제는 PageSection.isRequired
// 컬럼으로 섹션 단위 관리하며, 이 배열은 시딩/문서 참고용 기본값이다.
export const REQUIRED_SECTION_KEYS = ["fortune_category_grid", "hero_fortune_summary", "pass_status_bar"];

export const PAGE_VERSION_STATUSES = ["draft", "published", "archived"] as const;

// ── 타입 가드(화이트리스트 검증) ──────────────────────────────────────────
export function isValidBlockType(v: unknown): v is BlockType {
  return typeof v === "string" && (BLOCK_TYPES as readonly string[]).includes(v);
}
export function isValidStylePreset(v: unknown): v is StylePreset {
  return typeof v === "string" && (STYLE_PRESETS as readonly string[]).includes(v);
}
export function isValidBackgroundPreset(v: unknown): v is BackgroundPreset {
  return typeof v === "string" && (BACKGROUND_PRESETS as readonly string[]).includes(v);
}
export function isValidAlignmentPreset(v: unknown): v is AlignmentPreset {
  return typeof v === "string" && (ALIGNMENT_PRESETS as readonly string[]).includes(v);
}
export function isValidDensityPreset(v: unknown): v is DensityPreset {
  return typeof v === "string" && (DENSITY_PRESETS as readonly string[]).includes(v);
}
export function isValidSectionStatus(v: unknown): v is SectionStatus {
  return typeof v === "string" && (SECTION_STATUSES as readonly string[]).includes(v);
}
export function isValidRuleType(v: unknown): v is RuleType {
  return typeof v === "string" && (RULE_TYPES as readonly string[]).includes(v);
}
export function isValidRuleOperator(v: unknown): v is RuleOperator {
  return typeof v === "string" && (RULE_OPERATORS as readonly string[]).includes(v);
}
export function isValidAttachmentUsageType(v: unknown): v is AttachmentUsageType {
  return typeof v === "string" && (ATTACHMENT_USAGE_TYPES as readonly string[]).includes(v);
}
export function isValidLinkedAssetType(v: unknown): v is LinkedAssetType {
  return typeof v === "string" && (LINKED_ASSET_TYPES as readonly string[]).includes(v);
}
export function isValidPlatformTarget(v: unknown): v is PlatformTarget {
  return typeof v === "string" && (PLATFORM_TARGETS as readonly string[]).includes(v);
}

// §4/§18 텍스트 길이 validation — malformed config(너무 긴 텍스트) 저장을 서버에서 차단.
export function validateSectionContent(fields: {
  title?: string | null;
  subtitle?: string | null;
  description?: string | null;
  buttonText?: string | null;
  badgeText?: string | null;
  emptyStateText?: string | null;
}): string[] {
  const errors: string[] = [];
  const check = (value: string | null | undefined, limit: number, label: string) => {
    if (value && value.length > limit) {
      errors.push(`${label}은 최대 ${limit}자까지 입력할 수 있습니다. (현재 ${value.length}자)`);
    }
  };
  check(fields.title, TEXT_LIMITS.title, "제목");
  check(fields.subtitle, TEXT_LIMITS.subtitle, "부제목");
  check(fields.description, TEXT_LIMITS.description, "설명");
  check(fields.buttonText, TEXT_LIMITS.buttonText, "버튼 텍스트");
  check(fields.badgeText, TEXT_LIMITS.badgeText, "배지 텍스트");
  check(fields.emptyStateText, TEXT_LIMITS.emptyStateText, "빈 상태 안내문구");
  return errors;
}
