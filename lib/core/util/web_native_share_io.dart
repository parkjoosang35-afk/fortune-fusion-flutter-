/// 네이티브(Android/iOS) 스텁 — 이 파일의 함수는 웹이 아닌 플랫폼에서는
/// 절대 호출되지 않는다(호출부인 `safe_share.dart`가 `kIsWeb`으로 이미
/// 분기하기 때문). 조건부 export가 항상 하나의 구현을 요구하므로 안전한
/// 기본값(false)만 반환하는 자리채움 구현이다.
Future<bool> tryNativeWebShare(String text, {String? subject}) async {
  return false;
}
