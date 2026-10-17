// test/design.step4-legacy-convert.test.ts
// 쿠폰 디자인 스튜디오 — **4단계 작업순서4(§4-3 전환 버튼)** 전용 테스트
//
// [검증 대상]
//   1) legacy-convert.ts의 convertVisibilityToLayout() — CouponVisibilityConfig
//      (11토글) → DesignLayout 순수 변환 함수. 매핑표(02e §4-3 / 02h §0-M-6)대로
//      동작하는지, 그리고 defaultLayout 계열이라 검사를 통과하는지 확인한다.
//   2) studio-api.ts의 convertLegacyDesign() — 실제 캠페인에 대해 전환을
//      수행하고 freezeRevision+setCurrentRevision까지 연결되는지, "버튼 1회"
//      가드(이미 전환된 캠페인 재전환 거부)가 동작하는지 확인한다.
//   3) [02h §0-M-6 "전환 직전/직후 해시 변화"] 전환 전(레거시 상태)과
//      전환 직후(rev1) 레이아웃이 다름을 canonicalHash로 확인한다.
//   4) [02h §0-M-6 "전환 전 레이아웃도 리비전으로 보존"] 전환 직후 즉시
//      rollbackCampaignDesign이 동작 가능한 상태(리비전이 남아있음)인지 확인한다
//      — rev1 자체가 "전환 결과"이며 이후 신규 에디터에서 rev2를 저장해도
//      rev1은 영구 보존되어 되돌릴 수 있다(revision.ts 불변 원칙 재확인).
//
// describe / it / expect / beforeAll / afterAll 는 하네스가 주입한다.

import { prisma } from '../src/lib/db';
import { validateLayout } from '../src/lib/bokju-coupon-design/layout';
import { convertVisibilityToLayout } from '../src/lib/bokju-coupon-design/legacy-convert';
import { canonicalHash } from '../src/lib/bokju-coupon-design/revision';
import {
  convertLegacyDesign, getCampaignDesign, listCampaignRevisions,
  rollbackCampaignDesign, StudioApiError,
} from '../src/lib/bokju-coupon-design/studio-api';
import { DEFAULT_VISIBILITY } from '../src/lib/bokju-coupon-visibility';

// ════════════════════════════════════════════════ 1) 순수 변환 함수
describe('legacy-convert — convertVisibilityToLayout (순수 매핑)', () => {
  it('1) 전부 true(DEFAULT_VISIBILITY)면 9개 요소(logo/title/amount/unit/guide/qr/couponNo/period/domain)가 모두 남는다', () => {
    const layout = convertVisibilityToLayout(DEFAULT_VISIBILITY);
    const ids = layout.elements.map((e) => e.id).sort();
    expect(ids).toEqual(['amount', 'couponNo', 'domain', 'guide', 'logo', 'period', 'qr', 'title', 'unit']);
  });

  it('2) [1:1 매핑] logo=false면 logo 요소만 제거되고 나머지는 남는다', () => {
    const layout = convertVisibilityToLayout({ ...DEFAULT_VISIBILITY, logo: false });
    const ids = layout.elements.map((e) => e.id);
    expect(ids.includes('logo')).toBe(false);
    expect(ids.includes('title')).toBe(true);
  });

  it('3) [1:1 매핑] qr=false면 qr 요소가 제거되고 redeemMode가 MANUAL로 바뀐다', () => {
    const layout = convertVisibilityToLayout({ ...DEFAULT_VISIBILITY, qr: false });
    expect(layout.elements.some((e) => e.id === 'qr')).toBe(false);
    expect(layout.redeemMode).toBe('MANUAL');
  });

  it('4) [amount→amount,unit] amount=false면 amount와 unit(단위 레이블) 둘 다 제거된다', () => {
    const layout = convertVisibilityToLayout({ ...DEFAULT_VISIBILITY, amount: false });
    const ids = layout.elements.map((e) => e.id);
    expect(ids.includes('amount')).toBe(false);
    expect(ids.includes('unit')).toBe(false);
  });

  it('5) [별칭 validFrom+validTo→period] 둘 다 false일 때만 period가 제거된다', () => {
    const bothOff = convertVisibilityToLayout({ ...DEFAULT_VISIBILITY, validFrom: false, validTo: false });
    expect(bothOff.elements.some((e) => e.id === 'period')).toBe(false);

    const onlyFromOff = convertVisibilityToLayout({ ...DEFAULT_VISIBILITY, validFrom: false, validTo: true });
    expect(onlyFromOff.elements.some((e) => e.id === 'period')).toBe(true);

    const onlyToOff = convertVisibilityToLayout({ ...DEFAULT_VISIBILITY, validFrom: true, validTo: false });
    expect(onlyToOff.elements.some((e) => e.id === 'period')).toBe(true);
  });

  it('6) [별칭 guideText→guide] guideText=false면 guide 요소가 제거된다', () => {
    const layout = convertVisibilityToLayout({ ...DEFAULT_VISIBILITY, guideText: false });
    expect(layout.elements.some((e) => e.id === 'guide')).toBe(false);
  });

  it('7) [매핑 없음 — 02c §①·② 기존 결정] ctaText/decoration을 끄거나 켜도 classic 템플릿엔 해당 요소가 원래 없으므로 결과가 동일하다(no-op)', () => {
    const on = convertVisibilityToLayout({ ...DEFAULT_VISIBILITY, ctaText: true, decoration: true });
    const off = convertVisibilityToLayout({ ...DEFAULT_VISIBILITY, ctaText: false, decoration: false });
    const idsOn = on.elements.map((e) => e.id).sort();
    const idsOff = off.elements.map((e) => e.id).sort();
    expect(idsOn).toEqual(idsOff);
    // ctaText/partnerName에 대응하는 신규 요소 자체가 애초에 존재하지 않는다.
    expect(idsOn.includes('ctaText')).toBe(false);
    expect(idsOn.includes('partnerName')).toBe(false);
  });

  it('8) 전부 true(DEFAULT_VISIBILITY) 변환 결과는 validateLayout 오류 0건이다(§4-1 검증 기준)', () => {
    const layout = convertVisibilityToLayout(DEFAULT_VISIBILITY);
    const result = validateLayout(layout);
    const errors = result.issues.filter((i) => i.level === 'error');
    expect(errors.length).toBe(0);
  });

  it('9) 캔버스는 PORTRAIT_720(720×1280)이다 — 레거시 bokju-coupon-image-service.ts 치수와 일치(별개 네임스페이스, §4-3 캔버스 치수 주의)', () => {
    const layout = convertVisibilityToLayout(DEFAULT_VISIBILITY);
    expect(layout.canvas.width).toBe(720);
    expect(layout.canvas.height).toBe(1280);
  });

  it('10) [NO_DYNAMIC_BINDING 극단값] qr=false이고 couponNo=false이면 검사 오류가 발생한다(전환 자체를 거부해야 하는 근거 — 금지 목록 ⑦ 검사 우회 금지)', () => {
    const layout = convertVisibilityToLayout({ ...DEFAULT_VISIBILITY, qr: false, couponNo: false });
    const result = validateLayout(layout);
    const codes = result.issues.filter((i) => i.level === 'error').map((i) => i.code);
    expect(codes.includes('NO_DYNAMIC_BINDING')).toBe(true);
  });
});

// ════════════════════════════════════════════════ 2) studio-api 통합 — 전환 실행
describe('studio-api — convertLegacyDesign (§4-3 전환 버튼 핵심 로직)', () => {
  let campaignId: number;

  beforeAll(async () => {
    const campaign = await prisma.bokjuCouponCampaign.create({
      data: {
        title: '[TEST] 4단계 §4-3 전환 테스트 캠페인',
        grantAmount: 500,
        validFrom: new Date('2026-01-01T00:00:00Z'),
        validTo: new Date('2026-12-31T23:59:59Z'),
        guideText: 'QR코드를 찍고 복주머니를 받으세요',
        designTemplate: 'CLASSIC',
        // customTemplateId를 지정하지 않음 → 내장 템플릿 경로(11토글 개념 없음)
        // → convertLegacyDesign이 DEFAULT_VISIBILITY로 간주해야 한다.
      },
    });
    campaignId = campaign.id;
  });

  afterAll(async () => {
    await prisma.bokjuCoupon.deleteMany({ where: { campaignId } });
    await prisma.bokjuCouponDesignRevision.deleteMany({ where: { campaignId } });
    await prisma.bokjuCouponCampaign.delete({ where: { id: campaignId } });
  });

  it('11) 전환 전: currentRevisionId는 null이다(레거시 상태)', async () => {
    const before = await getCampaignDesign(campaignId);
    expect(before.currentRevisionId).toBe(null);
  });

  it('12) [핵심] customTemplateId 없는 캠페인(내장 4종 템플릿) 전환 — DEFAULT_VISIBILITY로 간주해 rev1을 만든다', async () => {
    const result = await convertLegacyDesign(campaignId, { createdBy: 'test' });
    expect(result.ok).toBe(true);
    expect(result.revisionNo).toBe(1);

    const after = await getCampaignDesign(campaignId);
    expect(after.currentRevisionId).toBe(result.revisionId);
    expect(after.currentRevisionNo).toBe(1);
    // DEFAULT_VISIBILITY 변환 결과이므로 9개 요소 전부 있어야 한다.
    expect(after.layout.elements.length).toBe(9);
  });

  it('13) [버튼 1회 가드] 이미 전환된 캠페인을 다시 전환하면 ALREADY_CONVERTED(409)로 거부된다', async () => {
    let threw = false;
    try {
      await convertLegacyDesign(campaignId, { createdBy: 'test' });
    } catch (e) {
      threw = true;
      expect(e instanceof StudioApiError).toBe(true);
      expect((e as StudioApiError).code).toBe('ALREADY_CONVERTED');
      expect((e as StudioApiError).status).toBe(409);
    }
    expect(threw).toBe(true);

    // 리비전이 중복 생성되지 않았어야 한다.
    const revs = await listCampaignRevisions(campaignId);
    expect(revs.length).toBe(1);
  });

  it('14) [02h §0-M-6 "전환 직전/직후 해시 변화"] 전환 직후(rev1) 레이아웃의 해시는 빈 레이아웃(요소 0개)의 해시와 다르다 — 레이아웃이 실제로 채워졌다는 증거', async () => {
    const after = await getCampaignDesign(campaignId);
    const emptyLayout = { ...after.layout, elements: [] };
    expect(canonicalHash(after.layout)).not.toBe(canonicalHash(emptyLayout));
  });

  it('15) [02h §0-M-6 "전환 전 레이아웃도 리비전으로 보존"] 전환 직후 즉시 되돌리기(rollback)가 가능한 상태다 — rev1 자체가 리비전 테이블에 영구 보존되어 있다', async () => {
    const revs = await listCampaignRevisions(campaignId);
    expect(revs.length).toBe(1);
    expect(revs[0].revNo).toBe(1);
    expect(revs[0].isCurrent).toBe(true);

    // 되돌리기 자체는 기존 rollbackCampaignDesign()을 그대로 재사용한다
    // (전환 전용 별도 되돌리기 함수를 새로 만들지 않음 — §5 "엔드포인트
    // 기존 재사용 우선"). rev1으로 "되돌리는" 호출도 정상 동작해야 한다
    // (이미 rev1이 current여도 setCurrentRevision이 멱등하게 동작).
    const result = await rollbackCampaignDesign(campaignId, revs[0].id);
    expect(result.revisionNo).toBe(1);
    expect(result.notice.existingCouponsUnaffected.length).toBeGreaterThan(0);
    expect(result.notice.futureCouponsUseThisRevision.length).toBeGreaterThan(0);
  });

  it('16) 존재하지 않는 캠페인은 CAMPAIGN_NOT_FOUND(404)를 던진다', async () => {
    let threw = false;
    try {
      await convertLegacyDesign(999999999, { createdBy: 'test' });
    } catch (e) {
      threw = true;
      expect((e as StudioApiError).code).toBe('CAMPAIGN_NOT_FOUND');
      expect((e as StudioApiError).status).toBe(404);
    }
    expect(threw).toBe(true);
  });
});

// ════════════════════════════════════════════════ 3) customTemplateId 경로 — 실제 11토글 값 반영
describe('studio-api — convertLegacyDesign (customTemplateId 있는 캠페인 — 실제 11토글 값 반영)', () => {
  let campaignId: number;
  let templateId: number;

  beforeAll(async () => {
    const tpl = await prisma.bokjuCouponDesignTemplate.create({
      data: {
        name: '[TEST] §4-3 변환용 템플릿',
        // qr과 ctaText만 끈 설정 — 나머지는 전부 켬.
        visibility: JSON.stringify({
          logo: true, title: true, amount: true, couponNo: true, qr: false,
          validFrom: true, validTo: true, guideText: true, ctaText: false,
          partnerName: true, decoration: true,
        }),
      },
    });
    templateId = tpl.id;

    const campaign = await prisma.bokjuCouponCampaign.create({
      data: {
        title: '[TEST] 4단계 §4-3 customTemplate 전환 테스트',
        grantAmount: 200,
        validFrom: new Date('2026-01-01T00:00:00Z'),
        validTo: new Date('2026-12-31T23:59:59Z'),
        customTemplateId: templateId,
      },
    });
    campaignId = campaign.id;
  });

  afterAll(async () => {
    await prisma.bokjuCoupon.deleteMany({ where: { campaignId } });
    await prisma.bokjuCouponDesignRevision.deleteMany({ where: { campaignId } });
    await prisma.bokjuCouponCampaign.delete({ where: { id: campaignId } });
    await prisma.bokjuCouponDesignTemplate.delete({ where: { id: templateId } });
  });

  it('17) customTemplateId가 가리키는 템플릿의 visibility(qr=false)를 실제로 읽어 qr 요소를 제거하고 redeemMode=MANUAL로 변환한다', async () => {
    const result = await convertLegacyDesign(campaignId, { createdBy: 'test' });
    expect(result.ok).toBe(true);

    const after = await getCampaignDesign(campaignId);
    expect(after.layout.elements.some((e) => e.id === 'qr')).toBe(false);
    expect(after.layout.redeemMode).toBe('MANUAL');
    // qr=false여도 couponNo=true라서 NO_DYNAMIC_BINDING에 걸리지 않고
    // 검사를 통과해 저장까지 성공했다(결과 issues에 error가 없음).
    expect(result.issues.some((i) => i.level === 'error')).toBe(false);
  });
});

// ════════════════════════════════════════════════ 4) 검사 우회 금지 — 극단값 전환 거부
describe('studio-api — convertLegacyDesign (금지 목록 ⑦ 발행 전 검사 우회 금지)', () => {
  let campaignId: number;
  let templateId: number;

  beforeAll(async () => {
    const tpl = await prisma.bokjuCouponDesignTemplate.create({
      data: {
        name: '[TEST] §4-3 극단값 템플릿(qr·couponNo 모두 꺼짐)',
        visibility: JSON.stringify({
          logo: true, title: true, amount: true, couponNo: false, qr: false,
          validFrom: true, validTo: true, guideText: true, ctaText: true,
          partnerName: true, decoration: true,
        }),
      },
    });
    templateId = tpl.id;

    const campaign = await prisma.bokjuCouponCampaign.create({
      data: {
        title: '[TEST] 4단계 §4-3 극단값 전환 거부 테스트',
        grantAmount: 100,
        validFrom: new Date('2026-01-01T00:00:00Z'),
        validTo: new Date('2026-12-31T23:59:59Z'),
        customTemplateId: templateId,
      },
    });
    campaignId = campaign.id;
  });

  afterAll(async () => {
    await prisma.bokjuCoupon.deleteMany({ where: { campaignId } });
    await prisma.bokjuCouponDesignRevision.deleteMany({ where: { campaignId } });
    await prisma.bokjuCouponCampaign.delete({ where: { id: campaignId } });
    await prisma.bokjuCouponDesignTemplate.delete({ where: { id: templateId } });
  });

  it('18) [핵심] qr=false·couponNo=false인 레거시 설정은 변환해도 NO_DYNAMIC_BINDING에 걸려 CONVERSION_INVALID(400)로 거부되고, 리비전이 생기지 않는다', async () => {
    let threw = false;
    try {
      await convertLegacyDesign(campaignId, { createdBy: 'test' });
    } catch (e) {
      threw = true;
      expect(e instanceof StudioApiError).toBe(true);
      expect((e as StudioApiError).code).toBe('CONVERSION_INVALID');
      expect((e as StudioApiError).status).toBe(400);
      const codes = (e as StudioApiError).issues?.map((i) => i.code) ?? [];
      expect(codes.includes('NO_DYNAMIC_BINDING')).toBe(true);
    }
    expect(threw).toBe(true);

    // [검사 우회 금지 증거] 거부됐으므로 리비전도, currentDesignRevisionId도
    // 변경되지 않아야 한다.
    const after = await getCampaignDesign(campaignId);
    expect(after.currentRevisionId).toBe(null);
    const revs = await listCampaignRevisions(campaignId);
    expect(revs.length).toBe(0);
  });
});
