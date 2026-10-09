// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;

import 'package:flutter/foundation.dart';

import '../router/app_navigator_key.dart';

bool _initialized = false;
StreamSubscription<html.PopStateEvent>? _sub;

/// [버그수정 — 정통사주 메인 화면 뒤로가기 시 "Maximum call stack size
/// exceeded" 화면 깨짐] 동영상으로 재현 확인된 증상: 정통사주 메인에서
/// 뒤로가기(←버튼)를 누르면 화면이 잠깐 검게 변하며 `RangeError: Maximum
/// call stack size exceeded`와 대량의 스택 트레이스 숫자가 노출된 뒤
/// 홈으로 튕기듯 복귀한다.
///
/// [근본 원인] 아래 `onPopState` 핸들러는 콜백 안에서 **동기적으로**
/// `history.pushState()`를 다시 호출한다. 표준 브라우저에서는 이것이
/// 안전하지만, 이 앱이 구동되는 일부 WebView/임베디드 브라우저 환경에서는
/// `pushState` 호출이 같은 호출 스택 안에서 `popstate` 이벤트를 즉시
/// 재디스패치하는 경우가 있다. 그러면
/// `popstate → pushState() → popstate → pushState() → ...`로 이어지는
/// 완전히 동기적이고 종료 조건이 없는 재귀 호출 체인이 형성되어 JS 콜
/// 스택이 곧바로 초과된다(이 핸들러에는 재진입을 막는 장치가 전혀
/// 없었다). 정통사주 화면은 `PopScope(canPop: false)` + 커스텀 복귀
/// 오버레이를 쓰므로 `maybePop()`이 호출되는 빈도가 높아 가장 먼저
/// 눈에 띄었을 뿐, 사실상 뒤로가기를 쓰는 모든 화면에서 재현 가능한
/// 전역 버그였다.
///
/// [해결] 재진입 가드(`_handlingPopState`)를 추가해, 이 핸들러가 실행
/// 중인 동안 발생한 `popstate`(= 우리 자신의 `pushState` 호출이 유발한
/// 재귀 호출)는 즉시 무시하고 반환한다. 바깥쪽(최초) 호출만 실제로
/// `pushState`/`maybePop()`을 수행하므로 기존 "항상 뒤로 갈 곳이 있는"
/// 동작은 그대로 유지되면서 재귀 폭발만 차단된다.
bool _handlingPopState = false;

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
      // [재귀 폭발 차단] 이 핸들러 안의 pushState가 동기적으로 popstate를
      // 재유발하는 환경에서, 그 재귀 호출을 여기서 즉시 끊는다.
      if (_handlingPopState) return;
      _handlingPopState = true;
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
      } finally {
        // 현재 호출 스택이 완전히 풀린 뒤(다음 이벤트 루프 틱)에야 가드를
        // 해제한다 — pushState가 유발하는 popstate가 "동기"이든 "마이크로/
        // 매크로태스크로 지연"되든 전부 안전하게 걸러내기 위해
        // microtask보다 더 뒤인 timer(0ms)를 사용한다.
        Future<void>.delayed(Duration.zero, () {
          _handlingPopState = false;
        });
      }
    });
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[BrowserBackBridge] 초기화 실패: $e');
    }
  }
}
