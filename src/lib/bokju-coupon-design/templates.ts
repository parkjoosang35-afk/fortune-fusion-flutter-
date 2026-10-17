// src/lib/bokju-coupon-design/templates.ts
// ─────────────────────────────────────────────────────────────────────
// 구성 템플릿 + 부품 라이브러리
//
// [이식 메모] 1차 전달 패키지 src/coupon/design/templates.ts 이식.
//   개발팀-지시서-2차.md §4: "좌표계만 적응. 템플릿 7 · 부품 5그룹".
//   → 본 파일은 boxOf(c) 로 캔버스 크기(width/height)를 매개변수로 받아
//     상대 비율로 좌표를 계산하는 구조라, 이미 모든 CANVAS_PRESETS
//     (PORTRAIT_1080/PORTRAIT_720/SQUARE_1080)에 그대로 적응된다.
//     별도의 좌표 변환 로직 추가 없이 원본 그대로 이식함.
//
// 문제의식
//   이전에는 "AI 배경 + 고정 배치" 라서 사실상 템플릿이 하나였다.
//   사용자는 배경만 바뀌고 구성은 손댈 수 없었다.
//
// 해결
//   · 구성 템플릿 7종 — 배치를 처음부터 고른다. (classic / hero / card / split /
//     ticket / minimal / badge)
//   · 부품 17종 · 5그룹 — 빈 캔버스에 하나씩 얹는다. 도메인·등록주소·박스·구분선 포함.
//     (기본정보5 · 등록4 · 텍스트3 · 이미지2 · 장식3 = 17. 정본은 PARTS 배열)
//   · 모든 색은 테마 토큰(@primary, @ink …)을 가리킨다.
//     그래서 팔레트를 바꾸면 구성이 그대로여도 쿠폰 전체 색이 따라온다.
// ─────────────────────────────────────────────────────────────────────
import type { DesignLayout, LayoutElement, ElementKind } from './layout';
import { CANVAS_PRESETS, addElement, nextElementId, normalizeLayout } from './layout';
import type { ResolvedTheme } from './theme';

type Canvas = { width: number; height: number };
type T = ResolvedTheme;

interface Box {
  W: number;
  H: number;
  /** 캔버스 폭 대비 비율을 픽셀로 */
  w: (r: number) => number;
  /** 캔버스 높이 대비 비율을 픽셀로 */
  h: (r: number) => number;
  cx: number;
}

function boxOf(c: Canvas): Box {
  return { W: c.width, H: c.height, w: (r) => c.width * r, h: (r) => c.height * r, cx: c.width / 2 };
}

/** 텍스트 요소 축약 생성기 */
function text(
  id: string, name: string, bind: LayoutElement['bind'],
  x: number, y: number, fs: number, colorToken: string,
  extra: Partial<LayoutElement> = {},
): LayoutElement {
  return {
    id, kind: 'text', name, bind, x, y, fontSize: fs,
    colorToken, align: 'center', z: 0, visible: true, ...extra,
  };
}

/** 테마 배경 토큰까지 반영한 빈 레이아웃 */
function base(c: Canvas, redeemMode: 'QR' | 'MANUAL'): DesignLayout {
  return {
    version: 1,
    canvas: { width: c.width, height: c.height, background: '#fffdfb', backgroundToken: '@surface' },
    theme: undefined as never,     // 호출부에서 채운다
    redeemMode,
    elements: [],
  };
}

// ══════════════════════════════════════════════════════ 구성 템플릿
export interface TemplateDef {
  id: string;
  name: string;
  note: string;
  /** 어떤 상황에 어울리는지 한 줄 */
  bestFor: string;
  build: (c: Canvas, t: T) => DesignLayout;
}

export const TEMPLATES: TemplateDef[] = [
  {
    id: 'classic',
    name: '클래식 세로',
    note: '위에서 아래로 로고·쿠폰명·수량·QR·번호',
    bestFor: '가장 무난합니다. 인쇄·모바일 모두 안전합니다.',
    build: (c) => {
      const b = boxOf(c);
      return {
        ...base(c, 'QR'),
        elements: [
          text('logo', '로고', 'static', b.cx, b.h(0.075), b.w(0.032), '@primary',
            { text: '신통방통', fontWeight: 700, letterSpacing: 8, locked: true }),
          text('title', '쿠폰명', 'campaign.title', b.cx, b.h(0.135), b.w(0.052), '@ink',
            { fontWeight: 700, maxLines: 2 }),
          text('amount', '지급 복주머니', 'campaign.grantAmount', b.cx, b.h(0.245), b.w(0.15), '@primary',
            { fontWeight: 800 }),
          text('unit', '단위', 'static', b.cx, b.h(0.300), b.w(0.042), '@inkMuted',
            { text: '복주머니', fontWeight: 700 }),
          text('guide', '안내 문구', 'campaign.guideText', b.cx, b.h(0.355), b.w(0.030), '@inkMuted',
            { maxLines: 2 }),
          { id: 'qr', kind: 'qr', name: 'QR코드', bind: 'coupon.qr', x: b.cx, y: b.h(0.585),
            width: b.w(0.42), height: b.w(0.42), z: 0, visible: true },
          text('couponNo', '쿠폰번호', 'coupon.couponNo', b.cx, b.h(0.900), b.w(0.034), '@ink',
            { letterSpacing: 2 }),
          text('period', '사용기간', 'campaign.validPeriod', b.cx, b.h(0.935), b.w(0.024), '@inkMuted'),
          text('domain', '도메인', 'brand.domain', b.cx, b.h(0.965), b.w(0.024), '@inkSubtle',
            { letterSpacing: 1 }),
        ],
      };
    },
  },
  {
    id: 'hero',
    name: '상단 히어로',
    note: '큰 숫자를 위에, QR 을 아래에',
    bestFor: '금액을 강조하고 싶은 이벤트 쿠폰.',
    build: (c) => {
      const b = boxOf(c);
      return {
        ...base(c, 'QR'),
        elements: [
          text('logo', '로고', 'static', b.cx, b.h(0.060), b.w(0.030), '@primary',
            { text: '신통방통', fontWeight: 700, letterSpacing: 8, locked: true }),
          text('amount', '지급 복주머니', 'campaign.grantAmount', b.cx, b.h(0.200), b.w(0.20), '@primary',
            { fontWeight: 800 }),
          text('unit', '단위', 'static', b.cx, b.h(0.258), b.w(0.045), '@inkMuted',
            { text: '복주머니', fontWeight: 700 }),
          text('title', '쿠폰명', 'campaign.title', b.cx, b.h(0.318), b.w(0.046), '@ink',
            { fontWeight: 700, maxLines: 2 }),
          text('guide', '안내 문구', 'campaign.guideText', b.cx, b.h(0.378), b.w(0.028), '@inkMuted',
            { maxLines: 2 }),
          { id: 'rule', kind: 'line', name: '구분선', bind: 'static', x: b.cx, y: b.h(0.430),
            width: b.w(0.60), strokeToken: '@line', strokeWidth: 2, z: 0, visible: true },
          { id: 'qr', kind: 'qr', name: 'QR코드', bind: 'coupon.qr', x: b.cx, y: b.h(0.620),
            width: b.w(0.40), height: b.w(0.40), z: 0, visible: true },
          text('couponNo', '쿠폰번호', 'coupon.couponNo', b.cx, b.h(0.880), b.w(0.034), '@ink',
            { letterSpacing: 2 }),
          text('domain', '도메인', 'brand.domain', b.cx, b.h(0.940), b.w(0.024), '@inkSubtle',
            { letterSpacing: 1 }),
        ],
      };
    },
  },
  {
    id: 'card',
    name: '카드형',
    note: '쿠폰이 카드처럼 떠 있는 구성',
    bestFor: '배경 이미지를 쓰면서 내용은 또렷하게 유지하고 싶을 때.',
    build: (c) => {
      const b = boxOf(c);
      return {
        ...base(c, 'QR'),
        elements: [
          { id: 'cardBg', kind: 'box', name: '카드 배경', bind: 'static', x: b.cx, y: b.h(0.500),
            width: b.w(0.86), height: b.h(0.84), radius: 48, fillToken: '@surface',
            strokeToken: '@line', strokeWidth: 2, z: 0, visible: true },
          text('logo', '로고', 'static', b.cx, b.h(0.115), b.w(0.030), '@primary',
            { text: '신통방통', fontWeight: 700, letterSpacing: 8, locked: true }),
          text('title', '쿠폰명', 'campaign.title', b.cx, b.h(0.170), b.w(0.046), '@ink',
            { fontWeight: 700, maxLines: 2 }),
          text('amount', '지급 복주머니', 'campaign.grantAmount', b.cx, b.h(0.265), b.w(0.14), '@primary',
            { fontWeight: 800 }),
          text('unit', '단위', 'static', b.cx, b.h(0.320), b.w(0.040), '@inkMuted',
            { text: '복주머니', fontWeight: 700 }),
          text('guide', '안내 문구', 'campaign.guideText', b.cx, b.h(0.368), b.w(0.027), '@inkMuted',
            { maxLines: 2 }),
          { id: 'qr', kind: 'qr', name: 'QR코드', bind: 'coupon.qr', x: b.cx, y: b.h(0.575),
            width: b.w(0.40), height: b.w(0.40), z: 1, visible: true },
          text('couponNo', '쿠폰번호', 'coupon.couponNo', b.cx, b.h(0.845), b.w(0.034), '@ink',
            { letterSpacing: 2, z: 1 }),
          text('domain', '도메인', 'brand.domain', b.cx, b.h(0.885), b.w(0.024), '@inkSubtle',
            { letterSpacing: 1, z: 1 }),
        ],
      };
    },
  },
  {
    id: 'split',
    name: '좌우 분할',
    note: '왼쪽에 안내, 오른쪽에 QR',
    bestFor: '가로형 쿠폰 · QR 을 크게 보여주고 싶을 때.',
    build: (c) => {
      const b = boxOf(c);
      return {
        ...base(c, 'QR'),
        elements: [
          { id: 'panel', kind: 'box', name: '좌측 패널', bind: 'static', x: b.w(0.25), y: b.h(0.5),
            width: b.w(0.5), height: b.h(1.0), radius: 0, fillToken: '@surfaceAlt', z: 0, visible: true },
          text('logo', '로고', 'static', b.w(0.28), b.h(0.115), b.w(0.026), '@primary',
            { text: '신통방통', fontWeight: 700, letterSpacing: 6, locked: true }),
          text('title', '쿠폰명', 'campaign.title', b.w(0.28), b.h(0.200), b.w(0.042), '@ink',
            { fontWeight: 700, maxLines: 3, z: 1 }),
          text('amount', '지급 복주머니', 'campaign.grantAmount', b.w(0.28), b.h(0.340), b.w(0.105), '@primary',
            { fontWeight: 800, z: 1 }),
          text('unit', '단위', 'static', b.w(0.28), b.h(0.402), b.w(0.032), '@inkMuted',
            { text: '복주머니', fontWeight: 700, z: 1 }),
          text('guide', '안내 문구', 'campaign.guideText', b.w(0.28), b.h(0.500), b.w(0.024), '@inkMuted',
            { maxLines: 4, z: 1 }),
          text('couponNo', '쿠폰번호', 'coupon.couponNo', b.w(0.28), b.h(0.620), b.w(0.028), '@ink',
            { letterSpacing: 1, z: 1 }),
          text('domain', '도메인', 'brand.domain', b.w(0.28), b.h(0.672), b.w(0.021), '@inkSubtle',
            { letterSpacing: 1, z: 1 }),
          { id: 'divider', kind: 'line', name: '세로 구분선', bind: 'static', x: b.w(0.5), y: b.h(0.5),
            width: b.h(0.90), strokeToken: '@line', strokeWidth: 2, rotation: 90, z: 1, visible: true },
          { id: 'qr', kind: 'qr', name: 'QR코드', bind: 'coupon.qr', x: b.w(0.76), y: b.h(0.470),
            width: b.w(0.34), height: b.w(0.34), z: 1, visible: true },
          text('period', '사용기간', 'campaign.validPeriod', b.w(0.76), b.h(0.720), b.w(0.020), '@inkMuted',
            { maxLines: 2, z: 1 }),
        ],
      };
    },
  },
  {
    id: 'ticket',
    name: '티켓형',
    note: '절취선이 있는 티켓 모양',
    bestFor: '종이 티켓 느낌을 주고 싶을 때. 절취선 아래를 잘라 나눠 씁니다.',
    build: (c) => {
      const b = boxOf(c);
      return {
        ...base(c, 'QR'),
        elements: [
          { id: 'stub', kind: 'box', name: '티켓 배경', bind: 'static', x: b.cx, y: b.h(0.350),
            width: b.w(0.88), height: b.h(0.62), radius: 40, fillToken: '@surface',
            strokeToken: '@line', strokeWidth: 2, z: 0, visible: true },
          text('logo', '로고', 'static', b.cx, b.h(0.100), b.w(0.030), '@primary',
            { text: '신통방통', fontWeight: 700, letterSpacing: 8, locked: true }),
          text('title', '쿠폰명', 'campaign.title', b.cx, b.h(0.160), b.w(0.046), '@ink',
            { fontWeight: 700, maxLines: 2, z: 1 }),
          text('amount', '지급 복주머니', 'campaign.grantAmount', b.cx, b.h(0.270), b.w(0.13), '@primary',
            { fontWeight: 800, z: 1 }),
          text('unit', '단위', 'static', b.cx, b.h(0.325), b.w(0.038), '@inkMuted',
            { text: '복주머니', fontWeight: 700, z: 1 }),
          text('guide', '안내 문구', 'campaign.guideText', b.cx, b.h(0.375), b.w(0.026), '@inkMuted',
            { maxLines: 2, z: 1 }),
          { id: 'perforation', kind: 'line', name: '절취선', bind: 'static', x: b.cx, y: b.h(0.660),
            width: b.w(0.88), strokeToken: '@line', strokeWidth: 3, dash: '16 12', z: 2, visible: true },
          { id: 'qr', kind: 'qr', name: 'QR코드', bind: 'coupon.qr', x: b.cx, y: b.h(0.790),
            width: b.w(0.32), height: b.w(0.32), z: 1, visible: true },
          text('couponNo', '쿠폰번호', 'coupon.couponNo', b.cx, b.h(0.925), b.w(0.032), '@ink',
            { letterSpacing: 2, z: 1 }),
          text('domain', '도메인', 'brand.domain', b.cx, b.h(0.965), b.w(0.023), '@inkSubtle',
            { letterSpacing: 1 }),
        ],
      };
    },
  },
  {
    id: 'minimal',
    name: '미니멀',
    note: '수량·QR·번호만 남긴 최소 구성',
    bestFor: '배경 이미지가 화려할 때. 글자를 얹지 않아 결과가 깔끔합니다.',
    build: (c) => {
      const b = boxOf(c);
      return {
        ...base(c, 'QR'),
        elements: [
          text('amount', '지급 복주머니', 'campaign.grantAmount', b.cx, b.h(0.300), b.w(0.18), '@primary',
            { fontWeight: 800 }),
          text('unit', '단위', 'static', b.cx, b.h(0.365), b.w(0.040), '@inkMuted',
            { text: '복주머니', fontWeight: 700 }),
          { id: 'qr', kind: 'qr', name: 'QR코드', bind: 'coupon.qr', x: b.cx, y: b.h(0.620),
            width: b.w(0.38), height: b.w(0.38), z: 0, visible: true },
          text('couponNo', '쿠폰번호', 'coupon.couponNo', b.cx, b.h(0.870), b.w(0.034), '@ink',
            { letterSpacing: 2 }),
          text('domain', '도메인', 'brand.domain', b.cx, b.h(0.925), b.w(0.024), '@inkSubtle',
            { letterSpacing: 1 }),
        ],
      };
    },
  },
  {
    id: 'badge',
    name: '배지형',
    note: '원형 배지 안에 수량을 넣은 구성',
    bestFor: '동그란 강조가 필요한 이벤트. 눈에 가장 잘 띕니다.',
    build: (c) => {
      const b = boxOf(c);
      return {
        ...base(c, 'QR'),
        elements: [
          { id: 'badgeCircle', kind: 'box', name: '배지 원', bind: 'static', x: b.cx, y: b.h(0.360),
            width: b.w(0.52), height: b.w(0.52), radius: 999, fillToken: '@surfaceAlt',
            strokeToken: '@accent', strokeWidth: 6, z: 0, visible: true },
          text('amount', '지급 복주머니', 'campaign.grantAmount', b.cx, b.h(0.352), b.w(0.13), '@primary',
            { fontWeight: 800, z: 1 }),
          text('unit', '단위', 'static', b.cx, b.h(0.420), b.w(0.032), '@inkMuted',
            { text: '복주머니', fontWeight: 700, z: 1 }),
          text('title', '쿠폰명', 'campaign.title', b.cx, b.h(0.545), b.w(0.042), '@ink',
            { fontWeight: 700, maxLines: 2 }),
          text('guide', '안내 문구', 'campaign.guideText', b.cx, b.h(0.600), b.w(0.026), '@inkMuted',
            { maxLines: 2 }),
          { id: 'qr', kind: 'qr', name: 'QR코드', bind: 'coupon.qr', x: b.cx, y: b.h(0.710),
            width: b.w(0.32), height: b.w(0.32), z: 0, visible: true },
          text('couponNo', '쿠폰번호', 'coupon.couponNo', b.cx, b.h(0.900), b.w(0.034), '@ink',
            { letterSpacing: 2 }),
          text('domain', '도메인', 'brand.domain', b.cx, b.h(0.950), b.w(0.024), '@inkSubtle',
            { letterSpacing: 1 }),
        ],
      };
    },
  },
];

export const TEMPLATE_IDS = TEMPLATES.map((t) => t.id);

/** 템플릿으로 레이아웃을 만든다 (테마 포함) */
export function buildTemplate(id: string, theme: T, canvas: Canvas = CANVAS_PRESETS.PORTRAIT_1080): DesignLayout {
  const def = TEMPLATES.find((t) => t.id === id) ?? TEMPLATES[0];
  const layout = def.build(canvas, theme);
  return normalizeLayout({ ...layout, theme: themeToLayoutTheme(theme) });
}

/** 해석된 테마 → 레이아웃에 저장할 테마 입력값 */
export function themeToLayoutTheme(t: T) {
  return {
    paletteId: t.paletteId,
    overrides: {} as Record<string, string>,
    textScale: t.textScaleId,
    fontStack: t.fontStackId,
    autoContrast: t.autoContrast,
    safeArea: t.safeArea,
  };
}

// ══════════════════════════════════════════════════════ 부품 라이브러리
export interface PartDef {
  id: string;
  name: string;
  group: '기본정보' | '등록' | '텍스트' | '이미지' | '장식';
  note: string;
  make: (c: Canvas, t: T) => Partial<LayoutElement> & { kind: ElementKind; name: string };
}

export const PARTS: PartDef[] = [
  // ── 기본정보 (5) ──────────────────────────────────────────
  { id: 'title', name: '쿠폰명', group: '기본정보', note: '캠페인 이름이 자동으로 들어갑니다',
    make: (c) => ({ kind: 'text', name: '쿠폰명', bind: 'campaign.title', text: undefined,
      x: c.width / 2, y: c.height * 0.2, fontSize: c.width * 0.05, fontWeight: 700,
      colorToken: '@ink', align: 'center', maxLines: 2 }) },
  { id: 'amount', name: '지급 복주머니', group: '기본정보', note: '숫자만 자동 치환',
    make: (c) => ({ kind: 'text', name: '지급 복주머니', bind: 'campaign.grantAmount',
      x: c.width / 2, y: c.height * 0.3, fontSize: c.width * 0.15, fontWeight: 800,
      colorToken: '@primary', align: 'center' }) },
  { id: 'unit', name: '단위', group: '기본정보', note: '"복주머니" 같은 고정 글자',
    make: (c) => ({ kind: 'text', name: '단위', bind: 'static', text: '복주머니',
      x: c.width / 2, y: c.height * 0.35, fontSize: c.width * 0.04, fontWeight: 700,
      colorToken: '@inkMuted', align: 'center' }) },
  { id: 'guide', name: '안내 문구', group: '기본정보', note: '캠페인 안내문이 들어갑니다',
    make: (c) => ({ kind: 'text', name: '안내 문구', bind: 'campaign.guideText',
      x: c.width / 2, y: c.height * 0.4, fontSize: c.width * 0.03,
      colorToken: '@inkMuted', align: 'center', maxLines: 2 }) },
  { id: 'period', name: '사용기간', group: '기본정보', note: '유효기간이 자동으로 들어갑니다',
    make: (c) => ({ kind: 'text', name: '사용기간', bind: 'campaign.validPeriod',
      x: c.width / 2, y: c.height * 0.94, fontSize: c.width * 0.024,
      colorToken: '@inkMuted', align: 'center' }) },

  // ── 등록 (4) ──────────────────────────────────────────────
  { id: 'couponNo', name: '쿠폰번호', group: '등록', note: '쿠폰마다 다른 번호 (필수)',
    make: (c) => ({ kind: 'text', name: '쿠폰번호', bind: 'coupon.couponNo',
      x: c.width / 2, y: c.height * 0.9, fontSize: c.width * 0.034,
      colorToken: '@ink', align: 'center', letterSpacing: 2 }) },
  { id: 'qr', name: 'QR코드', group: '등록', note: '스캔하면 등록 페이지로 이동',
    make: (c) => ({ kind: 'qr', name: 'QR코드', bind: 'coupon.qr',
      x: c.width / 2, y: c.height * 0.6, width: c.width * 0.4, height: c.width * 0.4 }) },
  { id: 'domain', name: '도메인', group: '등록', note: 'sintong.kr — QR 을 못 찍는 상황의 안내',
    make: (c) => ({ kind: 'text', name: '도메인', bind: 'brand.domain',
      x: c.width / 2, y: c.height * 0.95, fontSize: c.width * 0.026,
      colorToken: '@inkSubtle', align: 'center', letterSpacing: 1 }) },
  { id: 'registerUrl', name: '등록 주소', group: '등록', note: 'sintong.kr/c/토큰 — 쿠폰별 주소',
    make: (c) => ({ kind: 'text', name: '등록 주소', bind: 'coupon.registerUrl',
      x: c.width / 2, y: c.height * 0.95, fontSize: c.width * 0.022,
      colorToken: '@inkSubtle', align: 'center', maxLines: 2 }) },

  // ── 텍스트 (3) ────────────────────────────────────────────
  { id: 'heading', name: '제목', group: '텍스트', note: '큰 제목 글자',
    make: (c) => ({ kind: 'text', name: '제목', bind: 'static', text: '제목을 입력하세요',
      x: c.width / 2, y: c.height * 0.15, fontSize: c.width * 0.06, fontWeight: 700,
      colorToken: '@ink', align: 'center' }) },
  { id: 'body', name: '본문', group: '텍스트', note: '설명·유의사항',
    make: (c) => ({ kind: 'text', name: '본문', bind: 'static', text: '내용을 입력하세요',
      x: c.width / 2, y: c.height * 0.5, fontSize: c.width * 0.028,
      colorToken: '@inkMuted', align: 'center', maxLines: 4 }) },
  { id: 'logo', name: '로고 글자', group: '텍스트', note: '브랜드 이름',
    make: (c) => ({ kind: 'text', name: '로고', bind: 'static', text: '신통방통',
      x: c.width / 2, y: c.height * 0.07, fontSize: c.width * 0.03, fontWeight: 700,
      colorToken: '@primary', align: 'center', letterSpacing: 8 }) },

  // ── 이미지 (2) ────────────────────────────────────────────
  { id: 'image', name: '이미지', group: '이미지', note: '로고·사진·QR 대체 이미지',
    make: (c) => ({ kind: 'image', name: '이미지', bind: 'static',
      x: c.width / 2, y: c.height * 0.5, width: c.width * 0.4, height: c.width * 0.4,
      assetId: null, assetUrl: null, fit: 'contain' }) },
  { id: 'badgeCircle', name: '원형 배지', group: '이미지', note: '동그란 강조 판',
    make: (c) => ({ kind: 'box', name: '원형 배지', bind: 'static',
      x: c.width / 2, y: c.height * 0.35, width: c.width * 0.5, height: c.width * 0.5,
      radius: 999, fillToken: '@surfaceAlt', strokeToken: '@accent', strokeWidth: 6 }) },

  // ── 장식 (3) ──────────────────────────────────────────────
  { id: 'box', name: '박스', group: '장식', note: '글자 뒤에 깔 판 (배경·강조)',
    make: (c) => ({ kind: 'box', name: '박스', bind: 'static',
      x: c.width / 2, y: c.height * 0.5, width: c.width * 0.8, height: c.height * 0.3,
      radius: 32, fillToken: '@surfaceAlt', strokeToken: '@line', strokeWidth: 2 }) },
  { id: 'line', name: '구분선', group: '장식', note: '가로 구분선',
    make: (c) => ({ kind: 'line', name: '구분선', bind: 'static',
      x: c.width / 2, y: c.height * 0.5, width: c.width * 0.7,
      strokeToken: '@line', strokeWidth: 2 }) },
  { id: 'dash', name: '점선', group: '장식', note: '절취선 느낌의 점선',
    make: (c) => ({ kind: 'line', name: '점선', bind: 'static',
      x: c.width / 2, y: c.height * 0.5, width: c.width * 0.8,
      strokeToken: '@line', strokeWidth: 3, dash: '16 12' }) },
];

export const PART_GROUPS = ['기본정보', '등록', '텍스트', '이미지', '장식'] as const;

/**
 * 부품 하나를 레이아웃에 얹는다 — 에디터의 "부품 추가".
 *
 * ★ 얹는 자리를 자동으로 조정한다.
 *   부품 기본 위치가 QR 코드를 덮으면, QR 을 가리지 않는 자리를 찾아 옮긴다.
 *   (박스를 가운데에 얹으면 QR 이 가려 스캔이 안 되는 사고를 막는다)
 */
export function insertPart(layout: DesignLayout, partId: string, theme: T): DesignLayout {
  const def = PARTS.find((p) => p.id === partId);
  if (!def) return layout;
  const made = def.make(layout.canvas, theme);

  const w = made.width ?? 0;
  const h = made.height ?? 0;
  let x = made.x ?? layout.canvas.width / 2;
  let y = made.y ?? layout.canvas.height / 2;

  const qr = layout.elements.find((e) => e.kind === 'qr' && e.visible !== false);
  if (qr && w > 0 && h > 0) {
    const qw = (qr.width ?? 0) / 2;
    const qh = (qr.height ?? 0) / 2;
    const hits = (px: number, py: number) =>
      Math.abs(px - qr.x) < w / 2 + qw - 4 && Math.abs(py - qr.y) < h / 2 + qh - 4;
    const fits = (py: number) => py - h / 2 >= 0 && py + h / 2 <= layout.canvas.height;

    if (hits(x, y)) {
      // 위/아래 여백 → 캔버스 상·하단 순으로 피난처를 찾는다
      const candidates = [
        y - h, y + h,
        layout.canvas.height * 0.20, layout.canvas.height * 0.80,
        layout.canvas.height * 0.32, layout.canvas.height * 0.66,
        y - h * 1.6, y + h * 1.6,
      ];
      for (const cy of candidates) {
        if (fits(cy) && !hits(x, cy)) { y = Math.round(cy); break; }
      }
    }
  }

  return addElement(layout, made.kind, { ...made, id: nextElementId(made.kind), x, y });
}
