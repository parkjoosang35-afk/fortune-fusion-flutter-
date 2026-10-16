// ══════════════════════════════════════════════════════════════════
// BokjuCouponVisibility — [신통방통 AI 쿠폰 디자인 표시·숨김 기능 §2/§3]
// 11개 쿠폰 정보 항목의 "표시/숨김" 설정 타입 + 기본값 + 레이아웃 재배치
// (reflow) 로직을 한 곳에 모은 공용 모듈.
//
// [핵심 원칙 — §3 "표시 설정과 실제 쿠폰 기능 분리"는 반드시 지켜야 한다]
//   이 모듈은 오직 "이미지에 무엇을 그릴지"만 결정한다. 실제 서버 검증
//   (만료일 체크, 쿠폰 상태 전이, 복주머니 지급액, assignedUserId 검증 등)은
//   전부 bokju-coupon-service.ts(redeemCoupon 등)가 그대로 수행하며, 이
//   visibility 설정은 그 로직을 단 한 줄도 건드리지 않는다. QR코드를 숨겨도
//   공유 링크(shareUrl)는 BokjuCouponShareSection/카카오 공유/등록 플로우에서
//   항상 그대로 노출된다(이미지 안에 QR 그림을 그릴지 말지만 결정할 뿐).
// ══════════════════════════════════════════════════════════════════

/** [§2 체크리스트 11개 항목] 각 boolean이 true면 쿠폰 이미지에 해당 요소를 그린다. */
export interface CouponVisibilityConfig {
  logo: boolean; // 신통방통 로고
  title: boolean; // 쿠폰명
  amount: boolean; // 지급 복주머니 수량
  couponNo: boolean; // 쿠폰번호
  qr: boolean; // QR코드
  validFrom: boolean; // 사용 시작일
  validTo: boolean; // 사용 만료일
  guideText: boolean; // 쿠폰 안내 문구
  ctaText: boolean; // '쿠폰 등록하러 가기' 안내
  partnerName: boolean; // 이벤트명 또는 제휴업체명
  decoration: boolean; // 장식 요소 및 테두리
}

export const VISIBILITY_FIELD_LABELS: Record<keyof CouponVisibilityConfig, string> = {
  logo: "신통방통 로고",
  title: "쿠폰명",
  amount: "지급 복주머니 수량",
  couponNo: "쿠폰번호",
  qr: "QR코드",
  validFrom: "사용 시작일",
  validTo: "사용 만료일",
  guideText: "쿠폰 안내 문구",
  ctaText: "'쿠폰 등록하러 가기' 안내",
  partnerName: "이벤트명 또는 제휴업체명",
  decoration: "장식 요소 및 테두리",
};

export const VISIBILITY_FIELD_ORDER: (keyof CouponVisibilityConfig)[] = [
  "logo",
  "title",
  "amount",
  "couponNo",
  "qr",
  "validFrom",
  "validTo",
  "guideText",
  "ctaText",
  "partnerName",
  "decoration",
];

/** [§2 "모든 항목을 반드시 표시하도록 강제하지 말고"] 기본값은 전부 표시지만,
 * 관리자가 자유롭게 끌 수 있다 — 서버는 어떤 조합이든 그대로 받아들인다. */
export const DEFAULT_VISIBILITY: CouponVisibilityConfig = {
  logo: true,
  title: true,
  amount: true,
  couponNo: true,
  qr: true,
  validFrom: true,
  validTo: true,
  guideText: true,
  ctaText: true,
  partnerName: true,
  decoration: true,
};

/** DB(JSON 문자열)에서 읽은 값에 신규 필드가 없을 수 있으므로(향후 항목 추가
 * 대비) 항상 DEFAULT_VISIBILITY와 병합해 안전하게 정규화한다. */
export function normalizeVisibility(raw: unknown): CouponVisibilityConfig {
  if (!raw || typeof raw !== "object") return { ...DEFAULT_VISIBILITY };
  const r = raw as Record<string, unknown>;
  const out = { ...DEFAULT_VISIBILITY };
  for (const key of VISIBILITY_FIELD_ORDER) {
    if (typeof r[key] === "boolean") out[key] = r[key] as boolean;
  }
  return out;
}

export function parseVisibilityJson(json: string): CouponVisibilityConfig {
  try {
    return normalizeVisibility(JSON.parse(json));
  } catch {
    return { ...DEFAULT_VISIBILITY };
  }
}

export function serializeVisibility(v: CouponVisibilityConfig): string {
  // 항상 고정된 키 순서로 저장해 diff/디버깅이 쉽도록 한다.
  const ordered: Record<string, boolean> = {};
  for (const key of VISIBILITY_FIELD_ORDER) ordered[key] = v[key];
  return JSON.stringify(ordered);
}

// ────────────────────────────────────────────────────────────────
// [§2 "표시하지 않는 항목은 빈 공간이 남지 않도록 나머지 요소를 자연스럽게
// 재배치"] reflow 엔진 — 세로 1열 스택 레이아웃의 각 "블록"에 높이를
// 부여하고, visibility=false인 블록은 건너뛴 뒤 남은 블록들의 y좌표를
// 순서대로 누적 배치한다. 모든 커스텀 템플릿(AI 배경 기반)이 이 계산
// 결과를 그대로 사용하므로, 어떤 조합으로 꺼도 항상 자연스럽게 당겨붙는다.
// ────────────────────────────────────────────────────────────────

export const CANVAS_WIDTH = 720;
export const CANVAS_HEIGHT = 1280;

/** 블록 높이(px) — 실제 buildCustomDesignSvg()의 각 섹션 높이와 반드시
 * 일치시킨다(reflow 계산과 실제 렌더링이 따로 놀면 겹침 버그가 생기므로
 * 이 상수들을 renderer가 그대로 import해서 쓴다 — 단일 소스 원칙). */
export const BLOCK_HEIGHT: Record<keyof CouponVisibilityConfig | "topPadding" | "bottomPadding", number> = {
  topPadding: 60,
  logo: 56,
  partnerName: 44,
  title: 52,
  amount: 150,
  qr: 400,
  couponNo: 48,
  validFrom: 0, // validFrom/validTo는 한 줄로 합쳐 그리므로 validTo 블록에서 함께 처리(아래 참고)
  validTo: 40,
  guideText: 44,
  ctaText: 56,
  decoration: 0, // decoration은 블록이 아니라 전체 배경 위에 겹쳐 그리는 장식이므로 높이를 차지하지 않음
  bottomPadding: 50,
};

export interface LayoutBlock {
  key: keyof CouponVisibilityConfig;
  y: number; // 블록 시작 y좌표(캔버스 기준)
  height: number;
}

export interface ComputedLayout {
  blocks: Partial<Record<keyof CouponVisibilityConfig, LayoutBlock>>;
  contentHeight: number; // 실제 사용된 세로 길이(디버깅/센터링용)
}

/**
 * visibility 설정에 따라 표시되는 블록만 순서대로 쌓아 y좌표를 계산한다.
 * decoration은 레이아웃 흐름에 영향을 주지 않는 오버레이이므로 blocks에
 * 포함하되 높이 0으로 취급(렌더러가 별도로 전체 배경에 테두리를 그릴지
 * 말지 판단하는 플래그로만 사용).
 */
export function computeLayout(visibility: CouponVisibilityConfig): ComputedLayout {
  const order: (keyof CouponVisibilityConfig)[] = [
    "logo",
    "partnerName",
    "title",
    "amount",
    "qr",
    "couponNo",
    "validTo", // validFrom은 validTo와 한 줄에 합쳐 그리므로 별도 블록 없음
    "guideText",
    "ctaText",
  ];

  const blocks: ComputedLayout["blocks"] = {};
  let cursorY = BLOCK_HEIGHT.topPadding;

  for (const key of order) {
    if (!visibility[key]) continue;
    const height = BLOCK_HEIGHT[key];
    blocks[key] = { key, y: cursorY, height };
    cursorY += height;
  }

  // decoration은 흐름에 영향 없는 오버레이 — 표시 여부만 blocks에 기록(높이 0).
  if (visibility.decoration) {
    blocks.decoration = { key: "decoration", y: 0, height: 0 };
  }

  return { blocks, contentHeight: cursorY };
}
