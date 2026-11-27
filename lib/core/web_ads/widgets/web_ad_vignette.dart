import 'package:flutter/material.dart';

import '../web_ad_config.dart';
import '../web_ad_service.dart';

/// [웹 AdSense 광고 시스템 — STEP D] 공통 Vignette(전면 전환) 광고 트리거.
///
/// [배경] Vignette ads는 페이지 전환(예: 정통사주 화면②→③→④ 같은
/// Navigator 전환) 사이에 Google이 자체적으로 전면 광고를 끼워 넣는
/// Auto ads 포맷이다. Anchor와 마찬가지로 `<ins>` 슬롯이 아니라 전역
/// 신호 1회 push 방식이다.
///
/// [호출 위치 권장] 화면 전환이 빈번한 플로우(정통사주 입력→계산→결과
/// 같은 다단계 스텝)의 "진입점 화면"(예: 정통사주 메인/인트로)에서
/// 1회만 트리거하면 된다 — 매 화면마다 중복 호출할 필요 없다
/// (`enablePageLevelAdsOnce` 내부에서 adType당 1회 제한).
///
/// [지시서 §5 — 절대 원칙] Vignette는 전면 광고라 자칫 "다음 버튼을
/// 눌렀는데 광고인지 결과 화면인지 헷갈리는" 상황을 만들 수 있다.
/// Google의 Auto ads 엔진이 과도한 빈도로 띄우지 않도록 자체 조절하지만,
/// STEP F에서 정통사주의 각 전환 지점(특히 계산 세레모니→FOUND 전환
/// 직후)에 실제로 끼어들 때 사용자가 "결과 보기 버튼"과 혼동하지
/// 않는지 반드시 실기기로 확인해야 한다.
///
/// 이 위젯은 레이아웃 공간을 전혀 차지하지 않는 순수 트리거이므로
/// `SizedBox.shrink()`만 반환한다 — 화면 어디에 배치해도 레이아웃에
/// 영향이 없다.
class WebAdVignette extends StatefulWidget {
  const WebAdVignette({super.key, required this.surface});

  final WebAdSurface surface;

  @override
  State<WebAdVignette> createState() => _WebAdVignetteState();
}

class _WebAdVignetteState extends State<WebAdVignette> {
  @override
  void initState() {
    super.initState();
    WebAdService.enablePageLevelAd(widget.surface, WebAdFormat.vignette);
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
