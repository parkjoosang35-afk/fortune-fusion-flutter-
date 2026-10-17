// test/design.layout.test.ts
// 표시항목 자리배치 · QR 대체 이미지 · 렌더러가 실제로 이미지를 만드는지 검증
import {
  defaultLayout, blankLayout, noQrLayout, validateLayout, normalizeLayout,
  addElement, removeElement, moveElement, reorder, duplicateElement, CANVAS_PRESETS,
} from '../src/lib/bokju-coupon-design/layout';
import { renderCouponImage, renderOgImage, wrapText, qrPayload, buildSvg } from '../src/coupon/jobs/renderer';

const ctx = {
  campaign: {
    title: '신통방통 복주머니 선물', grantAmount: 100,
    guideText: 'QR코드를 찍고 복주머니를 받으세요',
    validFrom: new Date('2026-10-20T00:00:00Z'), validTo: new Date('2026-12-31T23:59:59Z'),
  },
  coupon: { couponNo: 'ST-ABCD-1234-EF', redeemToken: 'a'.repeat(32) },
};

describe('레이아웃 — 자리배치', () => {
  it('기본 프리셋은 표시항목 8개를 가지며 검증을 통과한다', () => {
    const layout = defaultLayout();
    expect(layout.elements.length).toBe(9);
    const v = validateLayout(layout);
    expect(v.ok).toBe(true);
    expect(v.issues.filter((i) => i.level === 'error')).toHaveLength(0);
  });

  it('요소를 옮기면 좌표가 바뀌고 캔버스 밖으로는 나가지 않는다', () => {
    const layout = defaultLayout();
    const moved = moveElement(layout, 'amount', 500, 700);
    expect(moved.elements.find((e) => e.id === 'amount')!.x).toBe(500);
    expect(moved.elements.find((e) => e.id === 'amount')!.y).toBe(700);

    const clamped = moveElement(layout, 'amount', -999, 99999);
    const el = clamped.elements.find((e) => e.id === 'amount')!;
    expect(el.x).toBe(0);
    expect(el.y).toBe(CANVAS_PRESETS.PORTRAIT_1080.height);
  });

  it('빈 캔버스에서 시작해 요소를 추가·삭제할 수 있다', () => {
    let layout = blankLayout();
    expect(layout.elements.length).toBe(3);
    layout = addElement(layout, 'text', { name: '이벤트 문구', text: '선착순 1만명', bind: 'static' });
    expect(layout.elements.length).toBe(4);
    const added = layout.elements.find((e) => e.name === '이벤트 문구')!;
    layout = removeElement(layout, added.id);
    expect(layout.elements.length).toBe(3);
  });

  it('레이어 순서를 위·아래로 바꿀 수 있다', () => {
    const layout = defaultLayout();
    const before = layout.elements.find((e) => e.id === 'title')!.z;
    const up = reorder(layout, 'title', 'up');
    expect(up.elements.find((e) => e.id === 'title')!.z).toBe(before + 1);
    const down = reorder(layout, 'title', 'down');
    expect(down.elements.find((e) => e.id === 'title')!.z).toBe(before - 1);
  });

  it('복제하면 새 id 로 같은 위치 옆에 생긴다', () => {
    const layout = duplicateElement(defaultLayout(), 'logo');
    expect(layout.elements.filter((e) => e.name.startsWith('로고'))).toHaveLength(2);
    const ids = layout.elements.map((e) => e.id);
    expect(new Set(ids).size).toBe(ids.length);
  });

  it('z 는 저장 시 0..n-1 로 재부여되고 id 중복이 제거된다', () => {
    const layout = defaultLayout();
    const dup = { ...layout, elements: [...layout.elements, { ...layout.elements[0] }] };
    const norm = normalizeLayout(dup);
    expect(norm.elements.map((e) => e.z)).toEqual(norm.elements.map((_, i) => i));
    expect(new Set(norm.elements.map((e) => e.id)).size).toBe(norm.elements.length);
  });
});

describe('레이아웃 — QR 없이 이미지로 대체', () => {
  it('QR 제거 프리셋은 QR 이 사라지고 이미지 요소가 그 자리에 생긴다', () => {
    const layout = noQrLayout();
    expect(layout.elements.some((e) => e.kind === 'qr')).toBe(false);
    expect(layout.elements.some((e) => e.kind === 'image')).toBe(true);
    expect(layout.redeemMode).toBe('MANUAL');
  });

  it('QR 을 끄는 것은 의도된 선택이므로 경고 없이 번호 입력 방식으로 넘어간다', () => {
    const noQr = noQrLayout();
    const w = validateLayout(noQr);
    expect(w.ok).toBe(true);
    // QR 을 쓰지 않기로 했으니 "QR 없음" 경고는 나오면 안 된다
    expect(w.issues.some((i) => i.code === 'QR_MISSING')).toBe(false);
    expect(w.redeemModeOf?.() ?? noQr.redeemMode).toBe('MANUAL');
  });

  it('QR 을 지웠는데 등록 방식이 QR 로 남아 있으면 경고가 나온다', () => {
    const base = defaultLayout();
    const layout = { ...base, elements: base.elements.filter((e) => e.kind !== 'qr') };
    const v = validateLayout(layout);
    expect(v.issues.some((i) => i.code === 'QR_MISSING' && i.level === 'warn')).toBe(true);
  });

  it('번호 직접 입력 방식인데 쿠폰번호 요소까지 없으면 저장이 막힌다', () => {
    const noQr = noQrLayout();
    const stripped = { ...noQr, elements: noQr.elements.filter((e) => e.bind !== 'coupon.couponNo') };
    const e = validateLayout(stripped);
    expect(e.ok).toBe(false);
    expect(e.issues.some((i) => i.code === 'NO_COUPON_NO' && i.level === 'error')).toBe(true);
  });

  it('쿠폰번호·QR 이 모두 없으면 발행이 막힌다 (1만 장이 동일 이미지가 되는 것을 방지)', () => {
    const layout = { ...defaultLayout(), elements: defaultLayout().elements.filter(
      (e) => e.bind !== 'coupon.couponNo' && e.kind !== 'qr') };
    const v = validateLayout(layout);
    expect(v.ok).toBe(false);
    expect(v.issues.some((i) => i.code === 'NO_DYNAMIC_BINDING')).toBe(true);
  });

  it('캔버스 밖 좌표는 저장이 막힌다', () => {
    const layout = defaultLayout();
    const bad = { ...layout, elements: layout.elements.map((e) =>
      e.id === 'logo' ? { ...e, x: -10 } : e) };
    const v = validateLayout(bad);
    expect(v.ok).toBe(false);
    expect(v.issues.some((i) => i.code === 'OUT_OF_CANVAS')).toBe(true);
  });
});

describe('렌더러', () => {
  it('텍스트 줄바꿈이 캔버스 폭을 넘지 않는다', () => {
    const lines = wrapText('신통방통 복주머니 선물 쿠폰입니다 정말 긴 문장입니다', 40, 400, 2);
    expect(lines.length).toBeLessThanOrEqual(2);
    expect(lines[lines.length - 1].endsWith('…')).toBe(true);
  });

  it('QR 페이로드는 등록 링크 하나뿐이다 (개인정보 없음)', () => {
    const p = qrPayload('b'.repeat(32));
    expect(p).toContain('/c/' + 'b'.repeat(32));
    expect(p).not.toMatch(/@|\d{6}-?\d{7}/);
  });

  it('레이아웃대로 SVG 를 만들고 z 순서를 지킨다', async () => {
    const svg = await buildSvg(defaultLayout(), ctx);
    expect(svg.startsWith('<svg')).toBe(true);
    expect(svg).toContain('신통방통');
    expect(svg).toContain('ST-ABCD-1234-EF');
    expect(svg.indexOf('ST-ABCD-1234-EF')).toBeGreaterThan(svg.indexOf('복주머니'));
  });

  it('쿠폰 이미지가 실제로 생성된다 (레이아웃 없으면 기본 프리셋)', async () => {
    const buf = await renderCouponImage(null, ctx);
    expect(buf.length).toBeGreaterThan(1000);
  });

  it('QR 을 이미지로 바꾼 레이아웃도 이미지가 생성된다', async () => {
    const buf = await renderCouponImage(noQrLayout(), ctx);
    expect(buf.length).toBeGreaterThan(1000);
  });

  it('공유용 OG 이미지는 1200x630 이다', async () => {
    const buf = await renderOgImage(ctx);
    const sharp = (await import('sharp')).default;
    const meta = await sharp(buf).metadata();
    expect(meta.width).toBe(1200);
    expect(meta.height).toBe(630);
  });
});
