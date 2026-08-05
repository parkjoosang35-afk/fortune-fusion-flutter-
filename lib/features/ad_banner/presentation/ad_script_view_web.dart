import 'dart:js_interop';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// Web 플랫폼 구현: 제휴사 원본 광고 태그(HTML/iframe/script)를 그대로 DOM에 삽입한다.
///
/// [배경] Flutter Web은 임의의 <iframe>/<script> 태그를 위젯 트리에 직접 넣을 수 없으므로,
/// `dart:ui_web`의 `platformViewRegistry.registerViewFactory`를 이용해 실제 DOM 엘리먼트를
/// Flutter 캔버스 위에 오버레이하는 `HtmlElementView`로 렌더링한다.
/// 같은 광고소스 문자열은 동일한 viewType으로 캐싱해, 위젯이 재빌드되어도 팩토리를
/// 중복 등록(예외 발생)하지 않도록 방어한다.
///
/// [주의] `innerHTML`로 삽입되는 <script> 태그는 브라우저 명세상 실행되지 않으므로,
/// 제휴사가 <script>만 발급하는 경우(예: 문서 write 방식)에는 <iframe srcdoc="..."> 로
/// 한 번 더 감싸 실제 실행이 되도록 처리한다. <iframe> 자체를 발급하는 경우(쿠팡파트너스
/// 등 대부분의 위젯형 배너)는 innerHTML만으로 정상 동작한다.
final Set<String> _registeredViewTypes = {};

Widget buildAdScriptView(String html, {required double height}) {
  final viewType = 'ad-script-${html.hashCode}';

  if (!_registeredViewTypes.contains(viewType)) {
    _registeredViewTypes.add(viewType);
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final container = web.HTMLDivElement()
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.overflow = 'hidden'
        // 광고 소스(iframe 등)가 자체 고정폭을 가진 경우 기본적으로 좌측 정렬되므로,
        // flex 중앙 정렬로 감싸 컨테이너 안에서 항상 가운데 표시되도록 한다.
        ..style.display = 'flex'
        ..style.alignItems = 'center'
        ..style.justifyContent = 'center';

      final trimmed = html.trim();
      final containsScriptTag = trimmed.toLowerCase().contains('<script');

      if (containsScriptTag) {
        // <script> 태그가 포함된 경우 innerHTML로는 실행되지 않으므로,
        // srcdoc iframe으로 감싸 별도 브라우징 컨텍스트에서 실행되게 한다.
        final iframe = web.HTMLIFrameElement()
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.border = 'none'
          ..srcdoc = trimmed.toJS
          ..setAttribute('scrolling', 'no');
        container.appendChild(iframe);
      } else {
        // <iframe> 원본 태그 등은 innerHTML로 바로 삽입 가능.
        container.innerHTML = trimmed.toJS;
      }
      return container;
    });
  }

  return SizedBox(
    height: height,
    width: double.infinity,
    child: HtmlElementView(viewType: viewType),
  );
}
