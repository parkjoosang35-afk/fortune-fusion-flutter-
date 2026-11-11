import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../../../core/zoom/pinch_zoom_exclusion.dart';

/// Web 플랫폼 구현 — `dart:ui_web`의 `platformViewRegistry`로 실제
/// `<iframe src="...">`를 Flutter 캔버스 위에 오버레이한다.
/// `ad_banner`의 `ad_script_view_web.dart`와 동일한 기법(HtmlElementView).
/// admin_web의 `/terms`·`/privacy-policy`는 이미 독립적인 완전한 페이지이므로
/// `srcdoc` 조합 없이 `src`로 바로 로드하면 된다.
final Set<String> _registeredViewTypes = {};

class PolicyWebView extends StatelessWidget {
  const PolicyWebView({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final viewType = 'guinji-policy-iframe-${url.hashCode}';

    if (!_registeredViewTypes.contains(viewType)) {
      _registeredViewTypes.add(viewType);
      ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
        final iframe = web.HTMLIFrameElement()
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.border = 'none'
          ..src = url;
        return iframe;
      });
    }

    // [신통방통 전역 핀치 확대 시스템 — 제외 구역] Flutter Web의 플랫폼
    // 뷰(HtmlElementView는 실제 DOM 요소)는 별도 합성 레이어로 렌더링되어
    // RenderRepaintBoundary.toImage() 캐처에 포함되지 않거나 빈 영역으로
    // 나타나므로 제외한다.
    return PinchZoomDisabled(
      child: HtmlElementView(viewType: viewType),
    );
  }
}
