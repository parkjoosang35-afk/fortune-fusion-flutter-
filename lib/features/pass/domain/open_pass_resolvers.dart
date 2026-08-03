import '../domain/open_pass_models.dart';

/// [열림패스 첨부/광고소스 연동] 첨부파일 선택 리졸버.
///
/// 서버(`resolveProductDisplayConfig`)가 이미 hero/promo/fallback을 계산해
/// 내려주지만, 화면이 "지금 이 시점에 보여줄 배너가 무엇인지"를 매번
/// null 체크로 흩어서 판단하지 않도록 한 곳에 모은다. 값이 전혀 없으면
/// null을 반환하며(하드코딩된 대체 이미지를 쓰지 않음), 화면은 이 경우
/// 기본 안내 문구만 노출한다.
class OpenPassAttachmentResolver {
  const OpenPassAttachmentResolver._();

  /// 상품 CTA 카드/바텀시트 상단에 노출할 배너. 프로모 배너를 우선하고,
  /// 없으면 대표(히어로) 배너로 대체한다.
  static OpenPassAttachmentModel? resolvePromoBanner(
    OpenPassDisplayConfigModel config,
  ) {
    return config.promo ?? config.hero;
  }

  /// 광고 시청 실패/노필 시 노출할 대체 크리에이티브.
  /// 없으면 null(화면이 기본 안내 문구로 대체).
  static OpenPassAttachmentModel? resolveFallbackCreative(
    OpenPassDisplayConfigModel config,
  ) {
    return config.fallback;
  }

  /// 특정 용도(usageType)에 해당하는 첨부 목록(광고 시청 후 배너 등).
  static List<OpenPassAttachmentModel> resolveByUsage(
    OpenPassDisplayConfigModel config,
    String usageType,
  ) {
    return config.byUsageType[usageType] ?? const [];
  }
}

/// [열림패스 첨부/광고소스 연동] 광고소스 선택 리졸버.
///
/// 서버가 이미 우선순위(대표 1개 우선 -> priority 오름차순)와 사용자별
/// 시청 가능 여부(eligible)를 계산해 내려주므로(§15: 앱이 임의로 쿨다운/
/// 일일한도를 재판단하지 않는다), 이 리졸버는 그 결과에서 "지금 시도할
/// 1개"를 뽑아내는 얇은 선택 로직만 담당한다.
class OpenPassAdSourceResolver {
  const OpenPassAdSourceResolver._();

  /// 지금 시청 가능한(eligible != false) 광고소스 중 최우선 1개.
  /// 전부 시청 불가 상태라도 목록이 비어있지 않으면, 사용자 안내/로깅 목적으로
  /// 최우선 1개를 "시도 대상"으로 반환한다(호출부가 eligible 여부를 별도 확인).
  static OpenPassAdSourceBindingModel? pickAttemptTarget(
    List<OpenPassAdSourceBindingModel> sources,
  ) {
    if (sources.isEmpty) return null;
    for (final s in sources) {
      if (s.isUsable) return s;
    }
    // 전부 불가 상태 — 대표(or 최우선) 소스를 반환해 실패 사유를 그대로 노출.
    return sources.first;
  }

  /// [bindingId]를 제외한 다음 대체 광고소스(1차 실패 시 재시도용).
  static OpenPassAdSourceBindingModel? pickNextAfterFailure(
    List<OpenPassAdSourceBindingModel> sources,
    int excludeAdSourceId,
  ) {
    for (final s in sources) {
      if (s.adSourceId == excludeAdSourceId) continue;
      if (s.isUsable) return s;
    }
    return null;
  }
}
