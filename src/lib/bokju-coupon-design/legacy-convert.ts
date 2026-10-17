// src/lib/bokju-coupon-design/legacy-convert.ts
// ─────────────────────────────────────────────────────────────────────
// 쿠폰 디자인 스튜디오 — 4단계 작업순서4(§4-3): "신규 디자인으로 전환"
//
// [목표 — 02e §4-3 기본안(d) + 02h §0-M-6 재확인]
//   기존 캠페인(11토글 CouponVisibilityConfig)의 표시 설정을 읽어
//   신규 DesignLayout(템플릿 + 미체크 항목 제거)으로 1회 변환한다.
//   자동 전환은 금지 — 이 모듈의 함수는 항상 관리자의 명시적 클릭
//   (API 호출)에 의해서만 실행된다.
//
// [매핑 — 02e §4-3 "전환 시 정보 매핑(실측 기반)", 02h §0-M-6 재확인]
//   logo→logo  title→title  amount→amount  couponNo→couponNo  qr→qr   (1:1, 5개)
//   validFrom+validTo→period   guideText→guide                        (별칭)
//   decoration→box/line/badgeCircle                                   (장식군 — classic 템플릿엔 해당 장식 요소가
//                                                                       없으므로 classic 기준 변환에서는 사실상 no-op)
//   ctaText→(없음)   partnerName→(없음)                                 (02c §①·② 기존 결정 — 매핑하지 않는다)
//
//   amount가 켜지면 "단위"(복주머니) 텍스트도 함께 유지한다 — unit은
//   CouponVisibilityConfig에 없는 신규 전용 보조 요소이며, 레거시에서도
//   amount 블록 안에 "지급 복주머니" 레이블이 항상 같이 그려졌으므로
//   (bokju-coupon-image-service.ts buildCustomDesignSvg 참고) 분리하지 않는다.
//
// [절대 불가침 — 02e §7 금지 목록]
//   ② CouponVisibilityConfig/computeLayout 삭제·수정 금지 — 이 파일은
//      bokju-coupon-visibility.ts를 "읽기만" 한다(import해서 타입·정규화
//      함수만 재사용, 수정 없음).
//   ⑥ computeLayout을 CANVAS_PRESETS로 치환 금지 — 이 파일은 computeLayout을
//      전혀 호출하지 않는다(레거시 reflow 좌표를 신규 레이아웃에 베끼지
//      않는다 — 신규 레이아웃은 templates.ts의 classic 좌표를 그대로 쓴다).
//   ⑦ 발행 전 검사 12종 완화·우회 금지 — 변환 결과는 validateLayout()을
//      그대로 통과해야 하며, 이 파일이 검사를 느슨하게 만들지 않는다.
// ─────────────────────────────────────────────────────────────────────
import type { DesignLayout } from './layout';
import { CANVAS_PRESETS } from './layout';
import { buildTemplate } from './templates';
import { resolveTheme } from './theme';
import {
  type CouponVisibilityConfig,
  normalizeVisibility,
} from '@/lib/bokju-coupon-visibility';

/**
 * CouponVisibilityConfig(11토글) → DesignLayout 변환.
 *
 * 절차(02e §4-1 "템플릿 + 미체크 항목 제거"):
 *   1) classic 템플릿으로 레이아웃을 만든다(가장 무난 — §4-1 실측 근거,
 *      defaultLayout(720)과 동일 계열이라 검사 통과가 보장된다).
 *   2) 11토글 중 꺼진 항목에 대응하는 신규 요소를 제거한다.
 *   3) QR을 껐으면 redeemMode를 MANUAL로 바꾼다(검사 §2 QR_PRESENT_MANUAL
 *      방지 — QR 요소 자체가 없으니 QR_MISSING 경고만 남고 에러는 아니다).
 *
 * 이 함수는 결과가 validateLayout() 오류 0을 만족하는지 스스로 보장하지
 * 않는다(극단적 조합 — qr과 couponNo를 모두 끈 레거시 설정 — 은 신규
 * 검사 §4 NO_DYNAMIC_BINDING에 걸릴 수 있다). 호출부(studio-api.ts의
 * convertLegacyDesign)가 validateLayout()으로 재검증하고, 실패하면
 * 전환 자체를 거부한다(발행 전 검사를 우회하지 않는다 — 금지 목록 ⑦).
 */
export function convertVisibilityToLayout(
  rawVisibility: unknown,
  canvas: { width: number; height: number } = CANVAS_PRESETS.PORTRAIT_720,
): DesignLayout {
  const visibility: CouponVisibilityConfig = normalizeVisibility(rawVisibility);
  const theme = resolveTheme(undefined); // 기본 팔레트(bok-red) — 레거시엔 팔레트 개념이 없으므로 기본값을 쓴다
  const base = buildTemplate('classic', theme, canvas);

  // [1:1 매핑 5개 + amount→amount,unit] 꺼진 항목에 대응하는 요소를 제거한다.
  // classic 템플릿의 요소 id: logo, title, amount, unit, guide, qr, couponNo, period, domain
  const dropIds = new Set<string>();
  if (!visibility.logo) dropIds.add('logo');
  if (!visibility.title) dropIds.add('title');
  if (!visibility.amount) {
    dropIds.add('amount');
    dropIds.add('unit'); // amount를 끄면 "복주머니" 단위 레이블도 함께 제거(레거시와 동일하게 한 블록 취급)
  }
  if (!visibility.couponNo) dropIds.add('couponNo');
  if (!visibility.qr) dropIds.add('qr');
  // [별칭] validFrom+validTo → period. 둘 다 꺼졌을 때만 period를 제거한다
  // (둘 중 하나라도 켜져 있으면 레거시 쪽도 "사용기한 ~만료일까지" 식으로
  // 한 줄을 그렸으므로 — bokju-coupon-image-service.ts buildCustomDesignSvg
  // 참고 — period를 유지한다).
  if (!visibility.validFrom && !visibility.validTo) dropIds.add('period');
  // [별칭] guideText → guide
  if (!visibility.guideText) dropIds.add('guide');
  // domain은 CouponVisibilityConfig에 없는 신규 전용 요소(등록 안내) —
  // 11토글에 대응 항목이 없으므로 끄고 켜는 판단 근거가 없다. 항상 유지한다
  // (QR을 못 찍는 상황의 안내라는 본래 목적상, 끄면 §4-1 "정보 손실"이
  // 늘어나므로 보수적으로 유지하는 것이 맞다).
  // ctaText/partnerName: classic 템플릿 자체에 해당 요소가 없으므로
  // "매핑 없음" 결정(02c §①·②)이 이미 구조적으로 반영되어 있다.
  // decoration: classic 템플릿엔 box/line/badgeCircle 요소가 없으므로
  // 이 변환에서는 켜거나 꺼도 영향이 없다(no-op) — 다른 템플릿을 쓰면
  // 장식군이 생기지만, §4-1 "가장 무난한" classic을 기본으로 택했다.

  const elements = base.elements.filter((el) => !dropIds.has(el.id));

  return {
    ...base,
    elements,
    redeemMode: visibility.qr ? 'QR' : 'MANUAL',
  };
}
