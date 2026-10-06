import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// [웹 AdSense 광고 시스템] 실제 `<ins class="adsbygoogle">` 유닛 렌더링 —
/// Web 구현.
///
/// [배경] AdSense 디스플레이 광고 유닛은 `<ins class="adsbygoogle">` 태그 +
/// 그 바로 뒤에 `(adsbygoogle = window.adsbygoogle || []).push({})` 호출
/// 조합으로 표시된다. Flutter Web은 임의 DOM을 위젯 트리에 직접 넣을 수
/// 없으므로, 기존 `ad_script_view_web.dart`(제휴 배너)와 동일한
/// `dart:ui_web platformViewRegistry.registerViewFactory` 패턴으로 실제
/// DOM 엘리먼트를 Flutter 캔버스 위에 오버레이하는 `HtmlElementView`를
/// 쓴다 — 신규 패턴을 만들지 않고 기존에 검증된 접근을 재사용한다.
///
/// [슬롯별 캐싱] 같은 adSlot으로 위젯이 재빌드되어도 viewFactory를
/// 중복 등록(예외 발생)하지 않도록 방어한다.
///
/// [push 호출 방식] 타입이 있는 `package:web` JS interop으로 전역
/// `adsbygoogle` 배열을 직접 다루는 대신, `<ins>` 바로 뒤에 작은
/// `<script>`를 srcdoc iframe 없이 바로 추가하면 (innerHTML 경로는
/// script를 실행하지 않는) 브라우저 제약에 걸린다. 그래서 `document`에
/// 직접 script 엘리먼트를 생성해 DOM에 append하는 표준 방식을 쓴다 —
/// 이 방식은 (innerHTML 대입이 아니라) 실제 엘리먼트 생성이므로 모든
/// 브라우저에서 정상적으로 실행된다.
final Set<String> _registeredViewTypes = {};

Widget buildAdSenseUnit({
  required String publisherId,
  required String adSlot,
  required double height,
  String adFormat = 'auto',
  bool fullWidthResponsive = true,
}) {
  final viewType = 'adsense-unit-$adSlot';

  if (!_registeredViewTypes.contains(viewType)) {
    _registeredViewTypes.add(viewType);
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final container = web.HTMLDivElement()
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.overflow = 'hidden';

      final ins = web.document.createElement('ins') as web.HTMLElement
        ..className = 'adsbygoogle'
        ..style.display = 'block'
        ..setAttribute('data-ad-client', publisherId)
        ..setAttribute('data-ad-slot', adSlot)
        ..setAttribute('data-ad-format', adFormat)
        ..setAttribute(
          'data-full-width-responsive',
          fullWidthResponsive ? 'true' : 'false',
        );
      container.appendChild(ins);

      // adsbygoogle.js(전역 로더, WebAdService.ensureInitialized가 이미
      // <head>에 주입해 둔 상태)에게 "이 자리에 광고를 채워 달라"고
      // 요청한다. 실제 엘리먼트로 <script>를 생성해 append하면(innerHTML
      // 대입이 아니므로) 브라우저가 정상적으로 실행한다.
      final pushScript = web.document.createElement('script')
          as web.HTMLScriptElement
        ..text =
            '(window.adsbygoogle = window.adsbygoogle || []).push({});';
      container.appendChild(pushScript);

      return container;
    });
  }

  return SizedBox(
    height: height,
    width: double.infinity,
    child: HtmlElementView(viewType: viewType),
  );
}
