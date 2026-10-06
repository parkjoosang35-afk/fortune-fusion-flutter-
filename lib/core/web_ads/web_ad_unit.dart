// [웹 AdSense 광고 시스템] 조건부 export 진입점 — 기존 ad_script_view.dart와
// 동일한 패턴. Web에서만 실제 `<ins class="adsbygoogle">` DOM을 그리고,
// 그 외(Android/iOS/테스트)에서는 no-op 스텁을 쓴다.
export 'web_ad_unit_stub.dart' if (dart.library.html) 'web_ad_unit_web.dart';
