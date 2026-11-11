import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/zoom/pinch_zoom_exclusion.dart';

/// Android/iOS 플랫폼 구현: 제휴사 원본 광고 태그(HTML/iframe/script)를
/// `webview_flutter`의 [WebViewController.loadHtmlString]으로 렌더링한다.
///
/// Web 구현(`ad_script_view_web.dart`)과 달리 네이티브 플랫폼에는 진짜 브라우징
/// 컨텍스트(WebView)가 있으므로, innerHTML 우회 없이 그대로 `<script>` 태그가
/// 포함된 HTML 문서를 로드해도 정상적으로 실행된다.
Widget buildAdScriptView(String html, {required double height}) {
  final wrapped = _wrapHtmlDocument(html.trim());

  final controller = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setBackgroundColor(Colors.transparent)
    ..loadHtmlString(wrapped);

  // [신통방통 전역 핀치 확대 시스템 — 제외 구역] 광고 WebView는 네이티브
  // 플랫폼 뷰라 화면 캡처 기반 전역 확대와 호환되지 않고, 광고 영역은
  // 지시서 §6 "광고 및 결제 기능과 확대 엔진 분리" 요구에 따라 제외한다.
  return PinchZoomDisabled(
    child: SizedBox(
      height: height,
      width: double.infinity,
      child: WebViewWidget(controller: controller),
    ),
  );
}

/// 제휴사가 `<script>`/`<iframe>` 조각만 발급하는 경우가 많으므로,
/// 최소한의 HTML 뼈대(margin 제거, 배경 투명)로 감싸 로드한다.
String _wrapHtmlDocument(String bodyContent) {
  return '''
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <style>
      html, body {
        margin: 0;
        padding: 0;
        background: transparent;
        overflow: hidden;
        height: 100%;
      }
      body {
        display: flex;
        align-items: center;
        justify-content: center;
      }
    </style>
  </head>
  <body>
    $bodyContent
  </body>
</html>
''';
}
