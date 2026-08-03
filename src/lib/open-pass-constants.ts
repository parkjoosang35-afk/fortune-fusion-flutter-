// 열림패스 첨부파일/광고소스 관련 공용 상수(타입) 정의.
// [사용자 요청: 열림패스 관리자 첨부파일/광고소스 연동] §3/§4
// 주의: Next.js "use server" 파일(open-pass-attachments.ts, open-pass-ad-sources.ts)은
// async 함수만 export할 수 있으므로, 클라이언트 컴포넌트(폼)에서도 재사용해야 하는
// 이 상수 배열들은 "use server"가 아닌 이 순수 모듈에 두고 양쪽(Server Action 파일의
// zod 스키마 / 클라이언트 폼의 select 옵션)에서 동일하게 import한다.
// (§15 "앱/관리자에서 값이 갈라지면 안 된다" 원칙과 동일한 이유로, select 옵션을
// 이 배열과 별도로 하드코딩하지 않는다.)

export const ATTACHMENT_FILE_TYPES = [
  "image",
  "video",
  "document",
  "external_link",
  "rich_text_html",
  "ad_fallback_image",
  "ad_fallback_video",
] as const;
export type AttachmentFileType = (typeof ATTACHMENT_FILE_TYPES)[number];

export const ATTACHMENT_FILE_TYPE_LABELS: Record<AttachmentFileType, string> = {
  image: "이미지",
  video: "영상",
  document: "문서(PDF)",
  external_link: "외부 링크",
  rich_text_html: "리치 텍스트(HTML)",
  ad_fallback_image: "광고 대체 이미지",
  ad_fallback_video: "광고 대체 영상",
};

export const ATTACHMENT_PURPOSES = [
  "hero_banner",
  "product_thumbnail",
  "reward_ad_promo",
  "pre_ad_banner",
  "post_ad_banner",
  "fallback_creative",
  "terms_doc",
  "event_banner",
  "modal_image",
] as const;
export type AttachmentPurpose = (typeof ATTACHMENT_PURPOSES)[number];

export const ATTACHMENT_PURPOSE_LABELS: Record<AttachmentPurpose, string> = {
  hero_banner: "대표(hero) 배너",
  product_thumbnail: "상품 썸네일",
  reward_ad_promo: "광고 시청 유도 배너",
  pre_ad_banner: "광고 시청 전 안내 배너",
  post_ad_banner: "광고 시청 후 완료 배너",
  fallback_creative: "광고 실패 대체 소재",
  terms_doc: "이용 안내 문서",
  event_banner: "이벤트 배너",
  modal_image: "팝업(모달) 이미지",
};

export const AD_SOURCE_TYPES = [
  "admob_rewarded",
  "admob_interstitial",
  "applovin_rewarded",
  "meta_audience_rewarded",
  "custom_vast",
  "custom_web_ad",
  "internal_promo_ad",
  // ── [프리패스 테스트 인프라] §4 실광고 네트워크 연동 없이 프리패스 지급/실패 흐름
  // 전체를 검증하기 위한 테스트 전용(mock) 광고소스 5종. 실제 SDK 호출 없이
  // RewardedAdSimulator(Flutter)가 sourceType 접두어(mock_rewarded_)를 보고
  // 결정적으로(항상 같은 결과로) 동작을 재현한다 (§12 "실광고 없으면 검증 불가" 금지).
  "mock_rewarded_success",
  "mock_rewarded_fail",
  "mock_rewarded_no_fill",
  "mock_rewarded_cancel",
  "mock_rewarded_timeout",
] as const;
export type AdSourceType = (typeof AD_SOURCE_TYPES)[number];

export const AD_SOURCE_TYPE_LABELS: Record<AdSourceType, string> = {
  admob_rewarded: "AdMob 리워드",
  admob_interstitial: "AdMob 전면",
  applovin_rewarded: "AppLovin 리워드",
  meta_audience_rewarded: "Meta Audience 리워드",
  custom_vast: "커스텀 VAST",
  custom_web_ad: "커스텀 웹 광고",
  internal_promo_ad: "내부 프로모션 광고",
  mock_rewarded_success: "[테스트] 항상 성공",
  mock_rewarded_fail: "[테스트] 항상 실패",
  mock_rewarded_no_fill: "[테스트] 항상 no-fill",
  mock_rewarded_cancel: "[테스트] 항상 중도취소",
  mock_rewarded_timeout: "[테스트] 항상 타임아웃",
};

// mock_rewarded_* 소스타입인지 판별하는 헬퍼(관리자/서비스 레이어 공용).
export function isMockAdSourceType(sourceType: string): boolean {
  return sourceType.startsWith("mock_rewarded_");
}

export const BINDING_USAGE_TYPES = [
  "hero_banner",
  "promo_banner",
  "pre_ad_banner",
  "post_ad_banner",
  "fallback_creative",
  "terms_doc",
  "event_banner",
  "modal_image",
] as const;

export const AD_SOURCE_PLATFORMS = ["all", "android", "ios", "web"] as const;

// ── [프리패스 테스트 인프라] §3 적용 대상 운세 범위(scope) 프리셋 ──
// PassPolicy.scope는 실제 DB에 콤마(,)로 구분된 FeatureScope 키 문자열로 저장되지만,
// 관리자에게는 사용자가 요청한 6개 의미단위 프리셋(all_fortune/fortune_today/tarot_only/
// saju_only/compatibility_only/physiognomy_palm_bundle)로만 선택지를 제공한다(자유입력 방지).
// 주의: 현재 Flutter 앱은 AccessChecker.canAccessFortuneScope()가 "열림패스 활성여부"만
// 판단하고 카테고리별 scope를 아직 개별 판독하지 않으므로(§11 "1차는 전체 운세
// 열림(all_fortune) 우선 구현해도 된다" 허용사항), 어떤 preset을 고르든 실제 앱 동작은
// 동일하다(전체 열림). 보관용/향후 카테고리별 잠금 확장을 위해 값은 미리 저장해둔다.
export const SCOPE_PRESETS = {
  all_fortune: "fortune_today,fortune_tarot,fortune_saju,fortune_compatibility,fortune_face_palm,fortune_theme",
  fortune_today: "fortune_today",
  tarot_only: "fortune_tarot",
  saju_only: "fortune_saju",
  compatibility_only: "fortune_compatibility",
  physiognomy_palm_bundle: "fortune_face_palm",
} as const;
export type ScopePresetKey = keyof typeof SCOPE_PRESETS;

export const SCOPE_PRESET_LABELS: Record<ScopePresetKey, string> = {
  all_fortune: "전체 운세",
  fortune_today: "오늘의 운세만",
  tarot_only: "타로만",
  saju_only: "사주만",
  compatibility_only: "궁합만",
  physiognomy_palm_bundle: "관상/손금 세트",
};

// 실제 저장된 scope CSV 문자열을 보고 어떤 preset인지 역추정(관리자 폼 기본값 표시용).
export function detectScopePreset(scope: string): ScopePresetKey {
  const found = (Object.entries(SCOPE_PRESETS) as [ScopePresetKey, string][]).find(
    ([, v]) => v === scope
  );
  return found ? found[0] : "all_fortune";
}
