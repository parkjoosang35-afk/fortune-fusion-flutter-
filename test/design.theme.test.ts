// test/design.theme.test.ts
// 쿠폰 디자인 스튜디오 — 색 토큰 · 구성 템플릿 · 부품 · 안전장치
//
// 이 테스트가 지키는 것
//   "한 번 만들면 다시 안 고쳐도 되는 쿠폰" — 색을 바꿔도 안 보이는 글자가
//   나오지 않고, QR 이 가려지거나 너무 작아 스캔이 안 되는 일이 없다.
import {
  PALETTES, resolveTheme, paletteCatalog, tokenColor, contrastRatio,
  ensureContrast, mix, shade, luminance, pickReadable, TEXT_SCALES,
} from '../src/lib/bokju-coupon-design/theme';
import {
  validateLayout, defaultLayout, blankLayout, noQrLayout, addElement,
  moveElement, removeElement, CANVAS_PRESETS,
} from '../src/lib/bokju-coupon-design/layout';
import {
  TEMPLATES, TEMPLATE_IDS, buildTemplate, PARTS, insertPart, PART_GROUPS,
} from '../src/lib/bokju-coupon-design/templates';
import { buildSvg } from '../src/coupon/jobs/renderer';

const theme = resolveTheme({ paletteId: 'bok-red' });
const canvas = CANVAS_PRESETS.PORTRAIT_1080;

const ctx = {
  campaign: {
    title: '신통방통 복주머니 이벤트', grantAmount: 1000,
    guideText: 'QR코드를 찍고 복주머니를 받으세요',
    validFrom: new Date('2026-10-01'), validTo: new Date('2026-10-31'),
  },
  coupon: { couponNo: 'SG-2026-0001-1234', redeemToken: 'a'.repeat(32) },
  brand: { name: '신통방통', domain: 'sintong.kr' },
};

// ───────────────────────────────────────────────── 색 토큰
describe('테마 토큰 — 색을 한 곳에서 바꾼다', () => {
  it('팔레트를 바꾸면 토큰이 통째로 따라온다', () => {
    const red = resolveTheme({ paletteId: 'bok-red' });
    const night = resolveTheme({ paletteId: 'night' });
    expect(red.tokens.primary).toBe(PALETTES['bok-red'].primary);
    expect(night.tokens.primary).toBe(PALETTES['night'].primary);
    expect(night.dark).toBe(true);
    expect(red.dark).toBe(false);
  });

  it('overrides 로 팔레트를 덮어쓸 수 있다', () => {
    const t = resolveTheme({ paletteId: 'bok-red', overrides: { primary: '#123456' } });
    expect(t.tokens.primary).toBe('#123456');
    expect(t.tokens.accent).toBe(PALETTES['bok-red'].accent);
  });

  it('모르는 팔레트는 기본값으로 떨어진다 (발행이 멈추지 않게)', () => {
    expect(resolveTheme({ paletteId: 'does-not-exist' }).paletteId).toBe('bok-red');
  });

  it('토큰 참조 @이름 을 실제 색으로 바꾼다', () => {
    expect(tokenColor(theme, '@primary', '#000000')).toBe(theme.tokens.primary);
    expect(tokenColor(theme, '@inkMuted', '#000000')).toBe(theme.tokens.inkMuted);
    expect(tokenColor(theme, '#abcdef', '#000000')).toBe('#abcdef');
    expect(tokenColor(theme, undefined, '#000000')).toBe('#000000');
    expect(tokenColor(theme, '@nope', '#000000')).toBe('#000000');
  });

  it('onPrimary / onAccent 는 배경 위에서 읽히는 색을 자동으로 고른다', () => {
    for (const p of Object.values(PALETTES)) {
      const t = resolveTheme({ paletteId: p.id });
      expect(contrastRatio(t.tokens.onPrimary, t.tokens.primary), p.id).toBeGreaterThanOrEqual(4.5);
      expect(contrastRatio(t.tokens.onAccent, t.tokens.accent), p.id).toBeGreaterThanOrEqual(4.5);
    }
  });

  it('팔레트 12종이 모두 본문 대비 기준(4.5:1)을 통과한다', () => {
    for (const p of Object.values(PALETTES)) {
      const t = resolveTheme({ paletteId: p.id });
      expect(contrastRatio(t.tokens.ink, t.tokens.surface), p.id).toBeGreaterThanOrEqual(4.5);
      expect(contrastRatio(t.tokens.inkMuted, t.tokens.surface), p.id).toBeGreaterThanOrEqual(4.5);
    }
  });

  it('팔레트 목록은 에디터가 쓸 수 있는 형태로 나온다', () => {
    const cat = paletteCatalog();
    expect(cat.length).toBe(Object.keys(PALETTES).length);
    expect(cat[0].swatch.length).toBe(5);
  });

  it('textScale 3단계가 배율로 바뀐다', () => {
    expect(resolveTheme({ textScale: 'compact' }).textScale).toBe(TEXT_SCALES.compact);
    expect(resolveTheme({ textScale: 'large' }).textScale).toBe(TEXT_SCALES.large);
  });
});

// ───────────────────────────────────────────────── 대비 안전장치
describe('대비 자동 보정 — 안 보이는 쿠폰을 막는다', () => {
  it('이미 충분한 대비는 건드리지 않는다', () => {
    const r = ensureContrast('#1c1a18', '#fffdfb', 4.5);
    expect(r.adjusted).toBe(false);
    expect(r.color).toBe('#1c1a18');
  });

  it('밝은 배경에서는 글자를 어둡게 보정한다', () => {
    const r = ensureContrast('#cccccc', '#ffffff', 4.5);
    expect(r.adjusted).toBe(true);
    expect(r.ratio).toBeGreaterThanOrEqual(4.5);
    expect(luminance(r.color)).toBeLessThan(luminance('#cccccc'));
  });

  it('어두운 배경에서는 글자를 밝게 보정한다', () => {
    const r = ensureContrast('#333333', '#14181c', 4.5);
    expect(r.adjusted).toBe(true);
    expect(r.ratio).toBeGreaterThanOrEqual(4.5);
    expect(luminance(r.color)).toBeGreaterThan(luminance('#333333'));
  });

  it('배경과 같은 색도 읽히는 색으로 바꾼다 (최악의 경우)', () => {
    const r = ensureContrast('#a32b1c', '#a32b1c', 4.5);
    expect(r.adjusted).toBe(true);
    expect(r.ratio).toBeGreaterThanOrEqual(4.5);
  });

  it('pickReadable 은 더 잘 읽히는 쪽을 고른다', () => {
    expect(pickReadable('#ffffff')).toBe('#1c1a18');
    expect(pickReadable('#111111')).toBe('#ffffff');
  });

  it('mix / shade 는 색을 계산한다', () => {
    expect(mix('#000000', '#ffffff', 0.5)).toBe('#808080');
    expect(shade('#808080', -1)).toBe('#000000');
    expect(shade('#808080', 1)).toBe('#ffffff');
  });
});

// ───────────────────────────────────────────────── 구성 템플릿
describe('구성 템플릿 — 배치를 골라서 시작한다', () => {
  it('템플릿 7종이 모두 등록되어 있다', () => {
    expect(TEMPLATE_IDS).toEqual(
      ['classic', 'hero', 'card', 'split', 'ticket', 'minimal', 'badge']);
    expect(TEMPLATES.length).toBe(7);
  });

  it('모든 템플릿이 검증 오류 0으로 통과한다', () => {
    for (const id of TEMPLATE_IDS) {
      const v = validateLayout(buildTemplate(id, theme, canvas));
      const errors = v.issues.filter((i) => i.level === 'error');
      expect(errors.map((e) => `${id}:${e.message}`)).toHaveLength(0);
    }
  });

  it('모든 템플릿에 도메인과 쿠폰번호가 들어 있다', () => {
    for (const id of TEMPLATE_IDS) {
      const binds = buildTemplate(id, theme, canvas).elements.map((e) => e.bind);
      expect(binds, id).toContain('coupon.couponNo');
      expect(binds, id).toContain('brand.domain');
    }
  });

  it('모든 템플릿에 QR 이 있고 160px 이상이다', () => {
    for (const id of TEMPLATE_IDS) {
      const qr = buildTemplate(id, theme, canvas).elements.find((e) => e.kind === 'qr');
      expect(qr, id).toBeDefined();
      expect(Math.min(qr!.width ?? 0, qr!.height ?? 0), id).toBeGreaterThanOrEqual(160);
    }
  });

  it('템플릿은 테마를 함께 저장한다', () => {
    const layout = buildTemplate('classic', resolveTheme({ paletteId: 'night' }), canvas);
    expect(layout.theme?.paletteId).toBe('night');
  });

  it('팔레트를 바꾸면 배치는 그대로여도 색이 달라진다', () => {
    const red = buildTemplate('classic', resolveTheme({ paletteId: 'bok-red' }), canvas);
    const night = buildTemplate('classic', resolveTheme({ paletteId: 'night' }), canvas);
    const posOf = (l: typeof red) => l.elements.map((e) => `${e.x},${e.y}`).join('|');
    expect(posOf(red)).toBe(posOf(night));
    expect(red.theme?.paletteId).not.toBe(night.theme?.paletteId);
  });

  it('모르는 템플릿 id 는 기본 템플릿으로 떨어진다', () => {
    expect(buildTemplate('nope', theme, canvas).elements.length).toBeGreaterThan(0);
  });

  it('모든 템플릿이 실제 SVG 로 렌더된다 (도메인까지 그려진다)', async () => {
    for (const id of TEMPLATE_IDS) {
      const svg = await buildSvg(buildTemplate(id, theme, canvas), ctx);
      expect(svg, id).toContain('<svg');
      expect(svg, id).toContain('</svg>');
      expect(svg, id).toContain('sintong.kr');
      expect(svg, id).toContain('SG-2026-0001-1234');
    }
  });
});

// ───────────────────────────────────────────────── 부품 라이브러리
describe('부품 라이브러리 — 빈 캔버스에 하나씩 얹는다', () => {
  it('부품이 5개 그룹에 나뉘어 있다', () => {
    const groups = new Set(PARTS.map((p) => p.group));
    expect([...groups].sort()).toEqual([...PART_GROUPS].sort());
  });

  it('도메인 · 등록주소 부품이 있다 (요구사항)', () => {
    expect(PARTS.find((p) => p.id === 'domain')!.make(canvas, theme).bind).toBe('brand.domain');
    expect(PARTS.find((p) => p.id === 'registerUrl')!.make(canvas, theme).bind)
      .toBe('coupon.registerUrl');
  });

  it('박스 · 구분선 부품으로 배치를 직접 만들 수 있다', () => {
    const kinds = PARTS.filter((p) => p.group === '장식').map((p) => p.make(canvas, theme).kind);
    expect(kinds).toContain('box');
    expect(kinds).toContain('line');
  });

  it('모든 부품을 빈 캔버스에 얹어도 검증 오류가 없다', () => {
    for (const part of PARTS) {
      const v = validateLayout(insertPart(blankLayout(canvas), part.id, theme));
      const errors = v.issues.filter((i) => i.level === 'error');
      expect(errors.map((e) => `${part.id}:${e.message}`)).toHaveLength(0);
    }
  });

  it('부품을 얹으면 요소가 하나 늘고 z 가 겹치지 않는다', () => {
    const before = blankLayout(canvas);
    const after = insertPart(before, 'box', theme);
    expect(after.elements.length).toBe(before.elements.length + 1);
    const zs = after.elements.map((e) => e.z);
    expect(new Set(zs).size).toBe(zs.length);
  });

  it('없는 부품 id 는 레이아웃을 그대로 둔다', () => {
    const before = blankLayout(canvas);
    expect(insertPart(before, 'nope', theme)).toEqual(before);
  });
});

// ───────────────────────────────────────────────── 안전 검증
describe('안전 검증 — 발행 전에 사고를 막는다', () => {
  it('QR 이 160px 미만이면 발행을 막는다', () => {
    const layout = defaultLayout(canvas);
    const shrunk = {
      ...layout,
      elements: layout.elements.map((e) =>
        e.id === 'qr' ? { ...e, width: 120, height: 120 } : e),
    };
    const v = validateLayout(shrunk);
    expect(v.ok).toBe(false);
    expect(v.issues.some((i) => i.code === 'QR_TOO_SMALL')).toBe(true);
  });

  it('QR 을 덮는 요소가 있으면 발행을 막는다', () => {
    const layout = defaultLayout(canvas);
    const qr = layout.elements.find((e) => e.id === 'qr')!;
    const withCover = addElement(layout, 'box', {
      name: '덮는 박스', x: qr.x, y: qr.y, width: 400, height: 400, z: 99,
    });
    const v = validateLayout(withCover);
    expect(v.issues.some((i) => i.code === 'QR_COVERED')).toBe(true);
    expect(v.ok).toBe(false);
  });

  it('QR 아래 레이어의 박스는 가림으로 보지 않는다 (카드형이 통과하는 이유)', () => {
    const v = validateLayout(buildTemplate('card', theme, canvas));
    expect(v.issues.some((i) => i.code === 'QR_COVERED')).toBe(false);
  });

  it('대비가 낮으면 경고하고 보정 색을 알려준다', () => {
    const layout = defaultLayout(canvas);
    const low = {
      ...layout,
      theme: { paletteId: 'bok-red', autoContrast: true },
      elements: layout.elements.map((e) =>
        e.id === 'title' ? { ...e, colorToken: undefined, color: '#f2e9e6' } : e),
    };
    const v = validateLayout(low);
    const issue = v.issues.find((i) => i.code === 'LOW_CONTRAST');
    expect(issue).toBeDefined();
    expect(issue!.level).toBe('warn');
    expect(issue!.message).toContain('자동 보정');
  });

  it('자동 보정을 끄면 낮은 대비가 발행 차단 오류가 된다', () => {
    const layout = defaultLayout(canvas);
    const off = {
      ...layout,
      theme: { paletteId: 'bok-red', autoContrast: false },
      elements: layout.elements.map((e) =>
        e.id === 'title' ? { ...e, colorToken: undefined, color: '#f2e9e6' } : e),
    };
    const v = validateLayout(off);
    expect(v.issues.find((i) => i.code === 'LOW_CONTRAST')!.level).toBe('error');
    expect(v.ok).toBe(false);
  });

  it('안전 여백을 벗어나면 경고한다', () => {
    const v = validateLayout(moveElement(defaultLayout(canvas), 'logo', 540, 10));
    expect(v.issues.some((i) => i.code === 'SAFE_AREA')).toBe(true);
  });

  it('번호·QR 이 모두 없으면 발행을 막는다 (1만 장이 같은 이미지가 되는 사고)', () => {
    const stripped = removeElement(removeElement(blankLayout(canvas), 'qr'), 'couponNo');
    const v = validateLayout(stripped);
    expect(v.ok).toBe(false);
    expect(v.issues.some((i) => i.code === 'NO_DYNAMIC_BINDING')).toBe(true);
  });

  it('QR 을 끄고 이미지로 바꾼 프리셋은 번호가 있으면 통과한다', () => {
    expect(validateLayout(noQrLayout(canvas)).ok).toBe(true);
  });
});

// ───────────────────────────────────────────────── 편집 동작
describe('편집 동작 — 에디터가 쓰는 함수', () => {
  it('요소를 캔버스 밖으로 옮기면 안쪽으로 잘린다', () => {
    const moved = moveElement(defaultLayout(canvas), 'logo', -100, 99999);
    const el = moved.elements.find((e) => e.id === 'logo')!;
    expect(el.x).toBe(0);
    expect(el.y).toBe(canvas.height);
  });

  it('요소를 지우면 사라진다', () => {
    const after = removeElement(defaultLayout(canvas), 'logo');
    expect(after.elements.find((e) => e.id === 'logo')).toBeUndefined();
  });

  it('빈 캔버스는 배경만 있고, 번호·도메인은 기본으로 들어 있다', () => {
    const b = blankLayout(canvas);
    expect(b.canvas.backgroundToken).toBe('@surface');
    expect(b.elements.map((e) => e.id).sort()).toEqual(['couponNo', 'domain', 'qr']);
  });
});
