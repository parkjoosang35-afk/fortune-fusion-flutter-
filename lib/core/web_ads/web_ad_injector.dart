// [웹 AdSense 광고 시스템] 조건부 export 진입점 — 기존 ad_script_view.dart와
// 동일한 패턴(플랫폼별 구현을 dart.library.* 조건으로 선택)을 그대로
// 재사용한다. Web에서만 실제 스크립트를 주입하고, 그 외(Android/iOS/테스트)
// 에서는 no-op 스텁을 쓴다.
export 'web_ad_injector_stub.dart' if (dart.library.html) 'web_ad_injector_web.dart';
