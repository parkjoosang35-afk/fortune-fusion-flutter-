import 'package:flutter/material.dart';

/// [웹 AdSense 광고 시스템] 실제 `<ins class="adsbygoogle">` 유닛 렌더링 —
/// Non-web 구현(no-op). Android/iOS 앱 빌드에서는 이 위젯 트리에 절대
/// 도달하지 않는다([WebAdService.shouldShow]가 kIsWeb 가드로 먼저
/// 걸러낸다) — 그래도 안전하게 빈 위젯을 반환한다.
Widget buildAdSenseUnit({
  required String publisherId,
  required String adSlot,
  required double height,
  String adFormat = 'auto',
  bool fullWidthResponsive = true,
}) {
  return const SizedBox.shrink();
}
