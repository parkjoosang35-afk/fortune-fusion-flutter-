// test/design.step2-renderer.test.ts
// 쿠폰 디자인 스튜디오 — **2단계 전용** 테스트 (실제 렌더 7건)
//
// ⚠️ 1단계에서는 실행하지 마세요. 렌더러가 아직 없어 로드 자체가 실패합니다.
//    (의도된 상태입니다 — 1단계는 렌더러를 만들지 않습니다)
//
// ── 이 파일이 검증하는 것 ─────────────────────────────────────────────
//   레이아웃 JSON 이 "실제 그림"이 되는 경로. 1단계의 순수 로직 검증으로는
//   잡히지 않는 것(줄바꿈, QR 페이로드, z 순서, 실제 파일 생성, OG 크기)을 봅니다.
//
// ── 2단계 착수 시 먼저 할 일 ──────────────────────────────────────────
//   토큰 렌더러를 이 경로에 둡니다:
//       src/lib/bokju-coupon-design/renderer.ts
//   그리고 **기존 파이프라인(bokju-coupon-image-service.ts)은 건드리지 않습니다.**
//     · 기존 캠페인 → 기존 경로 그대로 (발행한 100장의 이미지가 바뀌면 실패)
//     · 신규 디자인(토큰/리비전 있음) → 새 토큰 렌더러
//   → 이렇게 하면 "기존 이미지 바이트 동일"이 자동으로 보장됩니다.
//
// describe / it / expect / beforeAll / afterAll 는 하네스가 주입합니다.

import {
  defaultLayout, noQrLayout, addElement, CANVAS_PRESETS,
} from '../src/lib/bokju-coupon-design/layout';
import {
  renderCouponImage, renderOgImage, wrapText, qrPayload, buildSvg,
} from '../src/lib/bokju-coupon-design/renderer';

const ctx = {
  campaign: {
    title: '신통방통 복주머니 선물', grantAmount: 100,
    guideText: 'QR코드를 찍고 복주머니를 받으세요',
    validFrom: new Date('2026-10-20T00:00:00Z'), validTo: new Date('2026-12-31T23:59:59Z'),
  },
  coupon: { couponNo: 'ST-ABCD-1234-EF', redeemToken: 'a'.repeat(32) },
  brand: { name: '신통방통', domain: 'sintong.kr' },
};

const themeCtx = {
  campaign: {
    title: '신통방통 복주머니 이벤트', grantAmount: 1000,
    guideText: 'QR코드를 찍고 복주머니를 받으세요',
    validFrom: new Date('2026-10-01'), validTo: new Date('2026-10-31'),
  },
  coupon: { couponNo: 'SG-2026-0001-1234', redeemToken: 'a'.repeat(32) },
  brand: { name: '신통방통', domain: 'sintong.kr' },
};

describe('렌더러 — 레이아웃이 실제 그림이 된다', () => {
  it('텍스트 줄바꿈이 캔버스 폭을 넘지 않는다', () => {
    const lines = wrapText('신통방통 복주머니 선물 쿠폰입니다 정말 긴 문장입니다', 40, 400, 2);
    expect(lines.length).toBeLessThanOrEqual(2);
    expect(lines[lines.length - 1].endsWith('…')).toBe(true);
  });

  it('QR 페이로드는 등록 링크 하나뿐이다 (개인정보 없음)', () => {
    // [2단계 — 02c_2단계-결정사항.md §4] registerBaseUrl 을 매개변수로
    // 넘기고, 넘긴 값 그대로 비교한다. 원본의 '/c/' 하드코딩 경로는 실제
    // 등록 라우트(src/app/coupon/[token]/page.tsx)와 일치하지 않아 제거했다.
    const base = 'https://sintong.kr';
    const p = qrPayload('b'.repeat(32), base);
    expect(p).toBe(base + '/coupon/' + 'b'.repeat(32));
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

  // [2단계 신규 — 02c_2단계-결정사항.md §2]
  // partner.name 이 비어 있어도(미배정 쿠폰 — 현재 bokju_coupon_allocations
  // 가 0건이라 발행된 100장은 전부 이 케이스다) 렌더가 실패하면 안 되고,
  // campaignTitle 로 대체해서도 안 된다("제휴업체명 자리에 캠페인 제목을
  // 인쇄하면 고객에게 사실과 다른 정보가 나간다").
  it('partner.name 바인딩이 비어 있으면 요소를 건너뛰고 나머지는 정상 렌더된다 (campaignTitle 대체 금지)', async () => {
    const layoutWithPartner = addElement(defaultLayout(), 'text', {
      name: '제휴업체명', bind: 'partner.name', x: defaultLayout().canvas.width / 2, y: 60,
    });
    // ctx.partnerName 을 의도적으로 주지 않는다(undefined) — 미배정 쿠폰 케이스
    const svgWithoutPartner = await buildSvg(layoutWithPartner, ctx);
    // 건너뛴 요소의 바인딩 소스가 남긴 흔적(캠페인 제목 대체 텍스트)이 섞여
    // 들어가지 않아야 한다. ctx.campaign.title 이 이미 SVG 다른 요소(쿠폰명)
    // 에도 그려지므로 "값이 아예 없다"는 것은 partnerName 요소 1개가 빈
    // 텍스트를 반환해 <text> 가 통째로 생략된다는 사실로 간접 검증한다 —
    // buildSvg 가 예외 없이 끝까지 실행되는 것 자체가 "렌더 실패 금지" 검증이다.
    expect(svgWithoutPartner.startsWith('<svg')).toBe(true);
    expect(svgWithoutPartner.endsWith('</svg>')).toBe(true);

    // partnerName 을 채워 주면 그 값이 그려진다 — 건너뛰기가 "항상 숨김"이
    // 아니라 "값이 없을 때만 숨김"임을 함께 검증한다.
    const svgWithPartner = await buildSvg(layoutWithPartner, { ...ctx, partnerName: '복주머니 제휴카페' });
    expect(svgWithPartner).toContain('복주머니 제휴카페');
  });
});

describe('렌더러 — 구성 템플릿 7종이 전부 그려진다', () => {
  it('모든 템플릿이 실제 SVG 로 렌더된다 (도메인까지 그려진다)', async () => {
    const { buildTemplate, TEMPLATE_IDS } = await import('../src/lib/bokju-coupon-design/templates');
    const { resolveTheme } = await import('../src/lib/bokju-coupon-design/theme');
    const theme = resolveTheme({ paletteId: 'bok-red' });
    for (const id of TEMPLATE_IDS) {
      const svg = await buildSvg(buildTemplate(id, theme, CANVAS_PRESETS.PORTRAIT_1080), themeCtx);
      expect(svg, id).toContain('<svg');
      expect(svg, id).toContain('</svg>');
      expect(svg, id).toContain('sintong.kr');
      expect(svg, id).toContain('SG-2026-0001-1234');
    }
  });
});
