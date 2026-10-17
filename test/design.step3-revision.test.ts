// test/design.step3-revision.test.ts
// 쿠폰 디자인 스튜디오 — **3단계 전용** 테스트 (디자인 리비전 고정 10건)
//
// [02d_3단계-리비전고정.md §6] 이 파일이 검증하는 것:
//   "디자인을 몇 번을 고쳐도 이미 발행된 쿠폰은 그때 모습 그대로다" 라는
//   3단계의 핵심 약속이 실제로 지켜지는지 — 특히 4번 케이스(rev1 발행 →
//   rev2 동결 → rev1 쿠폰 조회 시 여전히 rev1 레이아웃)가 이 파일 전체의
//   존재 이유다.
//
// [DB 를 실제로 쓰는 첫 테스트 파일] step1/step2 는 순수 함수 테스트라
// DB 가 필요 없었다. 이 파일은 BokjuCouponCampaign/BokjuCoupon/
// BokjuCouponDesignRevision 에 실제로 읽고 쓴다 — dev.db 를 그대로 쓰되,
// 이 파일이 만든 캠페인/쿠폰/리비전만 afterAll 에서 정리한다(기존 212행/
// 3행에는 전혀 손대지 않는다 — WHERE 조건에 테스트 전용 campaignId 만 쓴다).
//
// describe / it / expect / beforeAll / afterAll 는 하네스가 주입한다.

import { prisma } from '../src/lib/db';
import { defaultLayout, addElement, type DesignLayout } from '../src/lib/bokju-coupon-design/layout';
import {
  canonicalHash, freezeRevision, setCurrentRevision, resolveLayoutForCoupon, listRevisions,
} from '../src/lib/bokju-coupon-design/revision';
import { dispatchCouponRender } from '../src/lib/bokju-coupon-design/dispatch';
import { createHash } from 'node:crypto';

// ── 테스트 전용 캠페인/쿠폰 — afterAll 에서 전부 정리한다 ────────────────
let campaignId: number;
let couponRev1Id: number; // rev1 이 각인된 쿠폰
let couponRev2Id: number; // rev2 가 각인된 쿠폰
let couponLegacyId: number; // designRevisionId = null (레거시) 쿠폰
let rev1Id: number;
let rev2Id: number;

const layoutRev1: DesignLayout = defaultLayout();
// rev2 = rev1 과 "실제로 다른" 레이아웃(텍스트 요소 1개 추가) — 5번 케이스가
// "바이트가 다르다"를 검증하려면 디자인이 실제로 달라야 한다.
const layoutRev2: DesignLayout = addElement(defaultLayout(), 'text', {
  name: '테스트용 추가문구', bind: 'static', text: '리비전2 전용 문구',
  x: defaultLayout().canvas.width / 2, y: 100,
});

beforeAll(async () => {
  const campaign = await prisma.bokjuCouponCampaign.create({
    data: {
      title: '[TEST] 3단계 리비전 테스트 캠페인',
      grantAmount: 500,
      validFrom: new Date('2026-01-01T00:00:00Z'),
      validTo: new Date('2026-12-31T23:59:59Z'),
      guideText: 'QR코드를 찍고 복주머니를 받으세요',
    },
  });
  campaignId = campaign.id;

  // rev1 동결 + 캠페인 포인터를 rev1 으로
  const r1 = await freezeRevision(campaignId, layoutRev1, { note: '최초 디자인', createdBy: 'test-harness' });
  rev1Id = r1.id;
  await setCurrentRevision(campaignId, rev1Id);

  // [핵심 시나리오 준비] rev1 이 "현재"일 때 쿠폰 1장을 발행(각인) —
  // issueCoupons() 전체를 타지 않고, 그 함수가 하는 핵심 동작(발행 시점
  // 각인)만 직접 재현한다 — 이 테스트는 issueCoupons() 자체가 아니라
  // revision.ts 의 계약(발행 시점 각인 → 렌더 시점 불변 조회)을 검증한다.
  const couponRev1 = await prisma.bokjuCoupon.create({
    data: {
      campaignId,
      couponNo: 'TEST-REV1-' + Date.now(),
      redeemToken: createHash('sha256').update('rev1-' + Date.now()).digest('hex').slice(0, 32),
      expiresAt: campaign.validTo,
      designRevisionId: campaignId ? rev1Id : null, // 발행 시점의 currentDesignRevisionId(=rev1)
    },
  });
  couponRev1Id = couponRev1.id;

  const couponLegacy = await prisma.bokjuCoupon.create({
    data: {
      campaignId,
      couponNo: 'TEST-LEGACY-' + Date.now(),
      redeemToken: createHash('sha256').update('legacy-' + Date.now()).digest('hex').slice(0, 32),
      expiresAt: campaign.validTo,
      designRevisionId: null, // 레거시 — 기존 100행과 동일한 상태
    },
  });
  couponLegacyId = couponLegacy.id;

  // rev2 동결(캠페인 포인터를 rev2 로 바꾼 "이후" 발행될 쿠폰을 위해 준비) —
  // 주의: rev1 쿠폰은 이미 위에서 발행(각인)됐으므로, 이 시점 이후 rev2 로
  // 포인터를 옮겨도 couponRev1Id 의 designRevisionId 는 바뀌지 않는다
  // (금지 목록 #4 — 렌더 시점 조회 금지의 실제 보장 대상).
  const r2 = await freezeRevision(campaignId, layoutRev2, { note: '문구 추가', createdBy: 'test-harness' });
  rev2Id = r2.id;
  await setCurrentRevision(campaignId, rev2Id);

  const couponRev2 = await prisma.bokjuCoupon.create({
    data: {
      campaignId,
      couponNo: 'TEST-REV2-' + Date.now(),
      redeemToken: createHash('sha256').update('rev2-' + Date.now()).digest('hex').slice(0, 32),
      expiresAt: campaign.validTo,
      designRevisionId: rev2Id, // rev2 가 "현재"일 때 발행된 쿠폰
    },
  });
  couponRev2Id = couponRev2.id;
});

afterAll(async () => {
  // 이 파일이 만든 것만 지운다(campaignId 로 스코핑) — 기존 212행/3행은
  // WHERE 조건에 전혀 들어가지 않으므로 손대지 않는다.
  await prisma.bokjuCoupon.deleteMany({ where: { campaignId } });
  await prisma.bokjuCouponDesignRevision.deleteMany({ where: { campaignId } });
  await prisma.bokjuCouponCampaign.delete({ where: { id: campaignId } });
});

describe('리비전 고정 — canonicalHash', () => {
  it('1) 키 순서가 달라도 같은 디자인이면 같은 해시가 나온다', () => {
    const a = { canvas: { width: 100, height: 200 }, elements: [{ id: 'x', kind: 'text' }] } as unknown as DesignLayout;
    const b = { elements: [{ kind: 'text', id: 'x' }], canvas: { height: 200, width: 100 } } as unknown as DesignLayout;
    expect(canonicalHash(a)).toBe(canonicalHash(b));
  });
});

describe('리비전 고정 — freezeRevision (동결·재사용·불변)', () => {
  it('2) 같은 디자인을 2번 동결하면 reused=true 이고 리비전 행이 늘지 않는다', async () => {
    const before = await listRevisions(campaignId);
    const result = await freezeRevision(campaignId, layoutRev1, { note: '중복 동결 시도' });
    const after = await listRevisions(campaignId);
    expect(result.reused).toBe(true);
    expect(result.id).toBe(rev1Id);
    expect(after.length).toBe(before.length);
  });

  it('3) 디자인을 바꿔 재동결하면 새 revNo 가 생기고, 이전 리비전은 그대로 남는다', async () => {
    const layoutRev3 = addElement(defaultLayout(), 'text', {
      name: '3번째 변경', bind: 'static', text: '세 번째 디자인',
      x: 50, y: 50,
    });
    const r3 = await freezeRevision(campaignId, layoutRev3, { note: '3번째 변경' });
    expect(r3.reused).toBe(false);
    expect(r3.revNo).toBeGreaterThan(2);

    // 이전 리비전(rev1)이 그대로 조회되는지 — UPDATE 되지 않았음을 확인
    const rev1Row = await prisma.bokjuCouponDesignRevision.findUnique({ where: { id: rev1Id } });
    expect(rev1Row?.revNo).toBe(1);
    expect(JSON.parse(rev1Row!.layout)).toEqual(layoutRev1);

    // 정리 — 이 케이스 전용으로 만든 r3 는 다른 테스트에 영향 주지 않도록
    // 캠페인의 currentDesignRevisionId 를 rev2 로 되돌려 둔다(9번 케이스와
    // 순서가 꼬이지 않게 하기 위함).
    await setCurrentRevision(campaignId, rev2Id);
  });

  it('[불변성] freezeRevision 은 export 되어 있지만, 리비전 행을 고치는 함수(update/delete)는 모듈에 존재하지 않는다', async () => {
    const mod = await import('../src/lib/bokju-coupon-design/revision');
    expect((mod as Record<string, unknown>).updateRevision).toBeUndefined();
    expect((mod as Record<string, unknown>).deleteRevision).toBeUndefined();
  });
});

describe('리비전 고정 — 발행 시점 각인 vs 렌더 시점 조회 (핵심)', () => {
  it('4) [핵심] rev1 발행 → rev2 동결(+현재 포인터 이동) → rev1 쿠폰 레이아웃 조회 → 여전히 rev1 레이아웃이다', async () => {
    // beforeAll 에서 이미 couponRev1 발행 → rev2 동결 → 현재 포인터를 rev2 로
    // 옮기는 순서까지 재현했다. 여기서 "렌더 시점" 조회를 흉내 낸다.
    const resolved = await resolveLayoutForCoupon(couponRev1Id);
    expect(resolved).toEqual(layoutRev1);

    // 대조군 — 캠페인의 "현재" 포인터는 이미 rev2 로 옮겨져 있다는 것을
    // 직접 확인한다(렌더 시점 조회가 이 값을 보지 않는다는 것의 증거).
    const campaign = await prisma.bokjuCouponCampaign.findUnique({ where: { id: campaignId } });
    expect(campaign?.currentDesignRevisionId).toBe(rev2Id);
    expect(campaign?.currentDesignRevisionId).not.toBe(rev1Id);
  });

  it('5) rev1 쿠폰과 rev2 쿠폰을 각각 렌더하면 이미지 바이트가 다르다(디자인이 실제로 다르므로)', async () => {
    const r1 = await dispatchCouponRender({ couponId: couponRev1Id, registerBaseUrl: 'https://sintong.kr' });
    const r2 = await dispatchCouponRender({ couponId: couponRev2Id, registerBaseUrl: 'https://sintong.kr' });
    expect(r1.handled).toBe(true);
    expect(r2.handled).toBe(true);
    const hash1 = createHash('sha256').update(r1.buffer!).digest('hex');
    const hash2 = createHash('sha256').update(r2.buffer!).digest('hex');
    expect(hash1).not.toBe(hash2);
  });

  it('6) designRevisionId = null 인 쿠폰은 resolveLayoutForCoupon 이 null 을 반환한다(레거시 분기 신호)', async () => {
    const resolved = await resolveLayoutForCoupon(couponLegacyId);
    expect(resolved).toBeTruthy;
    expect(resolved).toBe(null);
  });

  it('7) [= 02d §8-7] designRevisionId = null 쿠폰은 dispatchCouponRender 가 handled=false 로 레거시 경로 분기를 알린다', async () => {
    const result = await dispatchCouponRender({ couponId: couponLegacyId, registerBaseUrl: 'https://sintong.kr' });
    expect(result.handled).toBe(false);
    expect(result.buffer).toBeUndefined();
  });
});

describe('리비전 고정 — partner.name 바인딩 (02d §6-7·8)', () => {
  it('8) partnerId 가 없는 쿠폰(= 현재 bokju_coupon_allocations 0건의 기본 상태)도 렌더가 실패하지 않는다', async () => {
    // couponRev1 은 partnerId 를 지정하지 않고 만들었다(기본값 null) —
    // 02d §6-7 이 말하는 "bokju_coupon_allocations 가 0건이라 이게 기본
    // 동작" 케이스를 그대로 재현한다.
    const result = await dispatchCouponRender({ couponId: couponRev1Id, registerBaseUrl: 'https://sintong.kr' });
    expect(result.handled).toBe(true);
    expect(result.buffer!.length).toBeGreaterThan(1000);
  });

  it('9) partnerId 가 있는 쿠폰은 partner.name 이 2차 쿼리로 조회되어 렌더 컨텍스트에 포함된다', async () => {
    const partner = await prisma.bokjuPartner.create({
      data: { name: '[TEST] 복주머니 제휴카페' },
    });
    const layoutWithPartner = addElement(defaultLayout(), 'text', {
      name: '제휴업체명', bind: 'partner.name',
      x: defaultLayout().canvas.width / 2, y: 140,
    });
    const rPartner = await freezeRevision(campaignId, layoutWithPartner, { note: '제휴업체명 포함 레이아웃' });
    const couponWithPartner = await prisma.bokjuCoupon.create({
      data: {
        campaignId,
        couponNo: 'TEST-PARTNER-' + Date.now(),
        redeemToken: createHash('sha256').update('partner-' + Date.now()).digest('hex').slice(0, 32),
        expiresAt: new Date('2026-12-31T23:59:59Z'),
        partnerId: partner.id,
        designRevisionId: rPartner.id,
      },
    });

    const result = await dispatchCouponRender({ couponId: couponWithPartner.id, registerBaseUrl: 'https://sintong.kr' });
    expect(result.handled).toBe(true);
    // SVG 자체를 들여다볼 수 없으니(dispatch 는 PNG Buffer 반환), buildSvg 를
    // 직접 호출해 partnerName 이 실제로 전달되는지 별도로 교차 검증한다.
    const { buildSvg } = await import('../src/lib/bokju-coupon-design/renderer');
    const svg = await buildSvg(layoutWithPartner, {
      campaign: { title: '테스트', grantAmount: 1, guideText: null, validFrom: new Date(), validTo: new Date() },
      coupon: { couponNo: couponWithPartner.couponNo, redeemToken: couponWithPartner.redeemToken },
      partnerName: partner.name,
    });
    expect(svg).toContain('복주머니 제휴카페');

    // 정리
    await prisma.bokjuCoupon.delete({ where: { id: couponWithPartner.id } });
    await prisma.bokjuPartner.delete({ where: { id: partner.id } });
  });
});

describe('리비전 고정 — 되돌리기(setCurrentRevision)', () => {
  it('10) 현재 리비전을 rev1 으로 되돌린 뒤 새로 발행하면, 새 쿠폰이 되돌린 리비전(rev1)을 참조한다', async () => {
    await setCurrentRevision(campaignId, rev1Id);
    const campaign = await prisma.bokjuCouponCampaign.findUnique({ where: { id: campaignId } });
    expect(campaign?.currentDesignRevisionId).toBe(rev1Id);

    const couponAfterRevert = await prisma.bokjuCoupon.create({
      data: {
        campaignId,
        couponNo: 'TEST-REVERT-' + Date.now(),
        redeemToken: createHash('sha256').update('revert-' + Date.now()).digest('hex').slice(0, 32),
        expiresAt: new Date('2026-12-31T23:59:59Z'),
        designRevisionId: campaign!.currentDesignRevisionId, // 발행 시점 각인 — issueCoupons() 와 동일한 패턴
      },
    });
    const resolved = await resolveLayoutForCoupon(couponAfterRevert.id);
    expect(resolved).toEqual(layoutRev1);

    await prisma.bokjuCoupon.delete({ where: { id: couponAfterRevert.id } });
    // 다음 실행을 위해 포인터를 rev2 로 복원(이 테스트 파일 내에서의 순서
    // 의존을 최소화 — 다른 it 블록이 이 포인터 값에 의존하지 않도록 함)
    await setCurrentRevision(campaignId, rev2Id);
  });
});

describe('리비전 고정 — [사용자 지적 반영] handled 플래그를 호출부가 실제로 존중하는지 (배치 루프 행동 검증)', () => {
  // [배경] "handled=false 플래그가 있는 것과 존중되는 것은 다르다 — 호출부가
  // 무시하면 없는 것보다 나쁘다"(사용자 지적, 02e §0-C). dispatchCouponRender()
  // 의 반환값만 보는 테스트(7번)로는 "그 값을 누가 소비하는지"를 증명하지 못한다.
  //
  // [왜 "함수 spy"가 아니라 "관찰 가능한 산출물 비교"인가] 실제 배치 루프
  // runImageJob() 은 bokju-coupon-image-service.ts 내부의 비공개(export 없음)
  // 함수다(절대불가침 파일 — 이 파일을 수정·재노출해 spy 를 꽂을 수 없다).
  // 이 프로젝트의 테스트 하네스(run-design-tests.ts)에는 jest.mock/vi.spyOn
  // 같은 모듈 모킹 기능도 없다. 대신 "함수 호출 여부"를 간접 관찰 가능한
  // 방법으로 확인한다: 신규 리비전의 캔버스를 레거시 렌더러의 고정 치수
  // (IMG_WIDTH=720 × IMG_HEIGHT=1280, bokju-coupon-image-service.ts:37-38)와
  // 다른 정사각형(1080×1080)으로 만든 뒤, 유일한 공개 진입점인
  // startImageGenerationJob() 을 실제로 호출해 산출된 PNG 파일의 실제 치수를
  // sharp 로 읽는다. 720×1280 이 나오면 레거시 renderCouponImage() 가 호출된
  // 것이고, 1080×1080 이 나오면 신규 buildSvg()(2~3단계 산출물)가 호출된
  // 것이다 — 이미지 치수는 "어느 코드가 실행됐는지"를 속일 수 없는 증거다.
  it('13) [행동 검증] designRevisionId 가 각인된 쿠폰도 실제 배치 루프(startImageGenerationJob)에서는 여전히 레거시 렌더러가 호출된다(= handled 플래그가 아직 아무도에게 소비되지 않는 현재 상태의 증거)', async () => {
    const { startImageGenerationJob, getImageJob, readCouponImage } = await import('../src/lib/bokju-coupon-image-service');
    const sharp = (await import('sharp')).default;
    const { rm } = await import('node:fs/promises');
    const path = await import('node:path');

    // 레거시와 치수가 다른(1080×1080) 신규 리비전을 만든다 — "어느 렌더러가
    // 호출됐는지"를 이미지 치수만으로 명확히 구분하기 위한 장치.
    const squareLayout = defaultLayout({ width: 1080, height: 1080 });
    const revSquare = await freezeRevision(campaignId, squareLayout, { note: '[배선검증] 1080x1080 신규 리비전' });
    await setCurrentRevision(campaignId, revSquare.id);

    // [핵심] issueCoupons() 와 동일한 각인 패턴 — 쿠폰 생성 시점에
    // campaign.currentDesignRevisionId(=신규 리비전)를 그대로 박는다.
    const wiringCoupon = await prisma.bokjuCoupon.create({
      data: {
        campaignId,
        couponNo: 'TEST-WIRING-' + Date.now(),
        redeemToken: createHash('sha256').update('wiring-' + Date.now()).digest('hex').slice(0, 32),
        expiresAt: new Date('2026-12-31T23:59:59Z'),
        designRevisionId: revSquare.id, // 발행 시점 각인 완료 — "신규 디자인이 있다"
      },
    });

    // dispatchCouponRender() 는 handled=true 를 반환한다 — 신규 경로가
    // *존재한다*는 것 자체는 이미 7번 케이스가 확인한 바와 같다(여기서도
    // 재확인해 둔다 — "경로가 없어서 당연히 레거시가 호출된 것"이라는
    // 반론을 차단하기 위함).
    const dispatchResult = await dispatchCouponRender({ couponId: wiringCoupon.id, registerBaseUrl: 'https://sintong.kr' });
    expect(dispatchResult.handled).toBe(true);

    // [실제 배치 루프 호출] 이것이 실서비스에서 쿠폰 이미지를 만드는 유일한
    // 공개 진입점이다 — 02d/02e 가 "발행 라우트 교체"라 부르는 바로 그 경로.
    const { jobId } = await startImageGenerationJob(campaignId, 'test-harness', {
      registerBaseUrl: 'https://sintong.kr',
    });

    // runImageJob() 은 await 되지 않고 백그라운드로 돈다(image-service.ts
    // 506-531행 — void runImageJob(...)) — 완료를 폴링한다.
    let job = await getImageJob(jobId);
    const deadline = Date.now() + 15000;
    while (job && job.status !== 'COMPLETED' && job.status !== 'FAILED' && Date.now() < deadline) {
      await new Promise((r) => setTimeout(r, 200));
      job = await getImageJob(jobId);
    }
    expect(job?.status).toBe('COMPLETED');

    // [증거] 실제로 파일시스템에 쓰인 PNG 치수를 읽는다 — 이것이 "handled
    // 플래그를 호출부가 실제로 소비했는지"의 유일하게 거짓말할 수 없는 증거다.
    const buf = await readCouponImage(campaignId, wiringCoupon.id);
    expect(buf).toBeTruthy;
    const meta = await sharp(buf!).metadata();

    // [현재 상태 — 02d §9 "발행 라우트 교체"가 아직 4단계 작업이라는 뜻]
    // 레거시 renderCouponImage() 의 고정 치수(720×1280, image-service.ts
    // IMG_WIDTH/IMG_HEIGHT)가 나온다. designRevisionId 가 각인되어 있고
    // dispatchCouponRender() 가 handled=true 를 반환함에도 불구하고, 실제
    // 배치 루프는 그 값을 전혀 조회하지 않고(select 절에 없음) 무조건
    // 레거시를 호출하기 때문이다 — "핸들된 값이 있어도 아무도 보지 않는다"
    // 는 사실이 숫자(치수)로 증명된다.
    //
    // ⚠️ 이 단언이 깨지는 날(= width/height 가 1080 으로 바뀌는 날)이 바로
    // 4단계에서 "발행 라우트 교체"가 완료된 신호다. 그때는 이 테스트를
    // 역방향으로 뒤집어야 한다(= 신규 렌더러가 호출됐음을 확인하는 테스트로).
    expect(meta.width).toBe(720);
    expect(meta.height).toBe(1280);

    // 정리
    await prisma.bokjuCoupon.delete({ where: { id: wiringCoupon.id } });
    await prisma.bokjuCouponImageJob.delete({ where: { id: jobId } });
    const dir = path.join(process.cwd(), 'public', 'uploads', 'bokju-coupons', `campaign_${campaignId}`);
    await rm(dir, { recursive: true, force: true }).catch(() => {});
    await setCurrentRevision(campaignId, rev2Id);
  });
});
