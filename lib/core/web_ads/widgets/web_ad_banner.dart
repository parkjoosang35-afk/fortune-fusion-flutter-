import 'package:flutter/material.dart';

import '../web_ad_config.dart';
import '../web_ad_service.dart';
import '../web_ad_unit.dart';
import 'web_ad_placeholder.dart';

/// [웹 AdSense 광고 시스템 — STEP D] 공통 배너형 광고 위젯.
///
/// [배경 — 지시서 §3/§10] 각 서비스 화면(정통사주/타로/소원방/귀인지도/
/// 관상/손금)이 AdSense 코드를 직접 들고 있지 않고, 이 4개 공통 위젯
/// (`WebAdBanner`/`WebAdInPage`/`WebAdAnchor`/`WebAdVignette`) 중 하나를
/// 그냥 가져다 쓰기만 하면 된다. 실제 노출 여부 판단([WebAdService.
/// shouldShow])과 AdSense 유닛 렌더링([buildAdSenseUnit])은 모두 이
/// 위젯 내부에 캡슐화되어 있다.
///
/// [배치형 디스플레이 광고] 화면 특정 위치(예: 콘텐츠 사이)에 고정된
/// 사각형 배너. 인라인 콘텐츠 흐름에 자연스럽게 들어가도록 세로 공간을
/// 명시적으로 차지한다.
///
/// [지시서 §5 "콘텐츠/버튼과 혼동 금지"] 이 위젯은 스스로 여백을 추가하지
/// 않는다 — 호출부(화면)가 다음 버튼/CTA/스크롤 영역과 충분히 떨어진
/// 위치에 배치할 책임을 진다. 위젯 자체는 광고가 아닌 다른 요소처럼 보일
/// 수 있는 배경색/테두리를 쓰지 않는다(AdSense 가이드라인 — 광고가 버튼
/// 처럼 보이게 하지 않음).
class WebAdBanner extends StatelessWidget {
  const WebAdBanner({
    super.key,
    required this.surface,
    required this.adSlot,
    this.height = 100,
  });

  /// 어느 서비스 화면에서 쓰이는지(중앙 설정 조회용).
  final WebAdSurface surface;

  /// AdSense 콘솔에서 발급받은 광고 슬롯 ID. 아직 발급 전이면 빈 문자열을
  /// 넘겨도 안전하다(shouldShow가 publisherId 체크를 먼저 하므로 실제
  /// 광고 유닛까지 도달하지 않는다).
  final String adSlot;

  final double height;

  @override
  Widget build(BuildContext context) {
    if (WebAdService.shouldShow(surface, WebAdFormat.banner)) {
      return buildAdSenseUnit(
        publisherId: WebAdConfig.publisherId,
        adSlot: adSlot,
        height: height,
      );
    }
    if (WebAdService.shouldShowPlaceholder(surface, WebAdFormat.banner)) {
      return WebAdPlaceholder(height: height, label: 'BANNER');
    }
    return const SizedBox.shrink();
  }
}
