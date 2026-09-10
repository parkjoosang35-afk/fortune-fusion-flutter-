/// [긴급 버그 수정 - 실제 모바일에서 PC 목업 프레임 노출] 비-웹(Android
/// APK 등) 플랫폼에서는 브라우저 User-Agent 개념이 없고, 애초에
/// `WebMobileFrame`이 `kIsWeb`일 때만 동작하므로 이 함수가 호출될 일이
/// 없다. 안전하게 false를 반환한다(프로덕션 APK 동작에 영향 없음).
bool isMobileBrowser() => false;
