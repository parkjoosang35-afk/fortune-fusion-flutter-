import 'package:flutter/widgets.dart';

/// 비-웹 플랫폼(Android/iOS/APK)에서는 PC 랜딩 iframe 연동이라는 개념이
/// 없으므로 완전히 no-op이다.
void initWebNavBridge() {}

/// 비-웹 플랫폼에서는 아무 동작도 하지 않는 빈 Observer.
class WebNavBridgeObserver extends NavigatorObserver {}

/// 비-웹 플랫폼에서는 no-op.
void notifyRouteName(String? name) {}
