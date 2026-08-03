/// [메인화면 관리자 편집기] admin_web `GET /api/public/page-configs/home`
/// 응답을 그대로 반영하는 Flutter 도메인 모델.
///
/// [설계 원칙] 서버는 "발행(published)된 원본 데이터"만 그대로 내려주고,
/// hidden/archived 제외·스케줄·플랫폼·노출조건(displayRules) 평가는 전부
/// 클라이언트의 SectionVisibilityEvaluator가 수행한다(§17 앱 동작 원칙).
/// 이 모델은 그 판단에 필요한 원본 필드를 손실 없이 그대로 보관한다.
library;

/// 13개 화이트리스트 블록 타입. 서버(page-config-constants.ts BLOCK_TYPES)와
/// 정확히 동일한 문자열 값을 사용하며, 알 수 없는 값은 unknown으로 폴백한다.
enum PageBlockType {
  heroBanner,
  textBanner,
  ctaBanner,
  singleCard,
  doubleCardGrid,
  horizontalCardScroll,
  categoryShortcutRow,
  wishPreviewBlock,
  aiConsultBanner,
  passPromoBar,
  pointStatusBar,
  eventBanner,
  featuredContentBlock,
  unknown;

  static PageBlockType fromKey(String? key) {
    switch (key) {
      case 'hero_banner':
        return PageBlockType.heroBanner;
      case 'text_banner':
        return PageBlockType.textBanner;
      case 'CTA_banner':
        return PageBlockType.ctaBanner;
      case 'single_card':
        return PageBlockType.singleCard;
      case 'double_card_grid':
        return PageBlockType.doubleCardGrid;
      case 'horizontal_card_scroll':
        return PageBlockType.horizontalCardScroll;
      case 'category_shortcut_row':
        return PageBlockType.categoryShortcutRow;
      case 'wish_preview_block':
        return PageBlockType.wishPreviewBlock;
      case 'ai_consult_banner':
        return PageBlockType.aiConsultBanner;
      case 'pass_promo_bar':
        return PageBlockType.passPromoBar;
      case 'point_status_bar':
        return PageBlockType.pointStatusBar;
      case 'event_banner':
        return PageBlockType.eventBanner;
      case 'featured_content_block':
        return PageBlockType.featuredContentBlock;
      default:
        return PageBlockType.unknown;
    }
  }
}

class PageSectionAttachment {
  final String attachmentUrl;
  final String usageType; // banner|sub_banner|icon|background|external_link_asset|fallback
  final bool isPrimary;
  final int displayOrder;

  const PageSectionAttachment({
    required this.attachmentUrl,
    required this.usageType,
    required this.isPrimary,
    required this.displayOrder,
  });

  factory PageSectionAttachment.fromJson(Map<String, dynamic> json) {
    return PageSectionAttachment(
      attachmentUrl: json['attachmentUrl'] as String? ?? '',
      usageType: json['usageType'] as String? ?? 'banner',
      isPrimary: json['isPrimary'] as bool? ?? false,
      displayOrder: json['displayOrder'] as int? ?? 0,
    );
  }
}

class PageSectionDisplayRule {
  final String ruleType;
  final String ruleOperator; // equals|not_equals|gte|lte|in
  final String ruleValue;

  const PageSectionDisplayRule({
    required this.ruleType,
    required this.ruleOperator,
    required this.ruleValue,
  });

  factory PageSectionDisplayRule.fromJson(Map<String, dynamic> json) {
    return PageSectionDisplayRule(
      ruleType: json['ruleType'] as String? ?? '',
      ruleOperator: json['ruleOperator'] as String? ?? 'equals',
      ruleValue: json['ruleValue'] as String? ?? '',
    );
  }
}

class PageSectionModel {
  final int id;
  final String sectionKey;
  final String blockTypeRaw;
  final PageBlockType blockType;
  final String? title;
  final String? subtitle;
  final String? description;
  final String? buttonText;
  final String? buttonLink;
  final String? badgeText;
  final String? emptyStateText;
  final String stylePreset;
  final String backgroundPreset;
  final String alignmentPreset;
  final String densityPreset;
  final bool isVisible;
  final String status; // visible|hidden|archived
  final bool isPinned;
  final bool isRequired;
  final int sortOrder;
  final List<String>? platformTargets; // null=전체 플랫폼
  final bool scheduleEnabled;
  final DateTime? startAt;
  final DateTime? endAt;
  final String? linkedAssetType; // open_pass|happy_money|luck_pouch
  final String? linkedFeatureScope;
  final String? linkedCampaignId;
  final String? linkedProductId;
  final List<PageSectionAttachment> attachments;
  final List<PageSectionDisplayRule> displayRules;

  const PageSectionModel({
    required this.id,
    required this.sectionKey,
    required this.blockTypeRaw,
    required this.blockType,
    this.title,
    this.subtitle,
    this.description,
    this.buttonText,
    this.buttonLink,
    this.badgeText,
    this.emptyStateText,
    this.stylePreset = 'default',
    this.backgroundPreset = 'white',
    this.alignmentPreset = 'left',
    this.densityPreset = 'normal',
    this.isVisible = true,
    this.status = 'visible',
    this.isPinned = false,
    this.isRequired = false,
    this.sortOrder = 0,
    this.platformTargets,
    this.scheduleEnabled = false,
    this.startAt,
    this.endAt,
    this.linkedAssetType,
    this.linkedFeatureScope,
    this.linkedCampaignId,
    this.linkedProductId,
    this.attachments = const [],
    this.displayRules = const [],
  });

  /// usageType == 'banner'인 첫 번째 대표(isPrimary) 첨부, 없으면 첫 번째 첨부.
  PageSectionAttachment? get primaryBannerAttachment {
    if (attachments.isEmpty) return null;
    final primaries = attachments.where((a) => a.isPrimary);
    if (primaries.isNotEmpty) return primaries.first;
    return attachments.first;
  }

  List<PageSectionAttachment> attachmentsOf(String usageType) =>
      attachments.where((a) => a.usageType == usageType).toList();

  factory PageSectionModel.fromJson(Map<String, dynamic> json) {
    final rawBlockType = json['blockType'] as String? ?? '';
    return PageSectionModel(
      id: json['id'] as int? ?? 0,
      sectionKey: json['sectionKey'] as String? ?? '',
      blockTypeRaw: rawBlockType,
      blockType: PageBlockType.fromKey(rawBlockType),
      title: json['title'] as String?,
      subtitle: json['subtitle'] as String?,
      description: json['description'] as String?,
      buttonText: json['buttonText'] as String?,
      buttonLink: json['buttonLink'] as String?,
      badgeText: json['badgeText'] as String?,
      emptyStateText: json['emptyStateText'] as String?,
      stylePreset: json['stylePreset'] as String? ?? 'default',
      backgroundPreset: json['backgroundPreset'] as String? ?? 'white',
      alignmentPreset: json['alignmentPreset'] as String? ?? 'left',
      densityPreset: json['densityPreset'] as String? ?? 'normal',
      isVisible: json['isVisible'] as bool? ?? true,
      status: json['status'] as String? ?? 'visible',
      isPinned: json['isPinned'] as bool? ?? false,
      isRequired: json['isRequired'] as bool? ?? false,
      sortOrder: json['sortOrder'] as int? ?? 0,
      platformTargets: (json['platformTargets'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      scheduleEnabled: json['scheduleEnabled'] as bool? ?? false,
      startAt: json['startAt'] != null
          ? DateTime.tryParse(json['startAt'] as String)
          : null,
      endAt: json['endAt'] != null
          ? DateTime.tryParse(json['endAt'] as String)
          : null,
      linkedAssetType: json['linkedAssetType'] as String?,
      linkedFeatureScope: json['linkedFeatureScope'] as String?,
      linkedCampaignId: json['linkedCampaignId'] as String?,
      linkedProductId: json['linkedProductId'] as String?,
      attachments: (json['attachments'] as List<dynamic>? ?? const [])
          .map((e) => PageSectionAttachment.fromJson(e as Map<String, dynamic>))
          .toList(),
      displayRules: (json['displayRules'] as List<dynamic>? ?? const [])
          .map(
            (e) => PageSectionDisplayRule.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  /// HomeConfigCacheStore 저장/캐시 왕복을 위한 역직렬화 대응 직렬화.
  Map<String, dynamic> toJson() => {
    'id': id,
    'sectionKey': sectionKey,
    'blockType': blockTypeRaw,
    'title': title,
    'subtitle': subtitle,
    'description': description,
    'buttonText': buttonText,
    'buttonLink': buttonLink,
    'badgeText': badgeText,
    'emptyStateText': emptyStateText,
    'stylePreset': stylePreset,
    'backgroundPreset': backgroundPreset,
    'alignmentPreset': alignmentPreset,
    'densityPreset': densityPreset,
    'isVisible': isVisible,
    'status': status,
    'isPinned': isPinned,
    'isRequired': isRequired,
    'sortOrder': sortOrder,
    'platformTargets': platformTargets,
    'scheduleEnabled': scheduleEnabled,
    'startAt': startAt?.toIso8601String(),
    'endAt': endAt?.toIso8601String(),
    'linkedAssetType': linkedAssetType,
    'linkedFeatureScope': linkedFeatureScope,
    'linkedCampaignId': linkedCampaignId,
    'linkedProductId': linkedProductId,
    'attachments': attachments
        .map(
          (a) => {
            'attachmentUrl': a.attachmentUrl,
            'usageType': a.usageType,
            'isPrimary': a.isPrimary,
            'displayOrder': a.displayOrder,
          },
        )
        .toList(),
    'displayRules': displayRules
        .map(
          (r) => {
            'ruleType': r.ruleType,
            'ruleOperator': r.ruleOperator,
            'ruleValue': r.ruleValue,
          },
        )
        .toList(),
  };
}

/// `GET /api/public/page-configs/home` 응답 전체(sections 배열 + 버전 메타)
class PageConfigData {
  final String pageKey;
  final int? versionId;
  final int? versionNumber;
  final DateTime? publishedAt;
  final List<PageSectionModel> sections;

  const PageConfigData({
    required this.pageKey,
    this.versionId,
    this.versionNumber,
    this.publishedAt,
    this.sections = const [],
  });

  factory PageConfigData.fromJson(Map<String, dynamic> json) {
    return PageConfigData(
      pageKey: json['pageKey'] as String? ?? 'home',
      versionId: json['versionId'] as int?,
      versionNumber: json['versionNumber'] as int?,
      publishedAt: json['publishedAt'] != null
          ? DateTime.tryParse(json['publishedAt'] as String)
          : null,
      sections: (json['sections'] as List<dynamic>? ?? const [])
          .map((e) => PageSectionModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'pageKey': pageKey,
    'versionId': versionId,
    'versionNumber': versionNumber,
    'publishedAt': publishedAt?.toIso8601String(),
    'sections': sections.map((s) => s.toJson()).toList(),
  };
}
