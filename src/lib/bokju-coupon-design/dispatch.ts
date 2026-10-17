// src/lib/bokju-coupon-design/dispatch.ts
// ─────────────────────────────────────────────────────────────────────
// 쿠폰 디자인 스튜디오 — 3단계: 호출부 배선(쿠폰 1장 렌더 디스패치)
//
// [배경 — 02d_3단계-리비전고정.md §4-2] 지시서는 "generate-images/route.ts
// / startImageGenerationJob 의 컨텍스트 조립 지점"에서 배선하라고 하지만,
// 실제 조립 지점은 그 안에서 호출되는 비공개 함수 runImageJob()
// (bokju-coupon-image-service.ts, export 없음) 내부에 있고, 이 파일은
// 절대불가침(02d §7-5)이라 수정할 수 없다. 02d §9 가 "발행 라우트 교체"
// 자체를 4단계 작업으로 명시하므로 모순은 아니다 — 3단계에서는 그 배선
// 로직을 이 파일에 "완성된 형태"로 독립적으로 만들어 완전히 테스트하고,
// 4단계가 실제 배치 루프/라우트를 교체할 때 이 함수를 호출하도록 준비한다
// (2단계의 renderer.ts 를 "만들었지만 아직 실트래픽에 연결 안 함" 상태로
// 둔 것과 동일한 패턴).
//
// [이 파일이 하는 일 — 02d §4-2 1~5번]
//   1. 쿠폰의 designRevisionId 확인
//   2. 있으면 → resolveLayoutForCoupon 로 스냅샷 레이아웃 → 신규 렌더러
//   3. 없으면 → 기존 경로(레거시)를 타야 함을 알리는 신호(null) 반환
//      (이 파일이 기존 renderCouponImage 를 대신 호출하지 않는다 — 그건
//      bokju-coupon-image-service.ts 의 책임 영역이고, 여기서 건드리면
//      절대불가침을 깬다. 호출부가 null 을 보고 기존 경로로 분기한다.)
//   4. partner.name 조회(2차 쿼리 1회) → RenderContext.partnerName
//      coupon.partnerId 있으면 findUnique, 없으면 undefined.
//      빈 값이면 렌더러(2단계)가 해당 요소를 자동으로 건너뛴다.
//   5. registerBaseUrl 은 호출부가 기존 resolvePublicOrigin(request) 결과를
//      그대로 넘긴다(이 파일은 origin 을 스스로 계산하지 않는다).
//
// [금지 목록 — 02d §7]
//   #4 designRevisionId 를 렌더 시점에 조회하지 않는다 — 이 함수는 이미
//      발행 시점에 각인된 coupon.designRevisionId 를 "읽기만" 한다
//      (각인 자체는 bokju-coupon-service.ts issueCoupons() 가 발행 시점에
//      수행 — 3단계에서 이미 배선 완료).
//   #5 bokju-coupon-image-service.ts / bokju-coupon-visibility.ts 를
//      import 하지 않는다.
// ─────────────────────────────────────────────────────────────────────
import { prisma } from '@/lib/db';
import { resolveLayoutForCoupon } from './revision';
import { renderCouponImage, type RenderContext } from './renderer';

export interface DispatchCouponRenderInput {
  couponId: number;
  registerBaseUrl: string;
}

export interface DispatchCouponRenderResult {
  /** true = 신규 렌더러(리비전 스냅샷)로 렌더됨. false = 레거시 경로로 분기해야 함(이 함수가 렌더하지 않음). */
  handled: boolean;
  buffer?: Buffer;
}

/**
 * 쿠폰 1장을 "어느 경로로 렌더할지" 판단하고, 신규 경로(리비전 있음)면
 * 직접 렌더까지 수행한다. 레거시 경로(리비전 없음)면 handled=false 를
 * 반환할 뿐 아무것도 렌더하지 않는다 — 호출부(4단계에서 교체될 배치 루프)
 * 가 기존 bokju-coupon-image-service.ts 경로로 계속 진행해야 한다.
 */
export async function dispatchCouponRender(
  input: DispatchCouponRenderInput,
): Promise<DispatchCouponRenderResult> {
  const coupon = await prisma.bokjuCoupon.findUnique({
    where: { id: input.couponId },
    include: { campaign: true },
  });
  if (!coupon) throw new Error(`쿠폰 ${input.couponId} 을(를) 찾을 수 없습니다.`);

  // [02d §3-3] 렌더 시점에 campaign.currentDesignRevisionId 를 보지 않는다.
  // coupon.designRevisionId(발행 시점 각인값)만 본다.
  const layout = await resolveLayoutForCoupon(coupon.id);
  if (!layout) {
    return { handled: false }; // 레거시 디자인 → 호출부가 기존 경로로 분기
  }

  // [02d §4-2-4] partner.name 2차 쿼리. 빈 값이면 렌더러가 요소를 건너뛴다
  // (campaignTitle 로 대체하지 않음 — 02c §2 결정).
  let partnerName: string | undefined;
  if (coupon.partnerId != null) {
    const partner = await prisma.bokjuPartner.findUnique({
      where: { id: coupon.partnerId },
      select: { name: true },
    });
    partnerName = partner?.name;
  }

  const ctx: RenderContext = {
    campaign: {
      title: coupon.campaign.title,
      grantAmount: coupon.campaign.grantAmount,
      guideText: coupon.campaign.guideText,
      validFrom: coupon.campaign.validFrom,
      validTo: coupon.campaign.validTo,
    },
    coupon: { couponNo: coupon.couponNo, redeemToken: coupon.redeemToken },
    // [2차 수정 — 역할 분리] 사용자 지적 반영: renderer.ts 는 2단계 신규
    // 생성물이라 수정 금지 대상이 아니다(02d §7 금지 목록 #5·#6 은
    // bokju-coupon-image-service.ts/bokju-coupon-visibility.ts·templates.ts
    // 만 가리킨다 — templates.ts 와 착각했었다). renderer.ts 쪽에
    // RenderContext.registerBaseUrl 전용 필드를 새로 만들고, QR·
    // coupon.registerUrl 생성은 그 필드만 보도록 고쳤다(추론 제거).
    // 그 결과:
    //   · brand.domain  → 화면 표시 전용. "sintong.kr" 처럼 사람이 읽는
    //     짧은 도메인명만 넣는다(URL 생성에는 전혀 쓰이지 않는다).
    //   · registerBaseUrl → QR·등록 URL 생성 전용. resolvePublicOrigin()
    //     이 돌려준 origin 전체(scheme+host[:port])를 가공 없이 그대로
    //     넘긴다 — 로컬(`http://localhost:4300`)이든 운영(`https://sintong.kr`)
    //     이든 scheme 이 뒤바뀌거나 포트가 사라지지 않는다.
    brand: { name: '신통방통', domain: new URL(input.registerBaseUrl).hostname },
    registerBaseUrl: input.registerBaseUrl,
    partnerName,
  };

  const buffer = await renderCouponImage(layout, ctx);
  return { handled: true, buffer };
}
