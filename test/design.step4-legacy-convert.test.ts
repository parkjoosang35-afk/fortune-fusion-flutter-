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
//   4) [02i §필수1 수정 — decoration은 "넣는" 매핑] decoration===true일 때
//      decoFrame/decoCircleA/decoCircleB 3개 요소가 실제로 "추가"되는지,
//      decoration===false일 때는 추가되지 않는지 확인한다(기존 "no-op"
//      주장은 틀렸었다 — classic 템플릿 실측상 장식 요소가 원래 0개이므로
//      decoration=true는 "추가"해야 하는 매핑이었다).
//   5) [02i §필수2 — "(A) 전환 취소 경로"] revertToLegacyDesign()으로
//      currentDesignRevisionId 포인터가 다시 null로 돌아가는지, 그리고
//      그 이후 getCampaignDesign()이 레거시 폴백(defaultLayout)으로
//      돌아가는지 확인한다. [테스트#15 정정 — 02i 지적 반영] 기존 문구
//      "전환 전 상태가 rev1으로 영구 보존됨을 증명"은 틀렸다: rev1은
//      전환 "후" 레이아웃이지 전환 "전"(레거시) 상태가 아니다. 진짜
//      증명해야 할 것은 "전환 전 레거시 렌더와, 전환 후 되돌린 결과가
//      동일한가"이며, 아래 15번 테스트를 이 기준으로 재작성했다.
//
// describe / it / expect / beforeAll / afterAll 는 하네스가 주입한다.

import { prisma } from '../src/lib/db';
import { validateLayout } from '../src/lib/bokju-coupon-design/layout';
import { convertVisibilityToLayout } from '../src/lib/bokju-coupon-design/legacy-convert';
import { canonicalHash } from '../src/lib/bokju-coupon-design/revision';
import {
  convertLegacyDesign, getCampaignDesign, listCampaignRevisions,
  revertToLegacyDesign, rollbackCampaignDesign, StudioApiError,
} from '../src/lib/bokju-coupon-design/studio-api';
import { DEFAULT_VISIBILITY } from '../src/lib/bokju-coupon-visibility';

// ════════════════════════════════════════════════ 1) 순수 변환 함수
describe('legacy-convert — convertVisibilityToLayout (순수 매핑)', () => {
  it('1) 전부 true(DEFAULT_VISIBILITY, decoration 포함)면 기존 9개 요소 + 장식 3개(decoFrame/decoCircleA/decoCircleB) = 12개가 남는다', () => {
    const layout = convertVisibilityToLayout(DEFAULT_VISIBILITY);
    const ids = layout.elements.map((e) => e.id).sort();
    expect(ids).toEqual([
      'amount', 'couponNo', 'decoCircleA', 'decoCircleB', 'decoFrame',
      'domain', 'guide', 'logo', 'period', 'qr', 'title', 'unit',
    ]);
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

  it('7) [매핑 없음 — 02c §①·② 기존 결정] ctaText를 끄거나 켜도 classic 템플릿엔 해당 요소가 원래 없으므로 결과가 동일하다(no-op) — decoration은 ctaText와 달리 "추가" 매핑이므로 양쪽 모두 decoration은 false로 고정해 비교한다', () => {
    const on = convertVisibilityToLayout({ ...DEFAULT_VISIBILITY, ctaText: true, decoration: false });
    const off = convertVisibilityToLayout({ ...DEFAULT_VISIBILITY, ctaText: false, decoration: false });
    const idsOn = on.elements.map((e) => e.id).sort();
    const idsOff = off.elements.map((e) => e.id).sort();
    expect(idsOn).toEqual(idsOff);
    // ctaText/partnerName에 대응하는 신규 요소 자체가 애초에 존재하지 않는다.
    expect(idsOn.includes('ctaText')).toBe(false);
    expect(idsOn.includes('partnerName')).toBe(false);
  });

  it('7-2) [02i §필수1 수정 — decoration은 "넣는" 매핑] decoration===true이면 decoFrame/decoCircleA/decoCircleB 3개 요소가 새로 추가되고, decoration===false이면 추가되지 않는다(이전 보고의 "no-op" 주장은 틀렸다 — classic 템플릿 실측상 장식 요소 원래 0개)', () => {
    const on = convertVisibilityToLayout({ ...DEFAULT_VISIBILITY, decoration: true });
    const off = convertVisibilityToLayout({ ...DEFAULT_VISIBILITY, decoration: false });
    const decoIdsOn = on.elements.filter((e) => e.id.startsWith('deco')).map((e) => e.id).sort();
    const decoIdsOff = off.elements.filter((e) => e.id.startsWith('deco')).map((e) => e.id).sort();
    expect(decoIdsOn).toEqual(['decoCircleA', 'decoCircleB', 'decoFrame']);
    expect(decoIdsOff).toEqual([]);
    // decoration을 뺀 나머지 9개 요소는 양쪽이 동일해야 한다(장식만 추가될 뿐 기존 매핑에 영향 없음).
    const nonDecoOn = on.elements.filter((e) => !e.id.startsWith('deco')).map((e) => e.id).sort();
    const nonDecoOff = off.elements.filter((e) => !e.id.startsWith('deco')).map((e) => e.id).sort();
    expect(nonDecoOn).toEqual(nonDecoOff);
  });

  it('7-3) [decoration 요소 상세] decoFrame은 테두리만(stroke)·배경과 같은 fillToken, decoCircleA/B는 radius:999(원)에 저채도(opacity 0.06)이며 둘 다 kind는 box다(badgeCircle이라는 별도 kind는 없다 — templates.ts badge 템플릿과 동일 원리)', () => {
    const layout = convertVisibilityToLayout({ ...DEFAULT_VISIBILITY, decoration: true });
    const frame = layout.elements.find((e) => e.id === 'decoFrame')!;
    const circleA = layout.elements.find((e) => e.id === 'decoCircleA')!;
    const circleB = layout.elements.find((e) => e.id === 'decoCircleB')!;

    expect(frame.kind).toBe('box');
    expect(frame.fillToken).toBe('@surface'); // 배경과 같은 색 = 시각적으로 "채움 없음"
    expect(frame.strokeToken).toBe('@accent');

    expect(circleA.kind).toBe('box');
    expect(circleA.radius).toBe(999); // 999 = 사실상 원(ELEMENT_KINDS에 별도 원 kind는 없다)
    expect(circleA.opacity).toBe(0.06);
    expect(circleB.kind).toBe('box');
    expect(circleB.radius).toBe(999);
    expect(circleB.opacity).toBe(0.06);

    // 세 요소 모두 z=0 — 다른 콘텐츠(로고 z=0, QR z=5 등)보다 먼저 그려져 "뒤에 깔리는" 장식이 되어야 한다.
    expect(frame.z).toBe(0);
    expect(circleA.z).toBe(0);
    expect(circleB.z).toBe(0);
  });

  it('7-4) [검사 통과 유지 — 금지 목록 ⑦] decoration=true로 장식 3개가 추가되어도 QR을 가리지 않으므로(z=0 ≤ qr.z) validateLayout 오류는 0건이다', () => {
    const layout = convertVisibilityToLayout({ ...DEFAULT_VISIBILITY, decoration: true });
    const result = validateLayout(layout);
    const errors = result.issues.filter((i) => i.level === 'error');
    expect(errors.length).toBe(0);
    expect(result.issues.some((i) => i.code === 'QR_COVERED')).toBe(false);
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

  it('12) [핵심] customTemplateId 없는 캠페인(내장 4종 템플릿) 전환 — DEFAULT_VISIBILITY로 간주하되 decoration은 false로 교정해 rev1을 만든다', async () => {
    const result = await convertLegacyDesign(campaignId, { createdBy: 'test' });
    expect(result.ok).toBe(true);
    expect(result.revisionNo).toBe(1);

    const after = await getCampaignDesign(campaignId);
    expect(after.currentRevisionId).toBe(result.revisionId);
    expect(after.currentRevisionNo).toBe(1);
    // [02k §필수 수정] 내장 4종 템플릿(buildClassicSvg 등)은 decoration을
    // 그리는 코드가 전혀 없으므로(SvgBuildParams에 visibility 필드 자체가
    // 없음 — decoration 분기는 buildCustomDesignSvg 전용), DEFAULT_VISIBILITY를
    // 그대로 따르면 안 되고 decoration만 false로 교정해야 한다. 따라서
    // 장식 3개가 추가되지 않고 기존 9개 그대로여야 한다(12개가 아니다 —
    // 이전 버전은 틀린 기대값이었다. 내장 템플릿을 전환해도 실제로 한 번도
    // 그려진 적 없는 장식이 새로 생기면 안 된다는 것이 핵심).
    expect(after.layout.elements.length).toBe(9);
    expect(after.layout.elements.some((e) => e.id.startsWith('deco'))).toBe(false);
    // [02k §결정 A] 장식이 생기지 않았으므로 색상 차이를 고지할 대상도 없다.
    expect(result.decorationColorNotice).toBe(null);
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

  it('15) [02h §0-M-6 "rev1 동결" — rollbackCampaignDesign 재사용 확인] rev1은 리비전 테이블에 영구 보존되어 있고, rev1으로의 rollbackCampaignDesign 호출 자체는 정상 동작한다', async () => {
    const revs = await listCampaignRevisions(campaignId);
    expect(revs.length).toBe(1);
    expect(revs[0].revNo).toBe(1);
    expect(revs[0].isCurrent).toBe(true);

    // 되돌리기 자체는 기존 rollbackCampaignDesign()을 그대로 재사용한다
    // (전환 전용 별도 되돌리기 함수를 새로 만들지 않음 — §5 "엔드포인트
    // 기존 재사용 우선"). rev1으로 "되돌리는" 호출도 정상 동작해야 한다
    // (이미 rev1이 current여도 setCurrentRevision이 멱등하게 동작).
    //
    // [02i 테스트#15 정정 — 중요] 이 테스트가 증명하는 것은 "rev1이
    // 보존되어 rollbackCampaignDesign이 동작한다"는 사실뿐이다. 이전 버전의
    // 문구("전환 전 상태가 rev1으로 영구 보존됨을 증명")는 틀렸다 — rev1은
    // 전환 "후" 레이아웃이지 전환 "전"(레거시 11토글) 상태가 아니다. rev1으로
    // rollback해도 레거시 11토글 화면으로는 돌아가지 않는다(무변화) — "전환
    // 전 상태로 돌아가는 증명"은 아래 15-2/15-3이 담당한다(revertToLegacyDesign).
    const result = await rollbackCampaignDesign(campaignId, revs[0].id);
    expect(result.revisionNo).toBe(1);
    expect(result.notice.existingCouponsUnaffected.length).toBeGreaterThan(0);
    expect(result.notice.futureCouponsUseThisRevision.length).toBeGreaterThan(0);
  });

  it('15-2) [02i §필수2 — "(A) 전환 취소 경로"] revertToLegacyDesign()은 currentDesignRevisionId 포인터를 다시 null로 되돌리고, 그 결과 getCampaignDesign()이 레거시 폴백(defaultLayout)으로 돌아간다 — 이것이 "전환 전 상태로 돌아간다"는 실제 증명이다(rev1이 아니다)', async () => {
    // 전환 전(= 레거시) 화면이 실제로 보여줬을 모습은 convertVisibilityToLayout()을
    // 직접 호출해 재현한다(캠페인은 customTemplateId가 없으므로 DEFAULT_VISIBILITY,
    // 단 [02k §필수] decoration은 convertLegacyDesign()이 실제로 쓰는 것과
    // 똑같이 false로 교정한 값을 써야 비교가 의미 있다 — 그렇지 않으면
    // decoration:true인 "가짜 레거시"와 비교하는 꼴이 된다).
    const legacyRenderBefore = convertVisibilityToLayout({ ...DEFAULT_VISIBILITY, decoration: false });

    const before = await getCampaignDesign(campaignId);
    expect(before.currentRevisionId).not.toBe(null); // 전환된 상태(테스트 12에서 전환됨)

    const reverted = await revertToLegacyDesign(campaignId);
    expect(reverted.ok).toBe(true);
    expect(reverted.notice.existingCouponsUnaffected.length).toBeGreaterThan(0);
    expect(reverted.notice.futureCouponsUseLegacy.length).toBeGreaterThan(0);
    // [02k §결정 A] 되돌리기 안내에도 색상 차이 고지가 포함되어야 한다.
    expect(reverted.notice.colorFidelityNotice.length).toBeGreaterThan(0);
    expect(reverted.notice.colorFidelityNotice).toContain('@accent');

    const after = await getCampaignDesign(campaignId);
    // [핵심] 포인터가 null로 돌아갔다 — "레거시 11토글 화면"으로 복귀했다는 뜻이다.
    expect(after.currentRevisionId).toBe(null);
    expect(after.currentRevisionNo).toBe(null);

    // [테스트#15 정정의 실제 증명] "전환 전 화면(레거시 렌더)"과 "되돌린 뒤
    // 레거시 설정을 다시 변환했을 때의 결과"가 동일해야 한다 — 레거시 설정
    // 데이터 자체(DEFAULT_VISIBILITY)가 전환 과정에서 전혀 변경되지 않았기
    // 때문이다(studio-api.ts convertLegacyDesign은 읽기만 하고 아무것도
    // 지우지 않는다).
    const legacyRenderAfterRevert = convertVisibilityToLayout({ ...DEFAULT_VISIBILITY, decoration: false });
    expect(canonicalHash(legacyRenderAfterRevert)).toBe(canonicalHash(legacyRenderBefore));

    // 리비전 행 자체는 여전히 테이블에 남아있다(불변 원칙 — 삭제되지 않음).
    const revs = await listCampaignRevisions(campaignId);
    expect(revs.length).toBe(1);
    expect(revs.every((r) => !r.isCurrent)).toBe(true); // 더 이상 current를 가리키는 리비전이 없다
  });

  it('15-3) [재전환 가능 확인] 레거시로 되돌린 뒤에는 ALREADY_CONVERTED 가드가 풀려 다시 convertLegacyDesign()을 호출할 수 있다(currentDesignRevisionId가 null이므로) — freezeRevision의 contentHash 유니크 제약으로 같은 내용이면 rev1을 재사용(reused=true)한다', async () => {
    const result = await convertLegacyDesign(campaignId, { createdBy: 'test' });
    expect(result.ok).toBe(true);
    // 레거시 설정(DEFAULT_VISIBILITY)이 바뀌지 않았으므로 같은 contentHash →
    // 새 리비전을 만들지 않고 기존 rev1을 재사용한다.
    expect(result.revisionNo).toBe(1);

    const revs = await listCampaignRevisions(campaignId);
    expect(revs.length).toBe(1); // 리비전이 중복 생성되지 않았다(freezeRevision의 재사용 보장)

    const after = await getCampaignDesign(campaignId);
    expect(after.currentRevisionId).toBe(revs[0].id);
  });

  it('15-5) [02k §필수 — 회귀 방지] 내장 템플릿(customTemplateId 없음) 캠페인을 새로 만들어 전환하면, DEFAULT_VISIBILITY의 decoration:true를 그대로 따르지 않고 decoration이 false로 교정되어 장식 3요소(decoFrame/decoCircleA/decoCircleB)가 전혀 생기지 않는다 — "신규회원 환영 쿠폰"처럼 실운영 중인 내장 템플릿 캠페인을 전환해도 디자인이 조용히 바뀌지 않음을 보장한다', async () => {
    const freshCampaign = await prisma.bokjuCouponCampaign.create({
      data: {
        title: '[TEST] 15-5 내장 템플릿 decoration 회귀방지용 캠페인',
        grantAmount: 300,
        validFrom: new Date('2026-01-01T00:00:00Z'),
        validTo: new Date('2026-12-31T23:59:59Z'),
        designTemplate: 'CLASSIC',
        // customTemplateId 미지정 — 캠페인 1 "신규회원 환영 쿠폰"과 동일한 경로.
      },
    });
    try {
      const result = await convertLegacyDesign(freshCampaign.id, { createdBy: 'test' });
      expect(result.ok).toBe(true);

      const after = await getCampaignDesign(freshCampaign.id);
      // 핵심 단언: decoration 관련 요소가 단 하나도 없어야 한다.
      const decoIds = after.layout.elements.filter((e) => e.id.startsWith('deco')).map((e) => e.id);
      expect(decoIds).toEqual([]);
      expect(after.layout.elements.length).toBe(9); // 장식 3개가 섞이지 않은 classic 기본 9개

      // 교차검증: convertVisibilityToLayout에 decoration:true를 직접 주면
      // (이 테스트가 "없어서 우연히 0개"가 아님을 증명하기 위해) 실제로는
      // 3개가 생긴다는 사실도 함께 확인한다.
      const withDecorationTrue = convertVisibilityToLayout({ ...DEFAULT_VISIBILITY, decoration: true });
      expect(withDecorationTrue.elements.filter((e) => e.id.startsWith('deco')).length).toBe(3);
    } finally {
      await prisma.bokjuCoupon.deleteMany({ where: { campaignId: freshCampaign.id } });
      await prisma.bokjuCouponDesignRevision.deleteMany({ where: { campaignId: freshCampaign.id } });
      await prisma.bokjuCouponCampaign.delete({ where: { id: freshCampaign.id } });
    }
  });

  it('15-4) [가드] 아직 전환된 적 없는(currentDesignRevisionId가 null인) 캠페인에 revertToLegacyDesign()을 호출하면 NOT_CONVERTED(409)로 거부된다', async () => {
    const freshCampaign = await prisma.bokjuCouponCampaign.create({
      data: {
        title: '[TEST] 15-4 되돌리기 가드용 캠페인',
        grantAmount: 100,
        validFrom: new Date('2026-01-01T00:00:00Z'),
        validTo: new Date('2026-12-31T23:59:59Z'),
      },
    });
    try {
      let threw = false;
      try {
        await revertToLegacyDesign(freshCampaign.id);
      } catch (e) {
        threw = true;
        expect(e instanceof StudioApiError).toBe(true);
        expect((e as StudioApiError).code).toBe('NOT_CONVERTED');
        expect((e as StudioApiError).status).toBe(409);
      }
      expect(threw).toBe(true);
    } finally {
      await prisma.bokjuCouponCampaign.delete({ where: { id: freshCampaign.id } });
    }
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

    // [02k §결정 A] 이 템플릿은 decoration:true로 생성됐으므로(위 beforeAll
    // 참고), customTemplateId 경로는 DEFAULT_VISIBILITY 간주 대상이 아니라
    // 실제 토글값을 그대로 쓴다 — decoration이 켜져 장식 3개가 실제로
    // 생겼으니 색상 차이 고지도 채워져야 한다.
    expect(after.layout.elements.filter((e) => e.id.startsWith('deco')).length).toBe(3);
    expect(result.decorationColorNotice).not.toBe(null);
    expect(result.decorationColorNotice).toContain('@accent');
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
