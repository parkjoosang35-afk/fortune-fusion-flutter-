// 조건부 export 진입점 — 플랫폼에 맞는 `buildAdScriptView()` 구현을 선택한다.
//
// - Web(`dart.library.html` 존재): `ad_script_view_web.dart`
//   (dart:ui_web platformViewRegistry로 실제 DOM 오버레이)
// - Android/iOS(`dart.library.io` 존재): `ad_script_view_mobile.dart`
//   (webview_flutter WebViewController.loadHtmlString)
// - 그 외(테스트 등): `ad_script_view_stub.dart` (빈 위젯)
export 'ad_script_view_stub.dart'
    if (dart.library.html) 'ad_script_view_web.dart'
    if (dart.library.io) 'ad_script_view_mobile.dart';
