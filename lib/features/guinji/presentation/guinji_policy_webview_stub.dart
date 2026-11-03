import 'package:flutter/material.dart';

/// 조건부 임포트용 기본(stub) 구현. 실제로는 guinji_policy_webview_web.dart
/// 또는 guinji_policy_webview_mobile.dart 중 하나로 대체된다(테스트 환경 등).
class PolicyWebView extends StatelessWidget {
  const PolicyWebView({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
