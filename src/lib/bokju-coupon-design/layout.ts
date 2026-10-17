// src/lib/bokju-coupon-design/layout.ts
// ─────────────────────────────────────────────────────────────────────
// 쿠폰 디자인 레이아웃 — "표시항목 자리배치" 를 데이터로 표현한다.
//
// [이식 메모] 1차 전달 패키지 src/coupon/design/layout.ts 를 그대로 이식.
//   개발팀-지시서-2차.md §4: "그대로. 스키마 + 검증 6종 + 프리셋". 변경 없음.
//
// 요구사항 대응
//   · 표시항목(로고·쿠폰명·수량·번호·QR·유효기간·안내문구)의 위치를
//     에디터에서 자유롭게 옮길 수 있어야 한다  → elements[].x / y
//   · 어떤 쿠폰을 만들지 미리 모르므로 "빈 캔버스"에서 시작할 수 있어야 한다
//     → BLANK_LAYOUT + addElement()
//   · QR 을 쓰지 않을 때 그 자리에 이미지를 넣을 수 있어야 한다
//     → kind='qr' 을 kind='image' 로 바꾸거나, useQr=false 로 두고 이미지 배치
//
// 설계 원칙
//   · 좌표는 "캔버스 픽셀" 절대값. 비율(%)이 아니라 픽셀로 두어 렌더가 단순하다.
//   · x,y 는 요소의 중심점(anchor='center')을 기본으로 한다.
//     회전·정렬·QR 합성이 중심 기준일 때 훨씬 단순해진다.
//   · z 는 레이어 순서. 렌더 시 오름차순으로 그린다.
//   · 잠금(locked) 요소는 에디터에서 이동을 막는다(로고 등 실수 방지).
// ─────────────────────────────────────────────────────────────────────
import { z } from 'zod';
import {
  themeSchema, resolveTheme, tokenColor, contrastRatio, ensureContrast,
  type ResolvedTheme,
} from './theme';

export const CANVAS_PRESETS = {
  PORTRAIT_1080: { width: 1080, height: 1920 },
  PORTRAIT_720: { width: 720, height: 1280 },
  SQUARE_1080: { width: 1080, height: 1080 },
} as const;

export const ELEMENT_KINDS = ['text', 'image', 'qr', 'box', 'line'] as const;

/** 값이 쿠폰마다 달라지는 항목의 데이터 출처 */
export const BIND_SOURCES = [
  'static',                 // 고정 텍스트
  'campaign.title',         // 쿠폰명
  'campaign.grantAmount',   // 지급 복주머니
  'campaign.guideText',     // 안내 문구
  'campaign.validPeriod',   // 사용기간
  'coupon.couponNo',        // 쿠폰번호
  'coupon.qr',              // QR (payload = 등록 링크)
  'brand.domain',           // 도메인 (sintong.kr) — QR 을 못 찍는 상황의 안내
  'coupon.registerUrl',     // 쿠폰별 등록 주소 (sintong.kr/coupon/토큰)
  // [2단계 — 02c_2단계-결정사항.md §2] 제휴업체명. 호출부(이미지 생성 job)가
  // coupon.partnerId → BokjuPartner.name 을 미리 조회해 RenderContext.partnerName
  // 으로 전달한다(렌더러는 BokjuCoupon* 모델을 직접 읽지 않는다). 값이 없으면
  // (미배정 쿠폰) 렌더러는 이 바인딩의 요소를 건너뛴다 — campaignTitle 로
  // 대체하지 않는다(기존 bokju-coupon-image-service.ts 의 대체 동작과 다르다:
  // 제휴업체명 자리에 캠페인 제목을 넣으면 고객에게 사실과 다른 정보가 나간다).
  'partner.name',
] as const;

export type ElementKind = (typeof ELEMENT_KINDS)[number];
export type BindSource = (typeof BIND_SOURCES)[number];

const hex = z.string().regex(/^#[0-9a-fA-F]{6}$/, '색상은 #RRGGBB 형식이어야 합니다.');
/** 테마 토큰 참조 — '@primary' 처럼 쓴다. 팔레트를 바꾸면 이 요소가 따라온다. */
const tokenRef = z.string().regex(/^@[a-zA-Z]+$/, "토큰은 '@primary' 형식이어야 합니다.");

export const layoutElementSchema = z.object({
  id: z.string().min(1).max(40),
  kind: z.enum(ELEMENT_KINDS),
  /** 에디터 좌측 "표시항목" 목록에 보이는 이름 */
  name: z.string().min(1).max(40),
  bind: z.enum(BIND_SOURCES).default('static'),

  // ── 위치 (중심점 기준) ──
  x: z.number().finite(),
  y: z.number().finite(),
  // 미지정이면 렌더러가 'center' 로 해석한다. 프리셋 리터럴에서 생략 가능.
  anchor: z.enum(['center', 'topleft']).optional(),

  // ── 크기 ──
  width: z.number().positive().max(4000).optional(),
  height: z.number().positive().max(4000).optional(),

  // ── 텍스트 ──
  text: z.string().max(300).optional(),
  fontSize: z.number().positive().max(400).optional(),
  fontWeight: z.number().int().min(100).max(900).optional(),
  color: hex.optional(),
  align: z.enum(['left', 'center', 'right']).optional(),
  letterSpacing: z.number().min(-20).max(60).optional(),
  lineHeight: z.number().min(0.8).max(3).optional(),
  maxLines: z.number().int().min(1).max(10).optional(),

  // ── 이미지 ──
  assetId: z.string().nullable().optional(),
  assetUrl: z.string().max(500).nullable().optional(),
  fit: z.enum(['contain', 'cover']).optional(),
  radius: z.number().min(0).max(2000).optional(),
  opacity: z.number().min(0).max(1).optional(),
  rotation: z.number().min(-360).max(360).optional(),

  // ── 도형 ──
  fill: hex.optional(),
  stroke: hex.optional(),
  strokeWidth: z.number().min(0).max(40).optional(),

  // ── 색 참조 (테마 토큰) ──
  // '@primary' 처럼 쓰면 팔레트를 바꿔도 이 요소가 따라온다.
  // 아래 color/fill/stroke 리터럴보다 우선한다.
  colorToken: tokenRef.optional(),
  fillToken: tokenRef.optional(),
  strokeToken: tokenRef.optional(),
  /** 점선 패턴 — '16 12' 처럼 SVG stroke-dasharray 값을 그대로 쓴다 */
  dash: z.string().max(40).optional(),

  // ── 레이어 ──
  z: z.number().int().min(0).max(999),
  locked: z.boolean().optional(),
  visible: z.boolean().optional(),
});

export const designLayoutSchema = z.object({
  version: z.literal(1),
  canvas: z.object({
    width: z.number().int().min(200).max(4000),
    height: z.number().int().min(200).max(4000),
    background: hex.default('#fffdfb'),
    /** 배경도 토큰으로 지정할 수 있다 — 팔레트를 바꾸면 배경까지 따라온다 */
    backgroundToken: tokenRef.optional(),
    backgroundAssetId: z.string().nullable().optional(),
    backgroundAssetUrl: z.string().max(500).nullable().optional(),
  }),
  elements: z.array(layoutElementSchema).max(60),
  /**
   * QR 미사용 쿠폰의 등록 방식.
   *   QR    — 이미지에 QR 이 있어 스캔으로 진입
   *   MANUAL — QR 없이 발행. 고객은 공유 링크 또는 쿠폰번호 직접 입력으로 등록
   * ※ 둘 중 어느 쪽이든 공유 링크(토큰)는 항상 동작한다.
   */
  redeemMode: z.enum(['QR', 'MANUAL']).default('QR'),
  /**
   * 색 · 글자 · 여백 토큰. 없으면 기본 팔레트로 해석한다.
   * 요소가 '@primary' 같은 토큰을 참조하므로, 팔레트 하나를 고르면
   * 배치를 그대로 둔 채 쿠폰 전체 색이 바뀐다.
   */
  theme: themeSchema.optional(),
});

export type LayoutElement = z.infer<typeof layoutElementSchema>;
export type DesignLayout = z.infer<typeof designLayoutSchema>;

// ────────────────────────────────────────────────── 검증 · 경고
export interface LayoutIssue {
  level: 'error' | 'warn';
  code: string;
  message: string;
  elementId?: string;
}

/**
 * 저장 전 검증. error 가 하나라도 있으면 저장을 막고,
 * warn 은 저장은 하되 에디터에 노란 경고로 보여준다.
 */
export function validateLayout(input: unknown): { ok: boolean; issues: LayoutIssue[]; layout?: DesignLayout } {
  const parsed = designLayoutSchema.safeParse(input);
  if (!parsed.success) {
    return {
      ok: false,
      issues: parsed.error.issues.map((i) => ({
        level: 'error' as const,
        code: 'SCHEMA',
        message: `${i.path.join('.')}: ${i.message}`,
      })),
    };
  }

  const layout = parsed.data;
  const issues: LayoutIssue[] = [];
  const { width: W, height: H } = layout.canvas;

  // 1) 캔버스 밖으로 나간 요소
  for (const el of layout.elements) {
    if (el.x < 0 || el.x > W || el.y < 0 || el.y > H) {
      issues.push({
        level: 'error', code: 'OUT_OF_CANVAS',
        message: `'${el.name}' 이 캔버스 밖에 있습니다 (${Math.round(el.x)}, ${Math.round(el.y)}).`,
        elementId: el.id,
      });
    }
  }

  // 2) QR 을 뺐는데 등록 방식이 QR 로 남아 있는 경우
  const hasQr = layout.elements.some((e) => e.kind === 'qr' && e.visible !== false);
  if (!hasQr && layout.redeemMode === 'QR') {
    issues.push({
      level: 'warn', code: 'QR_MISSING',
      message: 'QR 요소가 없습니다. 이대로 발행하면 고객은 공유 링크 또는 쿠폰번호 직접 입력으로만 등록할 수 있습니다.',
    });
  }
  if (hasQr && layout.redeemMode === 'MANUAL') {
    issues.push({
      level: 'warn', code: 'QR_PRESENT_MANUAL',
      message: 'QR 요소가 있지만 등록 방식이 "번호 직접 입력" 입니다. QR 을 살리려면 등록 방식을 QR 로 바꾸세요.',
    });
  }

  // 3) 쿠폰번호가 이미지에 없으면 고객이 번호를 알 수 없다
  const hasCouponNo = layout.elements.some(
    (e) => e.bind === 'coupon.couponNo' && e.visible !== false,
  );
  if (!hasCouponNo && layout.redeemMode === 'MANUAL') {
    issues.push({
      level: 'error', code: 'NO_COUPON_NO',
      message: '번호 직접 입력 방식인데 쿠폰번호 요소가 없습니다. 고객이 번호를 알 수 없습니다.',
    });
  }

  // 4) 쿠폰마다 달라지는 값이 하나도 없으면 1만 장이 모두 같은 이미지가 된다
  const hasDynamic = layout.elements.some(
    (e) => e.bind === 'coupon.couponNo' || e.bind === 'coupon.qr',
  );
  if (!hasDynamic) {
    issues.push({
      level: 'error', code: 'NO_DYNAMIC_BINDING',
      message: '쿠폰번호나 QR 중 최소 하나는 있어야 합니다. 없으면 발행한 쿠폰 1만 장이 모두 동일한 이미지가 됩니다.',
    });
  }

  // 5) 이미지 요소에 소스가 없는 경우
  for (const el of layout.elements) {
    if (el.kind === 'image' && !el.assetUrl && !el.assetId) {
      issues.push({
        level: 'warn', code: 'IMAGE_EMPTY',
        message: `'${el.name}' 이미지가 아직 첨부되지 않았습니다.`,
        elementId: el.id,
      });
    }
  }

  // 6) 텍스트 요소인데 내용이 비어 있는 경우
  for (const el of layout.elements) {
    if (el.kind === 'text' && el.bind === 'static' && !el.text?.trim()) {
      issues.push({
        level: 'warn', code: 'TEXT_EMPTY',
        message: `'${el.name}' 텍스트가 비어 있습니다.`,
        elementId: el.id,
      });
    }
  }

  // 7) 안전 여백 — 인쇄 · 모서리 잘림 방지
  const theme = resolveTheme(layout.theme);
  if (theme.safeArea > 0) {
    const s = theme.safeArea;
    for (const el of layout.elements) {
      if (el.visible === false) continue;
      const hw = (el.width ?? 0) / 2, hh = (el.height ?? 0) / 2;
      if (el.x - hw < s || el.x + hw > W - s || el.y - hh < s || el.y + hh > H - s) {
        issues.push({
          level: 'warn', code: 'SAFE_AREA',
          message: `'${el.name}' 이 안전 여백(${s}px)을 벗어났습니다. 인쇄하거나 화면 가장자리에서 잘릴 수 있습니다.`,
          elementId: el.id,
        });
      }
    }
  }

  // 8) 글자 대비 — "안 보이는 쿠폰" 을 막는 핵심 검사
  const bg = tokenColor(theme, layout.canvas.backgroundToken, layout.canvas.background);
  for (const el of layout.elements) {
    if (el.kind !== 'text' || el.visible === false) continue;
    const fg = tokenColor(theme, el.colorToken, el.color ?? theme.tokens.ink);
    const ratio = contrastRatio(fg, bg);
    if (ratio < 4.5) {
      const fixed = ensureContrast(fg, bg, 4.5);
      issues.push({
        level: theme.autoContrast ? 'warn' : 'error',
        code: 'LOW_CONTRAST',
        message: `'${el.name}' 글자가 배경과 구분되지 않습니다 (대비 ${ratio.toFixed(1)}:1). `
          + (theme.autoContrast
            ? `자동 보정으로 ${fixed.color} 로 렌더됩니다.`
            : '자동 보정이 꺼져 있어 이대로 발행됩니다. 색을 바꾸세요.'),
        elementId: el.id,
      });
    }
  }

  // 9) QR 최소 크기 — 인쇄 후 스캔이 안 되는 사고 방지
  for (const el of layout.elements) {
    if (el.kind !== 'qr' || el.visible === false) continue;
    const size = Math.min(el.width ?? 0, el.height ?? el.width ?? 0);
    if (size > 0 && size < 160) {
      issues.push({
        level: 'error', code: 'QR_TOO_SMALL',
        message: `QR 코드가 ${Math.round(size)}px 입니다. 160px 미만이면 인쇄 후 스캔되지 않을 수 있습니다.`,
        elementId: el.id,
      });
    }
  }

  // 10) QR 가림 — 위 레이어가 QR 을 덮으면 스캔이 불가능해진다
  for (const qr of layout.elements.filter((e) => e.kind === 'qr' && e.visible !== false)) {
    const qw = (qr.width ?? 0) / 2, qh = (qr.height ?? 0) / 2;
    for (const other of layout.elements) {
      if (other.id === qr.id || other.visible === false) continue;
      if (other.z <= qr.z) continue;                 // 아래 레이어는 가리지 않는다
      if (!other.width || !other.height) continue;   // 크기 없는 요소는 판단하지 않는다
      if (Math.abs(qr.x - other.x) < qw + other.width / 2 - 4
        && Math.abs(qr.y - other.y) < qh + other.height / 2 - 4) {
        issues.push({
          level: 'error', code: 'QR_COVERED',
          message: `'${other.name}' 이 QR 코드를 덮고 있습니다. QR 은 스캔되어야 하므로 가리면 안 됩니다.`,
          elementId: other.id,
        });
      }
    }
  }

  return { ok: !issues.some((i) => i.level === 'error'), issues, layout };
}

/** 레이아웃의 테마를 확정한다 — 렌더러와 에디터가 같은 값을 쓴다 */
export function resolveLayoutTheme(layout: Pick<DesignLayout, 'theme'>): ResolvedTheme {
  return resolveTheme(layout.theme);
}

/** 좌표 반올림 · z 중복 제거 · id 중복 제거 — 저장 직전 정규화 */
export function normalizeLayout(layout: DesignLayout): DesignLayout {
  const seenIds = new Set<string>();
  const elements = [...layout.elements]
    .sort((a, b) => a.z - b.z)
    .map((el, idx) => {
      let id = el.id;
      while (seenIds.has(id)) id = `${id}_${idx}`;
      seenIds.add(id);
      return {
        ...el,
        id,
        z: idx,                                   // z 를 0..n-1 로 재부여
        x: Math.round(el.x * 10) / 10,
        y: Math.round(el.y * 10) / 10,
      };
    });
  return { ...layout, elements };
}

// ────────────────────────────────────────────────── 프리셋
/**
 * 기본 프리셋 — 기존에 쓰던 6개 표시항목과 같은 배치.
 * "무엇을 만들지 모르겠다" 는 상황의 출발점이며, 여기서 자리를 옮기면 된다.
 */
// [2단계 — 02c_2단계-결정사항.md §0/§5 "캔버스 720x1280이 맞다"]
// 기존 bokju-coupon-image-service.ts 의 IMG_WIDTH/IMG_HEIGHT(37-38번 줄)와
// 치수를 맞추기 위해 기본 캔버스를 PORTRAIT_720으로 바꾼다. CANVAS_PRESETS
// 자체(세 가지 프리셋 값)는 변경하지 않는다 — defaultLayout() 의 기본 인자만
// 바꾼다. computeLayout()(bokju-coupon-visibility.ts, 기존 11항목 reflow 전용)
// 은 이 변경과 완전히 별개이며 손대지 않는다.
export function defaultLayout(canvas: { width: number; height: number } = CANVAS_PRESETS.PORTRAIT_720): DesignLayout {
  const { width: W, height: H } = canvas;
  const cx = W / 2;
  return {
    version: 1,
    // backgroundToken 을 쓰면 팔레트를 바꿀 때 배경까지 따라온다.
    // background 는 토큰이 없을 때의 폴백이다.
    canvas: { width: W, height: H, background: '#fffdfb', backgroundToken: '@surface' },
    redeemMode: 'QR',
    elements: [
      { id: 'logo', kind: 'text', name: '로고', bind: 'static', text: '신통방통',
        x: cx, y: H * 0.075, fontSize: W * 0.032, fontWeight: 700,
        color: '#7a2115', colorToken: '@primary',
        align: 'center', letterSpacing: 8, z: 0, locked: true, visible: true },
      { id: 'title', kind: 'text', name: '쿠폰명', bind: 'campaign.title',
        x: cx, y: H * 0.135, fontSize: W * 0.052, fontWeight: 700,
        color: '#1c1a18', colorToken: '@ink',
        align: 'center', maxLines: 2, z: 1, visible: true },
      { id: 'amount', kind: 'text', name: '지급 복주머니', bind: 'campaign.grantAmount',
        x: cx, y: H * 0.245, fontSize: W * 0.15, fontWeight: 800,
        color: '#a32b1c', colorToken: '@primary',
        align: 'center', z: 2, visible: true },
      { id: 'amountUnit', kind: 'text', name: '단위', bind: 'static', text: '복주머니',
        x: cx, y: H * 0.30, fontSize: W * 0.042, fontWeight: 700,
        color: '#3b3631', colorToken: '@inkMuted',
        align: 'center', z: 3, visible: true },
      { id: 'guide', kind: 'text', name: '안내 문구', bind: 'campaign.guideText',
        x: cx, y: H * 0.355, fontSize: W * 0.030,
        color: '#6a645e', colorToken: '@inkMuted',
        align: 'center', maxLines: 2, z: 4, visible: true },
      { id: 'qr', kind: 'qr', name: 'QR코드', bind: 'coupon.qr',
        x: cx, y: H * 0.585, width: W * 0.42, height: W * 0.42, z: 5, visible: true },
      { id: 'couponNo', kind: 'text', name: '쿠폰번호', bind: 'coupon.couponNo',
        x: cx, y: H * 0.92, fontSize: W * 0.034,
        color: '#2b2622', colorToken: '@ink',
        align: 'center', letterSpacing: 2, z: 6, visible: true },
      { id: 'period', kind: 'text', name: '사용기간', bind: 'campaign.validPeriod',
        x: cx, y: H * 0.955, fontSize: W * 0.024,
        color: '#6a645e', colorToken: '@inkMuted',
        align: 'center', z: 7, visible: true },
      { id: 'domain', kind: 'text', name: '도메인', bind: 'brand.domain',
        x: cx, y: H * 0.985, fontSize: W * 0.022,
        color: '#8a847c', colorToken: '@inkSubtle',
        align: 'center', letterSpacing: 1, z: 8, visible: true },
    ],
  };
}

/** 빈 캔버스 — 배경만 있고 요소는 없다. 에디터에서 직접 추가한다. */
export function blankLayout(canvas = CANVAS_PRESETS.PORTRAIT_1080): DesignLayout {
  return {
    version: 1,
    canvas: { width: canvas.width, height: canvas.height, background: '#fffdfb', backgroundToken: '@surface' },
    redeemMode: 'QR',
    elements: [
      { id: 'qr', kind: 'qr', name: 'QR코드', bind: 'coupon.qr',
        x: canvas.width / 2, y: canvas.height * 0.6,
        width: canvas.width * 0.42, height: canvas.width * 0.42, z: 0, visible: true },
      { id: 'couponNo', kind: 'text', name: '쿠폰번호', bind: 'coupon.couponNo',
        x: canvas.width / 2, y: canvas.height * 0.9,
        fontSize: canvas.width * 0.034, color: '#2b2622', colorToken: '@ink',
        align: 'center', letterSpacing: 2, z: 1, visible: true },
      { id: 'domain', kind: 'text', name: '도메인', bind: 'brand.domain',
        x: canvas.width / 2, y: canvas.height * 0.95,
        fontSize: canvas.width * 0.026, color: '#8a847c', colorToken: '@inkSubtle',
        align: 'center', letterSpacing: 1, z: 2, visible: true },
    ],
  };
}

/** "QR 대신 이미지" — QR 을 끄고 그 자리에 이미지를 놓는 프리셋 */
export function noQrLayout(canvas = CANVAS_PRESETS.PORTRAIT_1080): DesignLayout {
  const base = defaultLayout(canvas);
  return {
    ...base,
    redeemMode: 'MANUAL',
    elements: base.elements.map((el) =>
      el.kind === 'qr'
        ? { ...el, kind: 'image' as const, name: '대체 이미지', bind: 'static' as const,
            assetId: null, assetUrl: null, fit: 'contain' as const }
        : el,
    ),
  };
}

// ────────────────────────────────────────────────── 에디터 편의 함수
let seq = 0;
export function nextElementId(prefix = 'el'): string {
  seq += 1;
  return `${prefix}_${Date.now().toString(36)}${seq}`;
}

export function addElement(layout: DesignLayout, kind: ElementKind, partial: Partial<LayoutElement> = {}): DesignLayout {
  const z = layout.elements.reduce((m, e) => Math.max(m, e.z), -1) + 1;
  const el: LayoutElement = {
    id: nextElementId(kind),
    kind,
    name: partial.name ?? `${kind}_${z}`,
    bind: partial.bind ?? (kind === 'qr' ? 'coupon.qr' : 'static'),
    x: partial.x ?? layout.canvas.width / 2,
    y: partial.y ?? layout.canvas.height / 2,
    anchor: 'center',
    z,
    visible: true,
    ...partial,
  };
  return normalizeLayout({ ...layout, elements: [...layout.elements, el] });
}

export function removeElement(layout: DesignLayout, id: string): DesignLayout {
  return normalizeLayout({ ...layout, elements: layout.elements.filter((e) => e.id !== id) });
}

export function moveElement(layout: DesignLayout, id: string, x: number, y: number): DesignLayout {
  const { width: W, height: H } = layout.canvas;
  return {
    ...layout,
    elements: layout.elements.map((e) =>
      e.id === id
        ? { ...e, x: Math.min(Math.max(x, 0), W), y: Math.min(Math.max(y, 0), H) }
        : e,
    ),
  };
}

/** 레이어 순서 변경 — 위로/아래로 */
export function reorder(layout: DesignLayout, id: string, direction: 'up' | 'down'): DesignLayout {
  const sorted = [...layout.elements].sort((a, b) => a.z - b.z);
  const i = sorted.findIndex((e) => e.id === id);
  if (i < 0) return layout;
  const j = direction === 'up' ? i + 1 : i - 1;
  if (j < 0 || j >= sorted.length) return layout;
  [sorted[i], sorted[j]] = [sorted[j], sorted[i]];
  return normalizeLayout({ ...layout, elements: sorted.map((e, idx) => ({ ...e, z: idx })) });
}

export function duplicateElement(layout: DesignLayout, id: string): DesignLayout {
  const src = layout.elements.find((e) => e.id === id);
  if (!src) return layout;
  return addElement(layout, src.kind, { ...src, id: nextElementId(src.kind), name: `${src.name} 복사`, x: src.x + 24, y: src.y + 24 });
}
