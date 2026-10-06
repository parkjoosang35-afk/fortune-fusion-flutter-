// [웹 AdSense 광고 시스템] 조건부 export 진입점 — Anchor/Vignette 페이지
// 레벨 광고 활성화. Web에서만 실제로 동작한다.
export 'web_ad_page_level_stub.dart'
    if (dart.library.html) 'web_ad_page_level_web.dart';
