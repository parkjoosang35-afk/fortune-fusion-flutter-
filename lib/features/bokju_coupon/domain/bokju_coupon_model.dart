/// [복주머니 마케팅 쿠폰 — Flutter 클라이언트] admin_web
/// `GET /api/public/bokju-coupons/resolve?token=` 응답 1:1 대응 모델.
///
/// [비파괴 조회] 이 모델은 "등록(redeem) 전" 미리보기 전용이다 — 서버가
/// 쿠폰 상태를 변경하지 않으므로, 사용자가 이 화면을 여러 번 봐도 안전하다.
class BokjuCouponPreview {
  final String campaignTitle;
  final int grantAmount;
  final String? guideText;
  final String issueType; // INDIVIDUAL/SHARED
  final DateTime validTo;
  final bool redeemable;
  final String? reasonIfNot;

  const BokjuCouponPreview({
    required this.campaignTitle,
    required this.grantAmount,
    required this.guideText,
    required this.issueType,
    required this.validTo,
    required this.redeemable,
    required this.reasonIfNot,
  });

  factory BokjuCouponPreview.fromJson(Map<String, dynamic> json) {
    return BokjuCouponPreview(
      campaignTitle: json['campaignTitle'] as String? ?? '',
      grantAmount: json['grantAmount'] as int? ?? 0,
      guideText: json['guideText'] as String?,
      issueType: json['issueType'] as String? ?? 'INDIVIDUAL',
      validTo: DateTime.tryParse(json['validTo'] as String? ?? '') ??
          DateTime.now(),
      redeemable: json['redeemable'] as bool? ?? false,
      reasonIfNot: json['reasonIfNot'] as String?,
    );
  }
}

/// `POST /api/public/bokju-coupons/redeem` 성공 응답(`data`) 1:1 대응 모델.
class BokjuCouponRedeemResult {
  final int grantedAmount;
  final int balanceAfter;
  final String couponNoMasked;
  final DateTime redeemedAt;
  final bool replayed;

  const BokjuCouponRedeemResult({
    required this.grantedAmount,
    required this.balanceAfter,
    required this.couponNoMasked,
    required this.redeemedAt,
    required this.replayed,
  });

  factory BokjuCouponRedeemResult.fromJson(Map<String, dynamic> json) {
    return BokjuCouponRedeemResult(
      grantedAmount: json['grantedAmount'] as int? ?? 0,
      balanceAfter: json['balanceAfter'] as int? ?? 0,
      couponNoMasked: json['couponNoMasked'] as String? ?? '',
      redeemedAt: DateTime.tryParse(json['redeemedAt'] as String? ?? '') ??
          DateTime.now(),
      replayed: json['replayed'] as bool? ?? false,
    );
  }
}

/// `GET /api/public/bokju-coupons/my` 응답의 `redemptions[]` 항목 1:1 대응 모델.
/// "내 쿠폰함" 이력 화면용.
class BokjuCouponHistoryItem {
  final int id;
  final String? campaignTitle;
  final int grantedAmount;
  final int balanceAfter;
  final DateTime redeemedAt;

  const BokjuCouponHistoryItem({
    required this.id,
    required this.campaignTitle,
    required this.grantedAmount,
    required this.balanceAfter,
    required this.redeemedAt,
  });

  factory BokjuCouponHistoryItem.fromJson(Map<String, dynamic> json) {
    return BokjuCouponHistoryItem(
      id: json['id'] as int? ?? 0,
      campaignTitle: json['campaignTitle'] as String?,
      grantedAmount: json['grantedAmount'] as int? ?? 0,
      balanceAfter: json['balanceAfter'] as int? ?? 0,
      redeemedAt: DateTime.tryParse(json['redeemedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
