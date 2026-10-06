import 'package:flutter/material.dart';

import '../web_ad_config.dart';
import '../web_ad_service.dart';
import '../web_ad_unit.dart';
import 'web_ad_placeholder.dart';

/// [웹 AdSense 광고 시스템 — STEP D] 공통 In-page(네이티브형) 광고 위젯.
///
/// [배경] AdSense "In-page ads"는 콘텐츠 흐름 중간에 네이티브처럼
/// 자연스럽게 섞여 들어가는 포맷이다(지시서 §1). `WebAdBanner`와 DOM
/// 구조는 유사하지만(둘 다 `<ins class="adsbygoogle">`), 의미상 "리스트/
/// 스크롤 피드 중간에 삽입되는 광고"를 나타내는 별도 위젯으로 분리해
/// 호출부 코드의 의도를 명확히 한다 — 예: 정통사주 화면⑧(MoreStories)
/// 카드 리스트 사이.
///
/// [지시서 §5] 리스트 아이템처럼 보이되, 터치 시 실제로는 광고로
/// 이동한다는 점을 사용자가 오인하지 않도록 상위 호출부가 "광고"
/// 라벨을 함께 배치하는 것을 권장한다(이 위젯 자체는 강제하지 않음 —
/// AdSense 네이티브 포맷이 자체적으로 "Ads by Google" 표시를 포함).
class WebAdInPage extends StatelessWidget {
  const WebAdInPage({
    super.key,
    required this.surface,
    required this.adSlot,
    this.height = 280,
  });

  final WebAdSurface surface;
  final String adSlot;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (WebAdService.shouldShow(surface, WebAdFormat.inPage)) {
      return buildAdSenseUnit(
        publisherId: WebAdConfig.publisherId,
        adSlot: adSlot,
        height: height,
        adFormat: 'fluid',
      );
    }
    if (WebAdService.shouldShowPlaceholder(surface, WebAdFormat.inPage)) {
      return WebAdPlaceholder(height: height, label: 'IN-PAGE');
    }
    return const SizedBox.shrink();
  }
}
