/// [웹 AdSense 광고 시스템] 전역 로더 스크립트 주입 — Non-web 구현(no-op).
///
/// Android/iOS(모바일 앱 빌드) 및 테스트 환경에서는 AdSense 자체가 존재하지
/// 않는다(지시서 §2 절대 원칙 — 앱 광고는 AdMob 그대로 유지, 이 파일이
/// AdMob 쪽에 어떤 영향도 주지 않는다). [WebAdService]가 이미 `kIsWeb`
/// 가드로 이 함수를 호출하기 전에 걸러내지만, 혹시라도 호출되더라도
/// 안전하게 아무 일도 하지 않도록 이중으로 방어한다.
void injectAdSenseScriptOnce(String publisherId) {
  // no-op — Web 전용 기능.
}
