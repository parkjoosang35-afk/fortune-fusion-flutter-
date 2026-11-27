// 조건부 export 진입점 — 플랫폼에 맞는 `PolicyWebView` 구현을 선택한다.
// [2026-11 회원약관 보기 수정] `ad_banner/presentation/ad_script_view.dart`와
// 동일한 조건부 임포트 패턴을 재사용한다. `webview_flutter`는 Web 플랫폼을
// 지원하지 않으므로(네이티브 WebView 엔진이 없음), Web에서는 `dart:ui_web`
// 기반 `<iframe>` 오버레이로 동일한 "앱 안에서 약관 페이지를 스크롤해 보는"
// 경험을 제공한다.
export 'guinji_policy_webview_stub.dart'
    if (dart.library.html) 'guinji_policy_webview_web.dart'
    if (dart.library.io) 'guinji_policy_webview_mobile.dart';
