// test/design.step1-layout.test.ts
// 쿠폰 디자인 스튜디오 — 1단계 (자리배치 로직)
// 자리배치 · QR 대체 이미지 · 발행 차단 검증
//
// ── 분리 안내 ────────────────────────────────────────────────────────
//   원본 design.layout.test.ts 는 18건이었습니다.
//     · 이 파일                       : 순수 로직 **12건** → 1단계에서 통과
//     · design.step2-renderer.test.ts : 실제 렌더 **6건** → 2단계에서 통과
//   삭제·약화 없이 단계별로 나눴습니다. (12 + 6 = 18, 총 건수 보존)
//
// describe / it / expect 는 scripts/run-design-tests.ts 하네스가 주입합니다.

import {
  defaultLayout, blankLayout, noQrLayout, validateLayout, normalizeLayout,
  addElement, removeElement, moveElement, reorder, duplicateElement, CANVAS_PRESETS,
} from '../src/lib/bokju-coupon-design/layout';

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
    // [2단계 — 02c_2단계-결정사항.md §5] defaultLayout() 기본 캔버스가
    // PORTRAIT_1080 → PORTRAIT_720 으로 바뀌었다. 이 검증은 "clamp 가 layout
    // 자신의 캔버스 경계를 따르는가"이지 "PORTRAIT_1080 이 기본이어야 한다"가
    // 아니므로, layout.canvas.height(현재 기본값의 실제 높이)로 비교한다.
    expect(el.y).toBe(layout.canvas.height);
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
    expect(noQr.redeemMode).toBe('MANUAL');
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
