// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;

import 'package:flutter/foundation.dart';

import '../router/app_navigator_key.dart';

bool _initialized = false;
StreamSubscription<html.PopStateEvent>? _sub;

/// [브라우저 뒤로가기 버그수정] `main()`에서 앱 시작 시 1회 호출한다.
/// 자세한 배경은 `browser_back_bridge.dart`의 문서 주석 참고.
void initBrowserBackBridge() {
  if (_initialized) return;
  _initialized = true;
  try {
    // 가드용 히스토리 엔트리 — URL은 그대로 유지한 채(해시/경로 변경 없음)
    // "뒤로 갈 수 있는 상태"만 하나 만들어 둔다. 이 앱의 Navigator 1.0
    // 라우팅은 `settings.name`이 전부 null이라 자체적으로 pushState를
    // 호출하지 않으므로, 이 엔트리가 없으면 세션 전체에서 뒤로가기가
    // 갈 곳이 아예 없는 상태가 된다.
    html.window.history.pushState(null, '', html.window.location.href);
    _sub = html.window.onPopState.listen((html.PopStateEvent event) {
      try {
        // 브라우저가 방금 위 가드 엔트리를 소비했다 — 즉시 다시 쌓아서
        // "항상 뒤로 갈 곳이 있는" 상태를 유지한다(그렇지 않으면 다음
        // 뒤로가기 누름부터는 앱을 완전히 벗어나(랜딩 페이지 등) 버린다).
        html.window.history.pushState(null, '', html.window.location.href);
        // Android 하드웨어 백버튼과 완전히 동일한 경로로 위임한다. 각
        // 화면의 PopScope/WillPopScope가 이미 처리하고 있는 커스텀 복귀
        // 전환(예: 정통사주 다크 오버레이 페이드아웃)을 그대로 재사용한다.
        appNavigatorKey.currentState?.maybePop();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[BrowserBackBridge] popstate 처리 실패: $e');
        }
      }
    });
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[BrowserBackBridge] 초기화 실패: $e');
    }
  }
}
