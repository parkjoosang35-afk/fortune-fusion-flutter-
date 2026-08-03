/// [열림패스 첨부/광고소스 연동] admin_web `/api/public/open-pass/*` 공개 API
/// 응답을 그대로 반영하는 도메인 모델 모음.
///
/// 이 모델들은 어드민에서 등록한 첨부파일(배너/영상/문서)과 광고소스(리워드
/// 광고 네트워크) 값을 화면단이 하드코딩 없이 그대로 반영하기 위한 것이다.
/// 화면은 이 모델의 필드만 보고 렌더링하며, 어떤 URL/문구/광고단위ID도
/// 소스 코드에 직접 적지 않는다(anti-hardcoding 원칙).
library;

/// 첨부파일 1건 — 배너 이미지, 영상, 문서(PDF/HTML) 등 7종 fileType 대응.
class OpenPassAttachmentModel {
  final int id;
  final String fileName;
  final String fileType;
  final String purpose;
  final String? fileUrl;
  final String? thumbnailUrl;
  final String? mimeType;
  final int? fileSize;
  final String? htmlContent;

  const OpenPassAttachmentModel({
    required this.id,
    required this.fileName,
    required this.fileType,
    required this.purpose,
    this.fileUrl,
    this.thumbnailUrl,
    this.mimeType,
    this.fileSize,
    this.htmlContent,
  });

  bool get isImage => fileType == 'image' || fileType == 'ad_fallback_image';
  bool get isVideo => fileType == 'video';
  bool get isDocument => fileType == 'pdf' || fileType == 'document';
  bool get isHtml => fileType == 'html' || htmlContent != null;

  static OpenPassAttachmentModel? fromJsonOrNull(dynamic json) {
    if (json == null) return null;
    return OpenPassAttachmentModel.fromJson(json as Map<String, dynamic>);
  }

  factory OpenPassAttachmentModel.fromJson(Map<String, dynamic> json) {
    return OpenPassAttachmentModel(
      id: json['id'] as int,
      fileName: json['fileName'] as String? ?? '',
      fileType: json['fileType'] as String? ?? 'image',
      purpose: json['purpose'] as String? ?? '',
      fileUrl: json['fileUrl'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      mimeType: json['mimeType'] as String?,
      fileSize: json['fileSize'] as int?,
      htmlContent: json['htmlContent'] as String?,
    );
  }
}

/// 상품에 연결된 첨부파일 그룹(hero/promo/fallback + 용도별 목록).
class OpenPassDisplayConfigModel {
  final OpenPassAttachmentModel? hero;
  final OpenPassAttachmentModel? promo;
  final OpenPassAttachmentModel? fallback;
  final Map<String, List<OpenPassAttachmentModel>> byUsageType;

  const OpenPassDisplayConfigModel({
    this.hero,
    this.promo,
    this.fallback,
    this.byUsageType = const {},
  });

  static const empty = OpenPassDisplayConfigModel();

  factory OpenPassDisplayConfigModel.fromJson(Map<String, dynamic> json) {
    final rawByUsage = json['byUsageType'] as Map<String, dynamic>? ?? {};
    final byUsage = <String, List<OpenPassAttachmentModel>>{};
    rawByUsage.forEach((key, value) {
      byUsage[key] = (value as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(OpenPassAttachmentModel.fromJson)
          .toList();
    });
    return OpenPassDisplayConfigModel(
      hero: OpenPassAttachmentModel.fromJsonOrNull(json['hero']),
      promo: OpenPassAttachmentModel.fromJsonOrNull(json['promo']),
      fallback: OpenPassAttachmentModel.fromJsonOrNull(json['fallback']),
      byUsageType: byUsage,
    );
  }
}

/// 상품에 연결된 광고소스 1건(우선순위/대표 여부/현재 시청 가능 여부 포함).
/// 서버(`resolveProductAdConfig`)가 쿨다운/일일한도를 이미 계산해 [eligible]로
/// 내려주므로, 앱은 이 값을 그대로 신뢰하고 임의로 재판단하지 않는다.
class OpenPassAdSourceBindingModel {
  final int bindingId;
  final int adSourceId;
  final String sourceName;
  final String sourceType;
  final String? networkName;
  final String? adUnitId;
  final String? placementId;
  final String? rewardType;
  final int? rewardValue;
  final int cooldownSeconds;
  final int? dailyLimit;
  final bool testModeEnabled;
  final int priority;
  final bool isPrimary;
  final String platform;
  final bool? eligible;
  final String? eligibilityReason;

  /// [프리패스 테스트 인프라] §4 — sourceType이 `mock_rewarded_*`인 테스트
  /// 전용 광고소스인지 여부. true면 실제 광고 SDK 대신
  /// [RewardedAdSimulator]가 [simulatedDurationSeconds]/[failMode] 값을
  /// 그대로 사용해 결정적으로(deterministic) 동작한다.
  final bool isMock;
  final int? simulatedDurationSeconds;
  final String? failMode;

  const OpenPassAdSourceBindingModel({
    required this.bindingId,
    required this.adSourceId,
    required this.sourceName,
    required this.sourceType,
    this.networkName,
    this.adUnitId,
    this.placementId,
    this.rewardType,
    this.rewardValue,
    required this.cooldownSeconds,
    this.dailyLimit,
    required this.testModeEnabled,
    required this.priority,
    required this.isPrimary,
    required this.platform,
    this.eligible,
    this.eligibilityReason,
    this.isMock = false,
    this.simulatedDurationSeconds,
    this.failMode,
  });

  /// 서버가 eligible을 계산하지 않은 경우(userId 미전달)에는 null이며,
  /// 이때는 "우선 시도 가능"으로 간주한다(실제 판정은 reward-complete가 최종 수행).
  bool get isUsable => eligible != false;

  factory OpenPassAdSourceBindingModel.fromJson(Map<String, dynamic> json) {
    return OpenPassAdSourceBindingModel(
      bindingId: json['bindingId'] as int,
      adSourceId: json['adSourceId'] as int,
      sourceName: json['sourceName'] as String? ?? '',
      sourceType: json['sourceType'] as String? ?? '',
      networkName: json['networkName'] as String?,
      adUnitId: json['adUnitId'] as String?,
      placementId: json['placementId'] as String?,
      rewardType: json['rewardType'] as String?,
      rewardValue: json['rewardValue'] as int?,
      cooldownSeconds: json['cooldownSeconds'] as int? ?? 0,
      dailyLimit: json['dailyLimit'] as int?,
      testModeEnabled: json['testModeEnabled'] as bool? ?? false,
      priority: json['priority'] as int? ?? 0,
      isPrimary: json['isPrimary'] as bool? ?? false,
      platform: json['platform'] as String? ?? 'all',
      eligible: json['eligible'] as bool?,
      eligibilityReason: json['eligibilityReason'] as String?,
      isMock: json['isMock'] as bool? ?? false,
      simulatedDurationSeconds: json['simulatedDurationSeconds'] as int?,
      failMode: json['failMode'] as String?,
    );
  }
}

/// GET /api/public/open-pass/products 목록 항목.
class OpenPassProductModel {
  final int id;
  final String name;
  final String passType;
  final int durationMin;
  final int? dailyLimit;
  final String? description;
  final List<String> scope;
  final int? happyMoneyPrice;
  final bool adRewardEnabled;
  final bool isFeatured;
  final int displayPriority;
  final Map<String, dynamic>? uiCopy;
  final OpenPassAttachmentModel? heroAttachment;
  final OpenPassAttachmentModel? promoAttachment;

  const OpenPassProductModel({
    required this.id,
    required this.name,
    required this.passType,
    required this.durationMin,
    this.dailyLimit,
    this.description,
    this.scope = const [],
    this.happyMoneyPrice,
    required this.adRewardEnabled,
    this.isFeatured = false,
    this.displayPriority = 0,
    this.uiCopy,
    this.heroAttachment,
    this.promoAttachment,
  });

  factory OpenPassProductModel.fromJson(Map<String, dynamic> json) {
    return OpenPassProductModel(
      id: json['id'] as int,
      name: json['name'] as String,
      passType: json['passType'] as String? ?? 'ad',
      durationMin: json['durationMin'] as int? ?? 60,
      dailyLimit: json['dailyLimit'] as int?,
      description: json['description'] as String?,
      scope: (json['scope'] as List<dynamic>?)?.cast<String>() ?? const [],
      happyMoneyPrice: json['happyMoneyPrice'] as int?,
      adRewardEnabled: json['adRewardEnabled'] as bool? ?? false,
      isFeatured: json['isFeatured'] as bool? ?? false,
      displayPriority: json['displayPriority'] as int? ?? 0,
      uiCopy: json['uiCopy'] as Map<String, dynamic>?,
      heroAttachment: OpenPassAttachmentModel.fromJsonOrNull(
        json['heroAttachment'],
      ),
      promoAttachment: OpenPassAttachmentModel.fromJsonOrNull(
        json['promoAttachment'],
      ),
    );
  }
}

/// GET /api/public/open-pass/products/{id} 상세 응답.
class OpenPassProductDetailModel {
  final OpenPassProductModel product;
  final OpenPassDisplayConfigModel displayConfig;
  final List<OpenPassAdSourceBindingModel> adSources;

  const OpenPassProductDetailModel({
    required this.product,
    required this.displayConfig,
    required this.adSources,
  });

  /// 지금 시도 가능한 광고소스(우선순위 1순위) — 없으면 null(광고 버튼 비노출).
  OpenPassAdSourceBindingModel? get nextEligibleAdSource {
    for (final a in adSources) {
      if (a.isUsable) return a;
    }
    return null;
  }

  factory OpenPassProductDetailModel.fromJson(Map<String, dynamic> json) {
    return OpenPassProductDetailModel(
      product: OpenPassProductModel.fromJson(json),
      displayConfig: json['displayConfig'] != null
          ? OpenPassDisplayConfigModel.fromJson(
              json['displayConfig'] as Map<String, dynamic>,
            )
          : OpenPassDisplayConfigModel.empty,
      adSources: (json['adSources'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(OpenPassAdSourceBindingModel.fromJson)
          .toList(),
    );
  }
}

/// POST /api/public/open-pass/reward-complete 성공 응답.
class OpenPassRewardGrantModel {
  final int userPassId;
  final int policyId;
  final String? policyName;
  final DateTime expiresAt;
  final int remainingSec;
  final bool idempotent;

  const OpenPassRewardGrantModel({
    required this.userPassId,
    required this.policyId,
    this.policyName,
    required this.expiresAt,
    required this.remainingSec,
    this.idempotent = false,
  });

  factory OpenPassRewardGrantModel.fromJson(
    Map<String, dynamic> json, {
    bool idempotent = false,
  }) {
    return OpenPassRewardGrantModel(
      userPassId: json['userPassId'] as int,
      policyId: json['policyId'] as int,
      policyName: json['policyName'] as String?,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      remainingSec: json['remainingSec'] as int? ?? 0,
      idempotent: idempotent,
    );
  }
}

/// POST /api/public/open-pass/reward-complete 가 지급 불가로 응답했을 때의
/// 사유(쿨다운/일일한도 등) — [reason]과 [cooldownRemainingSec]는 §13
/// "쿨다운/일일한도 초과 안내" 요구사항에 대응한다.
class OpenPassRewardDeniedException implements Exception {
  final String message;
  final String? reason;
  final int? cooldownRemainingSec;

  const OpenPassRewardDeniedException(
    this.message, {
    this.reason,
    this.cooldownRemainingSec,
  });

  @override
  String toString() => message;
}

/// POST /api/public/open-pass/reward-failed 응답 — 광고 실패/노필 시
/// 표시할 대체 크리에이티브 + 대안 CTA(복주머니 구매) 정보.
class OpenPassRewardFailedModel {
  final String reason;
  final OpenPassAttachmentModel? fallbackAttachment;
  final bool alternateCtaHappyMoneyPurchase;
  final int? happyMoneyPrice;

  const OpenPassRewardFailedModel({
    required this.reason,
    this.fallbackAttachment,
    required this.alternateCtaHappyMoneyPurchase,
    this.happyMoneyPrice,
  });

  factory OpenPassRewardFailedModel.fromJson(Map<String, dynamic> json) {
    return OpenPassRewardFailedModel(
      reason: json['reason'] as String? ?? 'ad_fail',
      fallbackAttachment: OpenPassAttachmentModel.fromJsonOrNull(
        json['fallbackAttachment'],
      ),
      alternateCtaHappyMoneyPurchase:
          json['alternateCtaHappyMoneyPurchase'] as bool? ?? false,
      happyMoneyPrice: json['happyMoneyPrice'] as int?,
    );
  }
}
