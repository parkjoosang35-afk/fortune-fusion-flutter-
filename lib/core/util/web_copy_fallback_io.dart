/// 네이티브(Android/iOS) 스텁 — `safe_share.dart`가 `kIsWeb`일 때만 이
/// 함수를 호출하므로 비-웹 플랫폼에서는 절대 호출되지 않는다. 조건부
/// export가 항상 하나의 구현을 요구하므로 안전한 기본값(false)만 반환하는
/// 자리채움 구현이다.
library;

bool tryLegacyExecCommandCopy(String text) => false;
