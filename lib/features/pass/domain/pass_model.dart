/// 열림패스(AlarmPass) — Fortune Fusion 3대 재화 중 ①시간제 콘텐츠 열람권.
/// admin_web PassPolicy(정책 마스터)/UserPass(발급 이력) 모델 대응.
/// [문서8 DB스키마초안 승인 반영] passType: ad/partner/subscription/event
enum PassType { ad, partner, subscription, event }

extension PassTypeLabel on PassType {
  String get label => switch (this) {
    PassType.ad => '광고 시청',
    PassType.partner => '파트너 제휴',
    PassType.subscription => '구독',
    PassType.event => '이벤트',
  };

  static PassType fromCode(String code) {
    return PassType.values.firstWhere(
      (t) => t.name == code,
      orElse: () => PassType.ad,
    );
  }
}

/// GET /api/public/pass/policies 대응 — 홈 화면 CTA 카드 목록
class PassPolicyModel {
  final int id;
  final String name;
  final PassType passType;
  final int durationMin;
  final int? dailyLimit;
  final String? ctaText;
  final String? bannerImageUrl;
  final String? linkUrl;
  final int bonusPoint;
  // [재화 구조 정리] 복주머니로 직접 구매 시 가격(null=복주머니 구매 불가 정책).
  // 백엔드 JSON 키는 과거 명칭 그대로 happyMoneyPrice이나, 재화 구조 정리 이후
  // 의미상 복주머니 가격이므로 Dart 필드명은 luckPouchPrice로 둔다.
  final int? luckPouchPrice;

  // [프리패스 단순화 - 쿠팡파트너스 전용] §1/§2/§9
  // CMS 쿠팡파트너스 배너(positionCode='open_pass')에서 병합되어 내려오는
  // 값들. adType='script'면 [bannerImageUrl] 대신 [adScript](쿠팡파트너스
  // 원본 iframe/script)를 렌더링해야 한다. adWaitSeconds는 관리자가 설정한
  // "광고 확인 대기시간"(4/5/10초)으로, 쿠팡 방문 후 자동지급 전 대기하는 초.
  final String adType; // 'image' | 'script'
  final String? adScript;
  final int adWaitSeconds;

  // [프리패스 UI 문구 관리자 연동] "?" 도움말 팝업 및 아이콘 바로 아래
  // 안내 제목/문구를 관리자가 직접 입력한 값. null이면 화면단에서 기본 문구로 폴백한다.
  final String? adHelpMessage;
  final String? adGuideTitle;
  final String? adGuideText;

  const PassPolicyModel({
    required this.id,
    required this.name,
    required this.passType,
    required this.durationMin,
    this.dailyLimit,
    this.ctaText,
    this.bannerImageUrl,
    this.linkUrl,
    this.bonusPoint = 0,
    this.luckPouchPrice,
    this.adType = 'image',
    this.adScript,
    this.adWaitSeconds = 5,
    this.adHelpMessage,
    this.adGuideTitle,
    this.adGuideText,
  });

  factory PassPolicyModel.fromJson(Map<String, dynamic> json) {
    return PassPolicyModel(
      id: json['id'] as int,
      name: json['name'] as String,
      passType: PassTypeLabel.fromCode(json['passType'] as String? ?? 'ad'),
      durationMin: json['durationMin'] as int? ?? 60,
      dailyLimit: json['dailyLimit'] as int?,
      ctaText: json['ctaText'] as String?,
      bannerImageUrl: json['bannerImageUrl'] as String?,
      linkUrl: json['linkUrl'] as String?,
      bonusPoint: json['bonusPoint'] as int? ?? 0,
      luckPouchPrice: json['happyMoneyPrice'] as int?,
      adType: json['adType'] as String? ?? 'image',
      adScript: json['adScript'] as String?,
      adWaitSeconds: json['adWaitSeconds'] as int? ?? 5,
      adHelpMessage: json['adHelpMessage'] as String?,
      adGuideTitle: json['adGuideTitle'] as String?,
      adGuideText: json['adGuideText'] as String?,
    );
  }
}

/// GET /api/public/pass/purchase-options 대응 — "복주머니로 구매" 가능한 프리패스
/// 옵션 목록(마이페이지 프리패스 영역에서 사용). [복주머니 사용 구간표]
/// 프리패스30분-30 / 1시간-50 / 24시간-150.
class PassPurchaseOptionModel {
  final int id;
  final String name;
  final int durationMin;
  final int luckPouchPrice;
  final String? description;

  const PassPurchaseOptionModel({
    required this.id,
    required this.name,
    required this.durationMin,
    required this.luckPouchPrice,
    this.description,
  });

  factory PassPurchaseOptionModel.fromJson(Map<String, dynamic> json) {
    return PassPurchaseOptionModel(
      id: json['id'] as int,
      name: json['name'] as String,
      durationMin: json['durationMin'] as int? ?? 0,
      luckPouchPrice: json['happyMoneyPrice'] as int? ?? 0,
      description: json['description'] as String?,
    );
  }
}

/// GET /api/public/pass/status 대응 — 현재 사용자의 열림패스 활성 상태
class PassStatusModel {
  final bool isActive;
  final int? userPassId;
  final int? policyId;
  final String? policyName;
  final PassType? passType;
  final DateTime? activatedAt;
  final DateTime? expiresAt;
  final int remainingSec;

  const PassStatusModel({
    required this.isActive,
    this.userPassId,
    this.policyId,
    this.policyName,
    this.passType,
    this.activatedAt,
    this.expiresAt,
    this.remainingSec = 0,
  });

  factory PassStatusModel.inactive() => const PassStatusModel(isActive: false);

  factory PassStatusModel.fromJson(Map<String, dynamic> json) {
    final isActive = json['isActive'] as bool? ?? false;
    if (!isActive) return PassStatusModel.inactive();
    return PassStatusModel(
      isActive: true,
      userPassId: json['userPassId'] as int?,
      policyId: json['policyId'] as int?,
      policyName: json['policyName'] as String?,
      passType: json['passType'] != null
          ? PassTypeLabel.fromCode(json['passType'] as String)
          : null,
      activatedAt: json['activatedAt'] != null
          ? DateTime.parse(json['activatedAt'] as String)
          : null,
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
      remainingSec: json['remainingSec'] as int? ?? 0,
    );
  }
}
