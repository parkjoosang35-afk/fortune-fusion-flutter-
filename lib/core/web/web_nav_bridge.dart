/// [PC 랜딩 연동 — postMessage 기반 양방향 라우팅 동기화]
///
/// [배경] 신통방통 PC 웹 랜딩(sintong.kr/)은 이 앱을 `sintong.kr/app/`에
/// iframe으로 띄우고, 왼쪽 메뉴 클릭 시 iframe 내부 화면을 해당 서비스로
/// 이동시키려 한다. 처음 디자인 지시서는 `iframe.contentWindow.location.hash`를
/// 직접 바꾸는 방식을 제안했으나, 실측 결과 이 방식은 작동하지 않았다:
/// hash를 바꾸면 브라우저가 `popstate` 이벤트를 발생시키는데, Flutter Web
/// 엔진이 이미 그 이벤트를 "시스템 뒤로가기(백 버튼)" 처리용으로 선점해
/// 사용하고 있어(`handlePopRoute` → 현재 라우트를 pop), 우리가 원하는
/// "특정 라우트로 점프"와 의미가 달라 짧게 화면이 바뀌었다가 곧바로
/// 되돌아가는 증상이 나타났다(기존 네비게이션 스택/URL 동기화 로직과
/// 충돌).
///
/// [해결] `window.postMessage`는 브라우저 히스토리·URL을 전혀 건드리지
/// 않으므로 위 충돌이 원천적으로 없다. 이 파일은 그 최소 배선만 담당한다:
///   - 랜딩 → 앱: `{type: 'sintong:navigate', route: '/jeontong/input'}`
///     형태의 메시지를 받으면 전역 Navigator로 해당 named route로 이동.
///   - 앱 → 랜딩: 라우트가 바뀔 때마다 부모 윈도우(이 앱을 iframe으로
///     띄운 랜딩 페이지)에 `{type: 'sintong:route-changed', route: '…'}`
///     를 보낸다(이 앱이 iframe 안에 있지 않으면, 즉 standalone/APK면
///     아무 일도 하지 않는다).
///
/// [기존 코드에 대한 영향] 어떤 화면/Provider/라우팅 로직도 수정하지
/// 않는다. 웹 플랫폼에서만 동작(비-웹은 전부 no-op 스텁), MaterialApp에
/// `navigatorObservers` 1개를 추가하고 `main()`에서 리스너 1개를
/// 등록하는 것이 전체 변경 범위다.
export 'web_nav_bridge_io.dart' if (dart.library.html) 'web_nav_bridge_web.dart';
