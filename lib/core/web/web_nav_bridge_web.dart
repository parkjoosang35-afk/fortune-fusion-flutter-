// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:js_util' as js_util;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../router/app_navigator_key.dart';

/// [PC 랜딩 연동] 랜딩(부모 윈도우)에서 온 `postMessage`를 받아 전역
/// Navigator로 라우팅한다. `main()`에서 앱 시작 시 1회 호출한다.
///
/// 메시지 형식: `{ type: 'sintong:navigate', route: '/jeontong/input' }`
/// - `type`이 다르면 무시(다른 목적의 postMessage와 섞이지 않도록).
/// - 보안: 이 앱이 iframe으로 떠 있을 때(`window.parent != window`)만
///   유효하며, 발신 origin이 이 페이지와 **동일 origin**일 때만 수락한다
///   (README §7-1 "반드시 같은 도메인" 전제와 일치 — 다른 사이트가 보낸
///   메시지로 임의 네비게이션되는 것을 방지).
void initWebNavBridge() {
  html.window.addEventListener('message', (html.Event event) {
    if (event is! html.MessageEvent) return;
    try {
      // 동일 origin에서 온 메시지만 수락(랜딩과 앱은 같은 도메인 배포 전제).
      if (event.origin.isNotEmpty && event.origin != html.window.location.origin) {
        return;
      }
      final data = event.data;
      if (data == null) return;
      // [버그수정] `dart:html`은 postMessage로 전달된 일반 JS 객체를
      // structured-clone 과정에서 Dart `Map`(LinkedHashMap)으로 자동
      // 변환하는 경우가 있다. 이 경우 `js_util.getProperty`(순수 JS 객체
      // 전용)로 읽으면 항상 null이 되어 메시지가 조용히 무시된다
      // (실측으로 확인된 원인). `Map`과 순수 JS 객체 양쪽을 모두
      // 지원하도록 분기한다.
      final Object? type;
      final Object? route;
      if (data is Map) {
        type = data['type'];
        route = data['route'];
      } else {
        type = js_util.getProperty(data, 'type');
        route = js_util.getProperty(data, 'route');
      }
      if (type != 'sintong:navigate') return;
      if (route is! String) return;
      final String routeName = route;
      if (routeName.isEmpty) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final navState = appNavigatorKey.currentState;
        if (navState == null) return;
        // [중복 스택 방지] 같은 네비게이션 레벨에서 메뉴를 반복 클릭해도
        // 화면이 계속 쌓이지 않도록, 현재 스택을 비우고 새 라우트로
        // 교체한다(스플래시/홈 등 하위 화면이 겹겹이 쌓이는 것을 방지).
        navState.pushNamedAndRemoveUntil(routeName, (r) => false);
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[WebNavBridge] 수신 메시지 처리 실패: $e');
      }
    }
  });
}

/// [PC 랜딩 연동 — 반대 방향] 앱 내부에서 라우트가 바뀔 때마다 부모
/// 윈도우(랜딩 페이지)에 현재 라우트 이름을 알려준다. 랜딩은 이를 받아
/// 왼쪽 메뉴 선택 상태와 배경 테마를 따라 바꾼다(README §7-3 "반대 방향
/// 동기화").
///
/// [구현 — NavigatorObserver 대신 route name 직접 전송]
/// 처음에는 `NavigatorObserver.didPush` 등으로 구현했으나, 실측 결과
/// `AppRouter._page()` 헬퍼(기존 코드, 79곳에서 사용 중)가
/// `MaterialPageRoute(builder: ...)`를 `settings` 없이 생성하고 있어
/// `route.settings.name`이 **항상 null**이었다(Observer 콜백 자체는
/// 정상 호출되지만 라우트 이름을 알 수 없어 무용지물). 기존 라우터
/// 로직(79곳)을 건드리는 대신, [notifyRouteName]을 `onGenerateRoute`
/// 호출 시점에 직접 불러 그 시점에 들어오는 `RouteSettings.name`(이
/// 값은 항상 정상적으로 채워져 있음 — `switch (settings.name)`으로
/// 라우팅하는 데 쓰이는 값이라 당연히 non-null)을 그대로 전달한다.
void notifyRouteName(String? name) {
  if (name == null) return;
  try {
    if (html.window.parent == html.window) return; // standalone, iframe 아님
    final payload = js_util.jsify({'type': 'sintong:route-changed', 'route': name});
    html.window.parent?.postMessage(payload, '*');
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[WebNavBridge] 전송 실패: $e');
    }
  }
}

/// [호환용] app.dart가 `navigatorObservers`에 넣을 수 있는 빈 Observer.
/// 실질적인 알림은 [notifyRouteName]이 담당하므로 이 클래스는 아무 것도
/// 하지 않는다(다른 플랫폼의 WebNavBridgeObserver와 타입을 맞추기 위한
/// 자리 표시자).
class WebNavBridgeObserver extends NavigatorObserver {}
