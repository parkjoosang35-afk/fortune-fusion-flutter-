/// [브라우저 "뒤로가기" 버튼 버그수정 — 정통사주 화면 등 전체 앱 공통]
///
/// [증상] 정통사주 메인 화면(및 그 외 대부분의 내부 화면)에서 **브라우저
/// 자체의 뒤로가기 버튼**(또는 모바일 브라우저의 스와이프 제스처,
/// Playwright `page.go_back()`)을 누르면 화면이 전혀 바뀌지 않고 완전히
/// 무반응이었다(실측 재현 확인).
///
/// [근본 원인] 이 앱은 Navigator 1.0(`MaterialApp(onGenerateRoute: ...)`)을
/// 사용하는데, `AppRouter._page()` 헬퍼가 `MaterialPageRoute(builder: ...)`를
/// 만들 때 `RouteSettings`를 전달하지 않아(`saju_dimension_transition.dart`의
/// `sajuDimensionEnterRoute`도 동일) **모든 Route의 `settings.name`이 항상
/// `null`**이다(이는 `web_nav_bridge_web.dart`의 `notifyRouteName`이
/// `NavigatorObserver` 대신 `onGenerateRoute` 시점의 `RouteSettings`를 직접
/// 써야 했던 이유이기도 하다 — 기존 주석 참고).
///
/// Flutter Web의 Navigator 1.0 URL 동기화는 각 라우트의 `settings.name`을
/// 읽어 `window.history.pushState`를 호출하는데, 이름이 전부 `null`이라
/// **앱 내부에서 화면을 아무리 이동해도 브라우저 히스토리에 새 엔트리가
/// 전혀 쌓이지 않는다**(실측: `window.history.length`가 온보딩 이후
/// 어떤 화면 전환에도 전혀 증가하지 않음을 확인). 그 결과 브라우저
/// 뒤로가기를 눌러도 "되돌아갈 엔트리" 자체가 없어 아무 일도 일어나지
/// 않는다.
///
/// [고려했지만 선택하지 않은 수정] `_page()`/`sajuDimensionEnterRoute`에
/// `settings`를 전달해 Flutter의 기본 URL 동기화를 살리는 방법은, 과거
/// `web_nav_bridge.dart`에 기록된 것처럼 hash 변경이 `popstate`를 발생시켜
/// Flutter 엔진의 내장 핸들러(`handlePopRoute`)와 충돌해 "화면이 바뀌었다가
/// 곧바로 되돌아가는" 버그를 재현할 위험이 크고, 호출부가 79곳 이상이라
/// 변경 범위/회귀 위험이 과도하다. 이 파일은 URL을 전혀 건드리지 않는
/// 훨씬 안전한 대안을 택한다.
///
/// [해결] URL을 바꾸지 않으면서(해시/경로 변경 없음, 기존 랜딩 iframe
/// 연동에 영향 없음) 히스토리 스택에 "가드용" 엔트리를 하나 유지한다.
/// 사용자가 브라우저 뒤로가기를 누르면 그 가드 엔트리가 소비되며
/// `popstate`가 발생하는데, 이때 즉시 가드 엔트리를 다시 쌓아 "항상 뒤로
/// 갈 곳이 있는" 상태를 유지하고, 동시에 `appNavigatorKey`(전역 루트
/// Navigator)의 `maybePop()`을 호출한다. 이는 Android 하드웨어 백버튼이
/// 이미 사용하는 것과 **완전히 동일한 경로**(`WidgetsApp`의 기본
/// `_handlePopRoute` → `navigator.maybePop()`)이므로, 각 화면에 이미
/// 구현되어 있는 `PopScope`/`WillPopScope` 커스텀 복귀 전환(예:
/// `SajuRenewalHomeScreen._exitWithReturnTransition` →
/// `playSajuReturnOverlayThenPop`)을 그대로 재사용한다 — 화면별로 별도
/// 배선을 추가할 필요가 없다.
///
/// [기존 코드에 대한 영향] 전역에서 단 한 번(`main()`)만 호출하는 순수
/// 부가 기능이며, 어떤 화면/라우팅 로직도 수정하지 않는다. 웹
/// 플랫폼에서만 동작(비-웹은 no-op 스텁).
export 'browser_back_bridge_io.dart' if (dart.library.html) 'browser_back_bridge_web.dart';
