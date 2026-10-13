import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../router/app_navigator_key.dart';

bool _initialized = false;

/// 동일 출처 부모 창이 보내는 메뉴 이동만 수락한다.
void initWebNavBridge() {
  if (_initialized) return;
  _initialized = true;
  web.window.addEventListener(
    'message',
    ((web.Event event) {
      try {
        final message = event as web.MessageEvent;
        if (web.window.parent == web.window ||
            message.origin != web.window.location.origin ||
            message.source != web.window.parent) {
          return;
        }
        final data = message.data.dartify();
        if (data is! Map || data['type'] != 'sintong:navigate') return;
        final route = data['route'];
        if (route is! String || route.isEmpty) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          appNavigatorKey.currentState?.pushNamedAndRemoveUntil(
            route,
            (_) => false,
          );
        });
        WidgetsBinding.instance.scheduleFrame();
      } catch (error) {
        if (kDebugMode) debugPrint('[WebNavBridge] 수신 실패: $error');
      }
    }).toJS,
  );
}

/// 부모 창에 현재 경로를 알린다. 다른 출처로는 전송하지 않는다.
void notifyRouteName(String? name) {
  if (name == null) return;
  try {
    if (web.window.parent == web.window) return;
    web.window.parent?.postMessage(
      {'type': 'sintong:route-changed', 'route': name}.jsify(),
      web.window.location.origin.toJS,
    );
  } catch (error) {
    if (kDebugMode) debugPrint('[WebNavBridge] 전송 실패: $error');
  }
}

class WebNavBridgeObserver extends NavigatorObserver {}
