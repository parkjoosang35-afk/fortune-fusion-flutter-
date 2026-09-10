// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// [긴급 버그 수정 - 실제 모바일에서 PC 목업 프레임 노출] 웹 플랫폼에서
/// 브라우저의 User-Agent 문자열을 검사해 실제 모바일/태블릿 기기에서
/// 접속했는지 판별한다.
///
/// [배경] `WebMobileFrame`은 원래 "PC 브라우저에서 열었을 때만" 폰
/// 목업(베젤·노치)을 보여주기 위한 것이었는데, 폭(width)만으로 PC 여부를
/// 판단했다(폭이 430px를 넘으면 PC로 간주). 그런데 갤럭시 등 일부
/// 안드로이드 기기는 브라우저의 CSS 논리적 뷰포트 폭이 430px를 초과할 수
/// 있어(예: 배율 설정, 특정 브라우저의 레이아웃 뷰포트 처리 방식 차이),
/// 실제 사용자가 카카오톡 링크를 눌러 휴대폰 크롬으로 열었을 때도 PC로
/// 오판되어 앱 전체가 작은 폰 그림 안에 쪼그라들어 보이는 심각한 문제가
/// 발생했다.
///
/// [해결] 폭 대신(또는 폭과 함께) User-Agent로 실제 모바일/태블릿 기기
/// 여부를 판별한다. User-Agent에 Android/iPhone/iPad/iPod/Mobile 등의
/// 토큰이 있으면 무조건 실제 모바일 기기로 간주해 목업을 절대 씌우지
/// 않는다 — 화면 폭과 무관하게 항상 실제 모바일 사용자에게는 앱을
/// 그대로(프레임 없이) 보여주는 것이 최우선이다.
bool isMobileBrowser() {
  try {
    final ua = html.window.navigator.userAgent.toLowerCase();
    const mobileTokens = [
      'android',
      'iphone',
      'ipad',
      'ipod',
      'mobile',
      'windows phone',
    ];
    return mobileTokens.any((t) => ua.contains(t));
  } catch (_) {
    // UA를 읽을 수 없으면 안전하게 "모바일이 아님"으로 보지 않고,
    // 폭 기반 판별에만 의존하도록 false를 반환한다(기존 동작 유지).
    return false;
  }
}
