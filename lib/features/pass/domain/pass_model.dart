/// 알림패스(AlarmPass) — Fortune Fusion 3대 재화 중 ①시간제 콘텐츠 열람권.
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
    );
  }
}

/// GET /api/public/pass/status 대응 — 현재 사용자의 알림패스 활성 상태
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
