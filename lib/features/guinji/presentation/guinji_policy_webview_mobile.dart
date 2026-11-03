import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_loading)
          const Center(
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
      ],
    );
  }
}
