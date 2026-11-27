import 'package:web/web.dart' as web;

/// [웹 AdSense 광고 시스템] 전역 로더 스크립트 주입 — Web 구현.
///
/// [배경] Google AdSense Auto ads(지시서 §1 "Auto Ads, In-page Ads, Anchor
/// Ads, Vignette 등")는 페이지에 단 한 번 로더 스크립트
/// (`adsbygoogle.js`)만 심어두면 그 이후 광고 배치는 Google이 페이지
/// 구조를 분석해 자동으로 결정한다. 따라서 "각 화면이 광고 코드를 직접
/// 들고 있는" 기존 안티패턴(지시서 §3 "각 화면에 AdSense 코드를 제각각
/// 삽입하지 않는다")을 피하려면, 이 로더 스크립트를 앱 전체에서 정확히
/// 1회만 `<head>`에 주입하는 단일 진입점이 필요하다 — 그 책임이 이
/// 함수다. [WebAdService.ensureInitialized]가 앱 부팅 시 1회만 호출한다.
///
/// [중복 주입 방지] Flutter 앱 자체가 SPA라 페이지를 새로 불러오는 일이
/// 없으므로 원래 1회만 호출되지만, 혹시 여러 위젯이 동시에 초기화를
/// 시도하는 경쟁 상태(race)에도 안전하도록 DOM에 이미 해당 id의 script
/// 태그가 있는지 먼저 확인한다.
const String _scriptElementId = 'adsbygoogle-loader-script';

void injectAdSenseScriptOnce(String publisherId) {
  if (publisherId.isEmpty) return; // [안전장치] 퍼블리셔 ID 없이는 주입하지 않음.

  final existing = web.document.getElementById(_scriptElementId);
  if (existing != null) return; // 이미 주입됨 — 중복 방지.

  final script = web.HTMLScriptElement()
    ..id = _scriptElementId
    ..async = true
    ..src =
        'https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js'
        '?client=$publisherId'
    ..crossOrigin = 'anonymous';
  web.document.head?.appendChild(script);
}
