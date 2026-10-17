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
//   decoration→box/line/badgeCircle                                   (장식군 — "빼는" 매핑이 아니라 "넣는" 매핑.
//                                                                       classic 템플릿엔 장식 요소가 원래 0개이므로,
//                                                                       decoration===true일 때 레거시
//                                                                       buildCustomDesignSvg()의 장식(테두리 프레임 +
//                                                                       모서리 원 2개, bokju-coupon-image-service.ts
//                                                                       323-330줄)을 신규 요소로 새로 "추가"한다.
//                                                                       decoration===false면 기존 그대로 아무것도
//                                                                       추가하지 않는다 — 이쪽만 진짜 no-op.)
//   ctaText→(없음)   partnerName→(없음)                                 (02c §①·② 기존 결정 — 매핑하지 않는다)
//
// [02i §필수1 수정 — decoration 추가 로직]
//   레거시 장식 3요소를 신규 'box' kind로 재현한다(별도 kind 불필요 —
//   templates.ts의 badge 템플릿/PARTS의 'badgeCircle' 부품도 kind:'box'에
//   radius:999를 줘서 원을 표현한다. 'badgeCircle'은 ELEMENT_KINDS의 kind가
//   아니라 box의 한 변형일 뿐이다):
//     1) decoFrame      — 캔버스 전체에 가까운 테두리 box(fill 없음·stroke만,
//                          레거시 rect stroke="#d4a94a" 재현 → '@accent' 토큰)
//     2) decoCircleA/B  — 모서리 저채도 원 2개(box, radius:999, 낮은 opacity,
//                          레거시 circle opacity=0.06 재현)
//   세 요소 모두 z=0으로 두되 기존 요소들보다 배열 앞쪽에 넣어(동일 z에서는
//   배열 순서가 그대로 그리기 순서가 되므로 — svg.ts buildSvg의 안정 정렬)
//   텍스트/QR "뒤"에 깔리게 한다. 모서리 원은 안전여백(safeArea)을 넘어가
//   SAFE_AREA 경고가 날 수 있으나(의도된 "모서리 장식"이므로 경고는 정상),
//   같은 z(0)인 QR을 "덮지"는 않으므로(QR_COVERED 판정은 other.z > qr.z 일
//   때만 발동) error는 발생하지 않는다 — 검사 통과는 유지된다(금지 목록 ⑦).
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
import type { DesignLayout, LayoutElement } from './layout';
import { CANVAS_PRESETS } from './layout';
import { buildTemplate } from './templates';
import { resolveTheme } from './theme';
import {
  type CouponVisibilityConfig,
  normalizeVisibility,
} from '@/lib/bokju-coupon-visibility';

/**
 * [02i §필수1] decoration===true일 때 "추가"할 장식 요소 3개를 만든다.
 * 레거시 buildCustomDesignSvg()(bokju-coupon-image-service.ts 323-330줄)가
 * 그리던 값을 좌표·색·투명도까지 그대로 재현한다:
 *
 *   <rect x=14 y=14 width=W-28 height=H-28 rx=20 fill="none"
 *         stroke="#d4a94a" stroke-width=3 opacity=0.7/>      → decoFrame
 *   <circle cx=50 cy=60 r=90 fill="#d4a94a" opacity=0.06/>   → decoCircleA
 *   <circle cx=W-40 cy=H-90 r=130 fill="#d4a94a" opacity=0.06/> → decoCircleB
 *
 * 신규 레이아웃 스키마(layout.ts)에는 "fill 없음(테두리만)" 박스가 없으므로
 * (ELEMENT_KINDS의 'box'는 항상 fill을 그린다 — svg.ts elementSvg 'box' 분기),
 * decoFrame은 fillToken을 캔버스 배경과 같은 '@surface'로 둬서 시각적으로
 * "채움 없음"과 동일하게 만든다(이 변환 경로는 배경 이미지를 매핑하지
 * 않으므로 — 02e §4-1 매핑표에 배경 항목 자체가 없다 — 캔버스는 항상 단색
 * 배경이라 안전하다). 레거시의 금색(#d4a94a)은 테마 토큰 '@accent'로
 * 대체한다(고정 헥스 대신 토큰을 쓰면 팔레트를 바꿔도 장식이 따라온다 —
 * 이 파일의 다른 요소들과 동일한 원칙). 'badgeCircle'이라는 별도 kind는
 * 없다(ELEMENT_KINDS=['text','image','qr','box','line']) — templates.ts의
 * badge 템플릿/PARTS가 원을 표현할 때도 kind:'box'에 radius:999를 주는
 * 방식을 그대로 따른다.
 *
 * 세 요소 모두 z=0으로 두고 반환 배열의 맨 앞에 배치한다 — 같은 z(0)인
 * 다른 요소(예: qr z=5, logo z=0)와 섞여도 동일 z 안에서는 배열 순서가
 * 곧 그리기 순서이므로(svg.ts buildSvg의 stable sort), 맨 앞에 두면 항상
 * 다른 모든 요소보다 먼저(=아래에) 그려진다. QR_COVERED 검사는
 * `other.z <= qr.z`면 건너뛰므로(layout.ts 303줄) z=0인 이 장식 요소들은
 * QR(z=5)을 가린다고 판정되지 않는다 — 검사 통과가 유지된다.
 */
function buildDecorationElements(canvas: { width: number; height: number }): LayoutElement[] {
  const { width: W, height: H } = canvas;
  return [
    {
      id: 'decoFrame', kind: 'box', name: '장식 테두리', bind: 'static',
      x: W / 2, y: H / 2, width: W - 28, height: H - 28, radius: 20,
      fillToken: '@surface', strokeToken: '@accent', strokeWidth: 3, opacity: 0.7,
      z: 0, visible: true,
    },
    {
      id: 'decoCircleA', kind: 'box', name: '장식 원(좌상단)', bind: 'static',
      x: 50, y: 60, width: 180, height: 180, radius: 999,
      fillToken: '@accent', opacity: 0.06,
      z: 0, visible: true,
    },
    {
      id: 'decoCircleB', kind: 'box', name: '장식 원(우하단)', bind: 'static',
      x: W - 40, y: H - 90, width: 260, height: 260, radius: 999,
      fillToken: '@accent', opacity: 0.06,
      z: 0, visible: true,
    },
  ];
}

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

  const kept = base.elements.filter((el) => !dropIds.has(el.id));

  // [02i §필수1 — decoration은 "넣는" 매핑] classic 템플릿엔 장식 요소가
  // 원래 0개이므로, decoration===true일 때만 buildDecorationElements()로
  // 3개 요소를 새로 만들어 맨 앞(= z=0 중 가장 먼저 그려짐, 즉 가장 아래
  // 레이어)에 추가한다. decoration===false면 아무것도 추가하지 않는다
  // (이 경우에만 기존 주석이 말하던 "no-op"이 실제로 성립한다).
  const elements = visibility.decoration
    ? [...buildDecorationElements(canvas), ...kept]
    : kept;

  return {
    ...base,
    elements,
    redeemMode: visibility.qr ? 'QR' : 'MANUAL',
  };
}
