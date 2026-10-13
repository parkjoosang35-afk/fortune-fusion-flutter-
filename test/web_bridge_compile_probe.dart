// 로컬 컴파일 검증 전용. 운영 main.dart를 대체하지 않는다.
import 'package:flutter/material.dart';
import '../lib/core/router/app_navigator_key.dart';
import '../lib/core/web/web_nav_bridge_web.dart';
import '../lib/core/util/safe_share.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  initWebNavBridge();
  runApp(MaterialApp(
    navigatorKey: appNavigatorKey,
    onGenerateRoute: (settings) {
      notifyRouteName(settings.name);
      return MaterialPageRoute<void>(settings: settings, builder: (context) => Scaffold(
        appBar: AppBar(title: const Text('로컬 웹 브리지 검증')),
        body: TextButton(onPressed: () => safeShareText(context, 'http://localhost/result'), child: const Text('공유 시험')),
      ));
    },
  ));
}
