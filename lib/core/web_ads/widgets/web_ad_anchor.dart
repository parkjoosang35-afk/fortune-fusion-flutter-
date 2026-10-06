import 'package:flutter/material.dart';

import '../web_ad_config.dart';
import '../web_ad_service.dart';
import 'web_ad_placeholder.dart';

/// [웹 AdSense 광고 시스템 — STEP D] 공통 Anchor(상/하단 고정) 광고 트리거.
///
/// [배경] Anchor ads는 `<ins>` 슬롯을 화면 어딘가에 직접 그리는 방식이
/// 아니라, "이 페이지에서 Anchor 자동배치를 켜 달라"는 전역 신호를
/// 한 번 보내면 Google이 화면 하단에 띠 배너를 직접 붙인다(지시서 §1
/// Auto Ads). 그래서 이 위젯은 화면 레이아웃에 실제 공간을 차지하지
/// 않고, `initState`에서 [WebAdService.enablePageLevelAd]를 1회 트리거
/// 하기만 한다 — 다만 미승인 상태(§12)에서 레이아웃 확인용 플레이스홀더
/// 가 필요하면, 화면 최하단에 이 위젯을 두어 "여기 Anchor 띠 배너 자리"
/// 임을 보여줄 수 있다(플레이스홀더만 공간을 차지, 실제 Anchor 활성화
/// 시에는 이 위젯 자체가 공간을 차지하지 않음에 주의 — Google이 자체
/// 오버레이로 그리므로 Flutter 레이아웃에 포함되지 않는다).
///
/// [지시서 §5 "콘텐츠를 가리는 위치 금지"] 실제 Anchor ads가 활성화된
/// 뒤에는 화면 최하단 고정 CTA(예: saju_renewal의 "다음"/"저장하기"
/// 버튼)와 겹치지 않는지 STEP F에서 반드시 실기기 확인이 필요하다 —
/// 이 위젯 자체는 그 겹침을 코드로 막을 수 없다(Google이 자체 렌더링).
class WebAdAnchor extends StatefulWidget {
  const WebAdAnchor({super.key, required this.surface});

  final WebAdSurface surface;

  @override
  State<WebAdAnchor> createState() => _WebAdAnchorState();
}

class _WebAdAnchorState extends State<WebAdAnchor> {
  @override
  void initState() {
    super.initState();
    WebAdService.enablePageLevelAd(widget.surface, WebAdFormat.anchor);
  }

  @override
  Widget build(BuildContext context) {
    // 실제 Anchor ads는 Google이 페이지 레벨에서 직접 오버레이하므로
    // 이 위젯 자체는 활성화된 경우 공간을 차지하지 않는다.
    if (WebAdService.shouldShow(widget.surface, WebAdFormat.anchor)) {
      return const SizedBox.shrink();
    }
    if (WebAdService.shouldShowPlaceholder(
      widget.surface,
      WebAdFormat.anchor,
    )) {
      return const WebAdPlaceholder(height: 56, label: 'ANCHOR');
    }
    return const SizedBox.shrink();
  }
}
