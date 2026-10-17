// src/lib/bokju-coupon-design/theme.ts
// ─────────────────────────────────────────────────────────────────────
// 쿠폰 테마 — 색 · 글자 · 여백을 "토큰" 으로 관리한다.
//
// [이식 메모] 1차 전달 패키지 src/coupon/design/theme.ts 를 거의 그대로 이식.
//   DB 의존 0곳 확인됨(개발팀-지시서-2차.md §4). import 경로 외 변경 없음.
//
// 왜 필요한가
//   이전 구조는 요소마다 색을 직접 박았다(#a32b1c, #ffffff …).
//   그래서 "색을 한 번 바꾸고 싶다" 가 30곳을 고치는 일이 됐고,
//   결과적으로 아무도 색을 못 바꿨다.
//   팔레트 하나를 고르면 쿠폰 전체가 따라오게 만드는 것이 이 파일의 목적이다.
//
// 안전장치 (한 번 만들면 다시 안 고치게 하는 핵심)
//   · onPrimary / onAccent — 배경 위에 올릴 글자색을 대비로 자동 선택한다.
//   · ensureContrast()    — 대비가 4.5:1 미만이면 글자색을 자동 보정한다.
//     덕분에 "글자가 안 보이는 쿠폰" 이 구조적으로 나올 수 없다.
//   · safeArea            — 인쇄·모서리 잘림을 막는 안전 여백을 토큰으로 강제한다.
// ─────────────────────────────────────────────────────────────────────
import { z } from 'zod';

export const HEX_RE = /^#[0-9a-fA-F]{6}$/;

export interface Palette {
  id: string;
  name: string;
  /** 에디터 팔레트 목록에 보이는 한 줄 설명 */
  note: string;
  dark?: boolean;
  primary: string;
  accent: string;
  surface: string;
  surfaceAlt: string;
  ink: string;
  inkMuted: string;
  inkSubtle: string;
  line: string;
}

/**
 * 큐레이션 팔레트 12종.
 * 사용자가 색을 직접 고르지 않아도 "예쁜 조합" 이 나오도록 미리 맞춰 둔 값이다.
 * (직접 고르고 싶으면 overrides 로 덮어쓴다 — 팔레트는 출발점일 뿐이다)
 */
export const PALETTES: Record<string, Palette> = {
  'bok-red': {
    id: 'bok-red', name: '복(福) 레드', note: '가장 기본. 복주머니의 붉은색과 금색',
    primary: '#A32B1C', accent: '#B98A2F', surface: '#FFFDFB', surfaceAlt: '#FDF1EC',
    ink: '#1C1A18', inkMuted: '#5A544E', inkSubtle: '#8A847C', line: '#E7E1D8',
  },
  'gold': {
    id: 'gold', name: '황금', note: '금색 중심. 프리미엄·고급 이벤트',
    primary: '#8A6A1F', accent: '#C9A227', surface: '#FFFCF2', surfaceAlt: '#FAF1DA',
    ink: '#241F14', inkMuted: '#5E5540', inkSubtle: '#8C826A', line: '#EAE0C8',
  },
  'ink': {
    id: 'ink', name: '먹(墨)', note: '검정·금색. 담백하고 단정한 인상',
    primary: '#1F2933', accent: '#8A6A1F', surface: '#FAFAF8', surfaceAlt: '#F0F1F0',
    ink: '#14181C', inkMuted: '#4C5560', inkSubtle: '#7C848E', line: '#DEE1E2',
  },
  'cheong': {
    id: 'cheong', name: '청록', note: '차분한 초록빛. 건강·여행·자연',
    primary: '#0F5B5B', accent: '#C9A227', surface: '#F7FBFA', surfaceAlt: '#E6F2EF',
    ink: '#12211F', inkMuted: '#43605B', inkSubtle: '#77938D', line: '#D5E5E1',
  },
  'plum': {
    id: 'plum', name: '자두', note: '보랏빛 자두. 뷰티·럭셔리',
    primary: '#6B2A4A', accent: '#C9A227', surface: '#FFF8FB', surfaceAlt: '#F7E8F0',
    ink: '#241722', inkMuted: '#5D4451', inkSubtle: '#93798A', line: '#EBD8E3',
  },
  'spring': {
    id: 'spring', name: '봄', note: '벚꽃 분홍. 시즌 이벤트',
    primary: '#C2185B', accent: '#F9A825', surface: '#FFF9FA', surfaceAlt: '#FDE9F0',
    ink: '#241419', inkMuted: '#5E424C', inkSubtle: '#9B7885', line: '#F2D8E0',
  },
  'summer': {
    id: 'summer', name: '여름', note: '시원한 파랑. 물놀이·휴가',
    primary: '#0B6FA4', accent: '#F9A825', surface: '#F7FBFE', surfaceAlt: '#E4F1F9',
    ink: '#101E26', inkMuted: '#3F5A6B', inkSubtle: '#7A93A3', line: '#D2E3EE',
  },
  'autumn': {
    id: 'autumn', name: '가을', note: '단풍 주황. 추석·수확',
    primary: '#9C4A12', accent: '#C9A227', surface: '#FFFBF6', surfaceAlt: '#FAEADB',
    ink: '#241A12', inkMuted: '#5F4A38', inkSubtle: '#967F6A', line: '#EDDCC9',
  },
  'winter': {
    id: 'winter', name: '겨울', note: '차가운 회청색. 연말·크리스마스',
    primary: '#33566E', accent: '#9FB6C4', surface: '#F8FAFC', surfaceAlt: '#E9EFF4',
    ink: '#141C22', inkMuted: '#455A68', inkSubtle: '#7F93A1', line: '#DAE3EA',
  },
  'grape': {
    id: 'grape', name: '포도', note: '보라. 게임·쿠폰 이벤트',
    primary: '#4A2A7A', accent: '#C9A227', surface: '#FAF8FF', surfaceAlt: '#EDE7F9',
    ink: '#1A1426', inkMuted: '#4E4463', inkSubtle: '#877C9C', line: '#DED6EE',
  },
  'forest': {
    id: 'forest', name: '숲', note: '짙은 초록. 친환경·지역화폐',
    primary: '#2F5D3A', accent: '#C9A227', surface: '#F8FBF8', surfaceAlt: '#E6F0E7',
    ink: '#14201A', inkMuted: '#425A49', inkSubtle: '#7B9283', line: '#D6E4D9',
  },
  'night': {
    id: 'night', name: '밤(다크)', note: '검은 배경 + 금색. 야간·프리미엄 이벤트',
    dark: true,
    primary: '#E5B84B', accent: '#E5B84B', surface: '#14181C', surfaceAlt: '#1E242B',
    ink: '#F5F1E8', inkMuted: '#B8B2A6', inkSubtle: '#8A857B', line: '#333B44',
  },
};

export const DEFAULT_PALETTE = 'bok-red';

/** 테마가 제공하는 색 이름 — 요소는 이 이름으로 색을 참조한다 */
export const TOKEN_NAMES = [
  'primary', 'accent', 'surface', 'surfaceAlt', 'ink', 'inkMuted', 'inkSubtle', 'line',
  'onPrimary', 'onAccent',
] as const;
export type TokenName = (typeof TOKEN_NAMES)[number];

const hex = z.string().regex(HEX_RE, '색상은 #RRGGBB 형식이어야 합니다.');

export const themeSchema = z.object({
  paletteId: z.string().default(DEFAULT_PALETTE),
  /** 팔레트 위에 덮어쓸 개별 색 — "직접 고르고 싶다" 를 위한 출구 */
  overrides: z.object({
    primary: hex.optional(), accent: hex.optional(),
    surface: hex.optional(), surfaceAlt: hex.optional(),
    ink: hex.optional(), inkMuted: hex.optional(),
    inkSubtle: hex.optional(), line: hex.optional(),
  }).default({}),
  /** 글자 크기 전체 배율 — 레이아웃을 다시 짜지 않고 분위기만 바꾼다 */
  textScale: z.enum(['compact', 'normal', 'large']).default('normal'),
  fontStack: z.enum(['sans', 'serif', 'display']).default('sans'),
  /** ★ 대비 자동 보정 — 끄면 안 보이는 쿠폰이 나올 수 있다 */
  autoContrast: z.boolean().default(true),
  /** 안전 여백(px). 이 밖으로 나간 요소는 검증에서 경고한다 */
  safeArea: z.number().min(0).max(200).default(48),
});

export type ThemeInput = z.infer<typeof themeSchema>;

export const TEXT_SCALES: Record<ThemeInput['textScale'], number> = {
  compact: 0.9, normal: 1, large: 1.12,
};

export const FONT_STACKS: Record<ThemeInput['fontStack'], string> = {
  sans: 'Noto Sans KR, Pretendard, Apple SD Gothic Neo, Malgun Gothic, sans-serif',
  serif: 'Noto Serif KR, Nanum Myeongjo, Apple SD Gothic Neo, serif',
  display: 'Noto Sans KR, Pretendard, Apple SD Gothic Neo, sans-serif',
};

export interface ResolvedTheme {
  paletteId: string;
  name: string;
  dark: boolean;
  tokens: Record<TokenName, string>;
  fontStack: string;
  textScale: number;
  /** 원래 고른 값 — 에디터에 되돌려 보여주기 위해 보관한다 */
  textScaleId: ThemeInput['textScale'];
  fontStackId: ThemeInput['fontStack'];
  safeArea: number;
  autoContrast: boolean;
}

// ─────────────────────────────────────────────────────── 색 계산 유틸
export function parseHex(h: string): { r: number; g: number; b: number } {
  const s = h.replace('#', '');
  return {
    r: parseInt(s.slice(0, 2), 16),
    g: parseInt(s.slice(2, 4), 16),
    b: parseInt(s.slice(4, 6), 16),
  };
}

export function toHex(r: number, g: number, b: number): string {
  const c = (n: number) => Math.max(0, Math.min(255, Math.round(n))).toString(16).padStart(2, '0');
  return `#${c(r)}${c(g)}${c(b)}`;
}

/** 두 색을 t(0..1) 비율로 섞는다. t=0 이면 a, t=1 이면 b */
export function mix(a: string, b: string, t: number): string {
  const A = parseHex(a), B = parseHex(b);
  return toHex(A.r + (B.r - A.r) * t, A.g + (B.g - A.g) * t, A.b + (B.b - A.b) * t);
}

/** amount<0 어둡게, >0 밝게 */
export function shade(color: string, amount: number): string {
  return amount < 0 ? mix(color, '#000000', -amount) : mix(color, '#ffffff', amount);
}

/** WCAG 상대 휘도 */
export function luminance(color: string): number {
  const { r, g, b } = parseHex(color);
  const lin = (c: number) => {
    const s = c / 255;
    return s <= 0.04045 ? s / 12.92 : Math.pow((s + 0.055) / 1.055, 2.4);
  };
  return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b);
}

/** WCAG 대비비 (1:1 ~ 21:1) */
export function contrastRatio(a: string, b: string): number {
  const la = luminance(a), lb = luminance(b);
  const [hi, lo] = la > lb ? [la, lb] : [lb, la];
  return (hi + 0.05) / (lo + 0.05);
}

/** 배경 위에 올릴 "가장 읽기 좋은" 글자색을 고른다 */
export function pickReadable(bg: string, light = '#ffffff', dark = '#1c1a18'): string {
  return contrastRatio(bg, light) >= contrastRatio(bg, dark) ? light : dark;
}

/**
 * ★ 안전장치 — 대비가 min 미만이면 글자색을 배경에서 멀어지는 방향으로 보정한다.
 * 자동 보정이 켜져 있으면 이 함수를 통과한 색은 절대 안 보이지 않는다.
 */
export function ensureContrast(
  fg: string, bg: string, min = 4.5,
): { color: string; adjusted: boolean; ratio: number } {
  const before = contrastRatio(fg, bg);
  if (before >= min) return { color: fg, adjusted: false, ratio: before };

  // 배경이 밝으면 어둡게, 어두우면 밝게 — 20단계로 충분히 도달한다
  const toward = luminance(bg) > 0.5 ? '#000000' : '#ffffff';
  let best = fg, bestRatio = before;
  for (let i = 1; i <= 20; i++) {
    const c = mix(fg, toward, i / 20);
    const r = contrastRatio(c, bg);
    if (r > bestRatio) { best = c; bestRatio = r; }
    if (r >= min) return { color: c, adjusted: true, ratio: r };
  }
  return { color: best, adjusted: true, ratio: bestRatio };
}

// ─────────────────────────────────────────────────────── 테마 확정
/**
 * 팔레트 + 오버라이드 + 파생 토큰(onPrimary/onAccent)을 하나로 확정한다.
 * 렌더러와 에디터가 같은 함수를 쓰므로 화면과 결과물이 어긋나지 않는다.
 */
export function resolveTheme(input?: unknown): ResolvedTheme {
  const t: ThemeInput = themeSchema.parse(input ?? {});
  const p = PALETTES[t.paletteId] ?? PALETTES[DEFAULT_PALETTE];
  const o = t.overrides;

  const base = {
    primary: o.primary ?? p.primary,
    accent: o.accent ?? p.accent,
    surface: o.surface ?? p.surface,
    surfaceAlt: o.surfaceAlt ?? p.surfaceAlt,
    ink: o.ink ?? p.ink,
    inkMuted: o.inkMuted ?? p.inkMuted,
    inkSubtle: o.inkSubtle ?? p.inkSubtle,
    line: o.line ?? p.line,
  };

  return {
    paletteId: p.id,
    name: p.name,
    dark: luminance(base.surface) < 0.5,
    tokens: {
      ...base,
      // 배경색 위에 올릴 글자색은 항상 대비로 뽑는다 — 손으로 고르지 않는다
      onPrimary: pickReadable(base.primary),
      onAccent: pickReadable(base.accent),
    },
    fontStack: FONT_STACKS[t.fontStack],
    textScale: TEXT_SCALES[t.textScale],
    textScaleId: t.textScale,
    fontStackId: t.fontStack,
    safeArea: t.safeArea,
    autoContrast: t.autoContrast,
  };
}

/** 에디터 팔레트 목록 — 이름 · 대표색 · 미리보기용 색 5개 */
export function paletteCatalog() {
  return Object.values(PALETTES).map((p) => ({
    id: p.id, name: p.name, note: p.note, dark: !!p.dark,
    swatch: [p.surface, p.primary, p.accent, p.ink, p.line],
  }));
}

/**
 * 토큰 이름을 실제 색으로 바꾼다.
 * '@primary' → '#A32B1C' 처럼 @ 접두사를 쓴다. 팔레트를 바꾸면 이 값이 따라 바뀐다.
 */
export function tokenColor(theme: ResolvedTheme, ref: string | undefined, fallback: string): string {
  if (!ref) return fallback;
  if (!ref.startsWith('@')) return HEX_RE.test(ref) ? ref : fallback;
  const name = ref.slice(1) as TokenName;
  return theme.tokens[name] ?? fallback;
}
