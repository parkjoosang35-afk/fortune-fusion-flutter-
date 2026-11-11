import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/zoom/pinch_zoom_exclusion.dart';

/// Android/iOS 플랫폼 구현 — 실제 네이티브 WebView로 admin_web의
/// `/terms`·`/privacy-policy` 페이지를 그대로 로드한다. `ad_banner`의
/// `ad_script_view_mobile.dart`와 동일하게 `webview_flutter`를 사용한다.
class PolicyWebView extends StatefulWidget {
  const PolicyWebView({super.key, required this.url});

  final String url;

  @override
  State<PolicyWebView> createState() => _PolicyWebViewState();
}

class _PolicyWebViewState extends State<PolicyWebView> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    // [신통방통 전역 핀치 확대 시스템 — 제외 구역] 네이티브 플랫폼 뷰
    // (AndroidView/UiKitView 기반 WebView)는 별도 레이어로 합성되어
    // RenderRepaintBoundary.toImage() 캡처에 포함되지 않거나 빈 영역으로
    // 나타나는 Flutter의 알려진 제약이 있다. 또한 WebView 내부 페이지
    // 자체가 자신의 핀치줌/스크롤을 처리하므로, 전역 엔진의 스크린샷
    // 확대를 겹치면 제스처가 이중으로 해석돼 오히려 어색해진다.
    return PinchZoomDisabled(
      child: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
        ],
      ),
    );
  }
}
