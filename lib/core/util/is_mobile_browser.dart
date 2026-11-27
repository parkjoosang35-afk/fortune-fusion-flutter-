/// [긴급 버그 수정 - 실제 모바일에서 PC 목업 프레임 노출] 플랫폼별 구현을
/// 조건부로 연결하는 진입점. 웹에서는 User-Agent 기반 판별
/// (`is_mobile_browser_web.dart`)을, 그 외(Android APK 등)에서는 항상
/// false를 반환하는 스텁(`is_mobile_browser_io.dart`)을 사용한다.
export 'is_mobile_browser_io.dart'
    if (dart.library.html) 'is_mobile_browser_web.dart';
