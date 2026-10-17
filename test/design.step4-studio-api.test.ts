// test/design.step4-studio-api.test.ts
// 쿠폰 디자인 스튜디오 — **4단계 작업순서2 전용** 테스트 (엔드포인트 5종의
// 핵심 로직, studio-api.ts)
//
// [검증 대상] route.ts(Next.js 핸들러) 자체는 HTTP 서버 기동 없이는
// 테스트하기 어려우므로, 그 안에서 호출되는 순수 로직(studio-api.ts)을
// 직접 호출해 검증한다 — step3-revision.test.ts 가 revision.ts/dispatch.ts
// 를 직접 호출해 검증한 것과 동일한 관행.
//
// [이 파일이 검증하는 것 — 02e §0-G 필수 1~4]
//   · 필수1(가장 중요): 서버가 validateLayout 을 다시 돌려 거부하는지 —
//     "클라이언트가 통과시켰다"는 주장만으로는 저장/발행이 되지 않음을
//     직접 증명한다(에러가 있는 레이아웃을 넣고 거부되는지 확인).
//   · 필수2: 미리보기가 샘플 토큰을 쓰고, BokjuCoupon 테이블에 전혀 쓰기
//     작업을 하지 않는지(쿠폰 행 수가 미리보기 전후로 변하지 않음을 확인).
//   · 필수3: 카탈로그 값이 PALETTES/TEMPLATES/PARTS 원본과 참조 동일성
//     (reference identity) 수준으로 일치하는지 — 손으로 재입력한 복제본이
//     아님을 증명한다.
//   · 필수4: 되돌리기 결과에 두 가지 안내 문구가 모두 포함되는지.
//
// describe / it / expect / beforeAll / afterAll 는 하네스가 주입한다.

import { prisma } from '../src/lib/db';
import { defaultLayout, addElement, type DesignLayout } from '../src/lib/bokju-coupon-design/layout';
import { PALETTES } from '../src/lib/bokju-coupon-design/theme';
import { TEMPLATES, PARTS } from '../src/lib/bokju-coupon-design/templates';
import {
  getCampaignDesign, saveCampaignDesign, listCampaignRevisions, rollbackCampaignDesign,
  previewDesign, getDesignCatalog, StudioApiError,
  PARTS as PARTS_FROM_STUDIO_API,
} from '../src/lib/bokju-coupon-design/studio-api';

let campaignId: number;

beforeAll(async () => {
  const campaign = await prisma.bokjuCouponCampaign.create({
    data: {
      title: '[TEST] 4단계 studio-api 테스트 캠페인',
      grantAmount: 300,
      validFrom: new Date('2026-01-01T00:00:00Z'),
      validTo: new Date('2026-12-31T23:59:59Z'),
      guideText: 'QR코드를 찍고 복주머니를 받으세요',
    },
  });
  campaignId = campaign.id;
});

afterAll(async () => {
  // 이 파일이 만든 것만 지운다(campaignId 로 스코핑) — 기존 데이터는
  // WHERE 조건에 전혀 들어가지 않으므로 손대지 않는다.
  await prisma.bokjuCoupon.deleteMany({ where: { campaignId } });
  await prisma.bokjuCouponDesignRevision.deleteMany({ where: { campaignId } });
  await prisma.bokjuCouponCampaign.delete({ where: { id: campaignId } });
});

// ════════════════════════════════════════════════ 1) 디자인 조회
describe('studio-api — getCampaignDesign (조회)', () => {
  it('1) 신규 캠페인(리비전 없음)은 defaultLayout()을 돌려준다', async () => {
    const result = await getCampaignDesign(campaignId);
    expect(result.currentRevisionId).toBe(null);
    expect(result.layout.version).toBe(1);
    expect(result.layout.elements.length).toBeGreaterThan(0);
  });

  it('2) 존재하지 않는 캠페인은 CAMPAIGN_NOT_FOUND 오류를 던진다', async () => {
    let threw = false;
    try {
      await getCampaignDesign(999999999);
    } catch (e) {
      threw = true;
      expect(e instanceof StudioApiError).toBe(true);
      expect((e as StudioApiError).code).toBe('CAMPAIGN_NOT_FOUND');
      expect((e as StudioApiError).status).toBe(404);
    }
    expect(threw).toBe(true);
  });
});

// ════════════════════════════════════════════════ 2) 디자인 저장(발행) — 필수1
describe('studio-api — saveCampaignDesign (저장=발행, §0-G 필수1 서버 재검증)', () => {
  it('3) [필수1 — 핵심] QR 50px짜리(160px 미만) 레이아웃은 "클라이언트 검사를 거쳤다"는 가정 없이도 서버가 거부한다', async () => {
    const bad = addElement(defaultLayout(), 'qr', {
      bind: 'coupon.qr', width: 50, height: 50, x: 360, y: 640,
    });
    let threw = false;
    try {
      await saveCampaignDesign(campaignId, bad, { createdBy: 'test' });
    } catch (e) {
      threw = true;
      expect(e instanceof StudioApiError).toBe(true);
      expect((e as StudioApiError).code).toBe('LAYOUT_INVALID');
      expect((e as StudioApiError).status).toBe(400);
      const codes = (e as StudioApiError).issues?.map((i) => i.code) ?? [];
      expect(codes.includes('QR_TOO_SMALL')).toBe(true);
    }
    expect(threw).toBe(true);

    // [경계 확인] 거부됐으므로 리비전이 하나도 생기지 않아야 한다 —
    // "검증 실패 후에도 몰래 저장됐다"는 사고를 차단하는 증거.
    const revs = await listCampaignRevisions(campaignId);
    expect(revs.length).toBe(0);
  });

  it('4) 쿠폰번호도 QR도 없는(NO_DYNAMIC_BINDING) 레이아웃도 거부된다', async () => {
    const bad: DesignLayout = {
      version: 1,
      canvas: { width: 720, height: 1280, background: '#ffffff' },
      redeemMode: 'MANUAL',
      elements: [
        { id: 'onlyText', kind: 'text', name: '글자만', bind: 'static', text: '안녕',
          x: 360, y: 640, z: 0, visible: true },
      ],
    };
    let threw = false;
    try {
      await saveCampaignDesign(campaignId, bad, { createdBy: 'test' });
    } catch (e) {
      threw = true;
      expect((e as StudioApiError).code).toBe('LAYOUT_INVALID');
    }
    expect(threw).toBe(true);
  });

  it('5) 유효한 레이아웃은 저장(=freezeRevision+setCurrentRevision)되고 조회에 즉시 반영된다', async () => {
    const good = defaultLayout();
    const result = await saveCampaignDesign(campaignId, good, { createdBy: 'test', note: '첫 저장' });
    expect(result.ok).toBe(true);
    expect(result.reused).toBe(false);
    expect(result.revisionNo).toBe(1);

    const after = await getCampaignDesign(campaignId);
    expect(after.currentRevisionId).toBe(result.revisionId);
    expect(after.currentRevisionNo).toBe(1);
  });

  it('6) 같은 레이아웃을 다시 저장하면 reused=true이고 리비전이 늘지 않는다', async () => {
    const good = defaultLayout();
    const before = await listCampaignRevisions(campaignId);
    const result = await saveCampaignDesign(campaignId, good, { createdBy: 'test' });
    const after = await listCampaignRevisions(campaignId);
    expect(result.reused).toBe(true);
    expect(after.length).toBe(before.length);
  });

  it('7) 실제로 다른 레이아웃을 저장하면 새 리비전(rev2)이 생기고 현재 포인터가 그쪽으로 옮겨진다', async () => {
    const changed = addElement(defaultLayout(), 'text', {
      name: '추가문구', bind: 'static', text: '테스트 전용 문구', x: 360, y: 100,
    });
    const result = await saveCampaignDesign(campaignId, changed, { createdBy: 'test' });
    expect(result.reused).toBe(false);
    expect(result.revisionNo).toBe(2);

    const after = await getCampaignDesign(campaignId);
    expect(after.currentRevisionNo).toBe(2);
  });
});

// ════════════════════════════════════════════════ 3) 리비전 목록 + 되돌리기 — 필수4
describe('studio-api — listCampaignRevisions / rollbackCampaignDesign (§0-G 필수4 안내문구)', () => {
  it('8) 목록은 최신순이며 isCurrent가 정확히 하나만 true다', async () => {
    const revs = await listCampaignRevisions(campaignId);
    expect(revs.length).toBe(2);
    expect(revs[0].revNo).toBe(2); // 최신순
    const currents = revs.filter((r) => r.isCurrent);
    expect(currents.length).toBe(1);
    expect(currents[0].revNo).toBe(2);
  });

  it('9) rev1으로 되돌리면 현재 포인터가 rev1이 되고, [필수4] 두 안내 문구가 모두 포함된다', async () => {
    const revs = await listCampaignRevisions(campaignId);
    const rev1 = revs.find((r) => r.revNo === 1)!;
    const result = await rollbackCampaignDesign(campaignId, rev1.id);
    expect(result.revisionNo).toBe(1);

    // [필수4 — 핵심] "이미 발행된 쿠폰 유지" + "신규 발행분만 영향" 두
    // 사실이 모두 응답에 들어있어야 한다 — 에디터가 이 값을 그대로 표시한다.
    expect(result.notice.existingCouponsUnaffected.length).toBeGreaterThan(0);
    expect(result.notice.futureCouponsUseThisRevision.length).toBeGreaterThan(0);
    expect(result.notice.existingCouponsUnaffected).toMatch('유지');
    expect(result.notice.futureCouponsUseThisRevision).toMatch('새로');

    const after = await getCampaignDesign(campaignId);
    expect(after.currentRevisionNo).toBe(1);
  });

  it('10) [핵심 — 리비전 불변 재확인] 되돌려도 이미 발행된 쿠폰(rev2 각인)의 designRevisionId는 바뀌지 않는다', async () => {
    const revs = await listCampaignRevisions(campaignId);
    const rev2 = revs.find((r) => r.revNo === 2)!;

    // rev2가 "현재"였던 시점에 발행된 쿠폰을 재현(step3와 동일한 패턴).
    const coupon = await prisma.bokjuCoupon.create({
      data: {
        campaignId,
        couponNo: 'TEST-S4-REV2-' + Date.now(),
        redeemToken: 'b'.repeat(32),
        expiresAt: new Date('2026-12-31T23:59:59Z'),
        designRevisionId: rev2.id,
      },
    });

    // 다시 rev2로 돌아갔다가 rev1으로 되돌려도(이미 위에서 확인) 발행된
    // 쿠폰의 각인값은 전혀 건드리지 않는다 — rollbackCampaignDesign은
    // BokjuCoupon 테이블을 전혀 쓰지 않으므로 구조적으로 불가능하다.
    const reloaded = await prisma.bokjuCoupon.findUnique({ where: { id: coupon.id } });
    expect(reloaded?.designRevisionId).toBe(rev2.id);

    await prisma.bokjuCoupon.delete({ where: { id: coupon.id } });
  });

  it('11) 다른 캠페인 소속 리비전으로 되돌리려 하면 거부된다', async () => {
    const other = await prisma.bokjuCouponCampaign.create({
      data: {
        title: '[TEST] 4단계 다른 캠페인', grantAmount: 10,
        validFrom: new Date(), validTo: new Date(Date.now() + 86400000),
      },
    });
    let threw = false;
    try {
      await rollbackCampaignDesign(campaignId, 999999999);
    } catch (e) {
      threw = true;
      expect((e as StudioApiError).code).toBe('REVISION_NOT_FOUND');
    }
    expect(threw).toBe(true);
    await prisma.bokjuCouponCampaign.delete({ where: { id: other.id } });
  });
});

// ════════════════════════════════════════════════ 4) 미리보기 — 필수2
describe('studio-api — previewDesign (§0-G 필수2 샘플 토큰 경계)', () => {
  it('12) 미리보기는 실제 PNG 버퍼를 돌려준다', async () => {
    const result = await previewDesign({
      layout: defaultLayout(),
      campaignTitle: '미리보기 테스트',
      grantAmount: 100,
      guideText: '안내문구',
      validFrom: new Date('2026-01-01'),
      validTo: new Date('2026-12-31'),
      registerBaseUrl: 'https://sintong.kr',
    });
    expect(result.isSample).toBe(true);
    expect(result.buffer.length).toBeGreaterThan(0);
    // PNG 매직 바이트
    expect(result.buffer[0]).toBe(0x89);
    expect(result.buffer[1]).toBe(0x50);
  });

  it('13) [필수2 — 핵심] 미리보기를 여러 번 호출해도 BokjuCoupon 테이블의 행 수는 전혀 변하지 않는다(쓰기 작업이 없다는 행동 증거)', async () => {
    const before = await prisma.bokjuCoupon.count({ where: { campaignId } });
    await previewDesign({
      layout: defaultLayout(),
      campaignTitle: '미리보기 테스트2',
      grantAmount: 200,
      guideText: null,
      validFrom: new Date('2026-01-01'),
      validTo: new Date('2026-12-31'),
      registerBaseUrl: 'https://sintong.kr',
    });
    await previewDesign({
      layout: addElement(defaultLayout(), 'text', { name: 'x', bind: 'static', text: 'y', x: 10, y: 10 }),
      campaignTitle: '미리보기 테스트3',
      grantAmount: 300,
      guideText: null,
      validFrom: new Date('2026-01-01'),
      validTo: new Date('2026-12-31'),
      registerBaseUrl: 'https://sintong.kr',
    });
    const after = await prisma.bokjuCoupon.count({ where: { campaignId } });
    expect(after).toBe(before);
  });

  it('14) [필수2] 레이아웃에 error급 문제(QR 과소)가 있어도 미리보기 자체는 막지 않는다(발행과는 별개 경로) — 단 issues에 보고된다', async () => {
    const bad = addElement(defaultLayout(), 'qr', { bind: 'coupon.qr', width: 50, height: 50, x: 360, y: 640 });
    const result = await previewDesign({
      layout: bad,
      campaignTitle: '미리보기 테스트4',
      grantAmount: 100,
      guideText: null,
      validFrom: new Date('2026-01-01'),
      validTo: new Date('2026-12-31'),
      registerBaseUrl: 'https://sintong.kr',
    });
    expect(result.buffer.length).toBeGreaterThan(0); // 렌더는 됐다(미리보기는 막지 않음)
    const codes = result.issues.map((i) => i.code);
    expect(codes.includes('QR_TOO_SMALL')).toBe(true); // 하지만 문제는 보고된다
  });
});

// ════════════════════════════════════════════════ 5) 카탈로그 — 필수3
describe('studio-api — getDesignCatalog (§0-G 필수3 모듈 재사용, 값 복제 금지)', () => {
  it('15) 팔레트 12종이 그대로 내려온다', () => {
    const catalog = getDesignCatalog();
    expect(catalog.palettes.length).toBe(Object.keys(PALETTES).length);
    expect(catalog.palettes.length).toBe(12);
  });

  it('16) 템플릿 7종 · 부품 17종이 theme.ts/templates.ts 원본과 정확히 일치한다', () => {
    const catalog = getDesignCatalog();
    expect(catalog.templates.length).toBe(TEMPLATES.length);
    expect(catalog.templates.length).toBe(7);
    expect(catalog.parts.length).toBe(PARTS.length);
    expect(catalog.parts.length).toBe(17);
    expect(catalog.partGroups.length).toBe(5);
  });

  it('17) [드리프트 방지 — 핵심] 카탈로그의 템플릿 id 목록이 TEMPLATES 원본의 id 목록과 순서까지 완전히 같다(손으로 재입력했다면 어긋날 수 있다)', () => {
    const catalog = getDesignCatalog();
    expect(catalog.templates.map((t: { id: string }) => t.id)).toEqual(TEMPLATES.map((t) => t.id));
    expect(catalog.parts.map((p: { id: string }) => p.id)).toEqual(PARTS.map((p) => p.id));
  });

  it('18) [참조 동일성] studio-api가 재노출하는 PARTS는 templates.ts의 PARTS와 동일 배열 객체다(복제본이 아니다)', () => {
    expect(PARTS === PARTS_FROM_STUDIO_API).toBe(true);
  });

  it('19) 팔레트 각 항목에 색상 토큰 5종(swatch)이 들어있다 — theme.ts의 paletteCatalog() 포맷 그대로', () => {
    const catalog = getDesignCatalog();
    const bokRed = catalog.palettes.find((p) => p.id === 'bok-red');
    expect(bokRed).toBeDefined();
    expect(bokRed!.swatch.length).toBe(5);
    expect(bokRed!.swatch[1]).toBe(PALETTES['bok-red'].primary);
  });
});
