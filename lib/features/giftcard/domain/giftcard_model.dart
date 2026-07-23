/// 04A 도메인J `giftcard_products`(J-1) 대응 모델
class GiftcardProductModel {
  final String id;
  final String name;
  final String brand;
  final int requiredPoint;
  final int stockCount;
  final int validDays;
  final String imageEmoji; // 04A image_file_id 대응(Mock: 이모지로 대체)

  const GiftcardProductModel({
    required this.id,
    required this.name,
    required this.brand,
    required this.requiredPoint,
    required this.stockCount,
    required this.validDays,
    required this.imageEmoji,
  });

  bool get inStock => stockCount > 0;
}

/// `giftcard_issues`(J-2) 대응 - status(Base): requested/issued/failed/cancelled/expired
enum GiftcardIssueStatus { requested, issued, failed, cancelled, expired }

class GiftcardIssueModel {
  final String id;
  final GiftcardProductModel product;
  final int pointSpent;
  final GiftcardIssueStatus status;
  final String? issuedCode; // 암호화 저장 대응(Mock: 평문 표시, 04A 보안정책은 서버단 구현 사항)
  final DateTime? issuedAt;
  final DateTime? expiresAt;
  final DateTime? usedAt; // giftcard_usages(J-3) 대응, Phase14-2 사용처리에서 채움

  const GiftcardIssueModel({
    required this.id,
    required this.product,
    required this.pointSpent,
    required this.status,
    this.issuedCode,
    this.issuedAt,
    this.expiresAt,
    this.usedAt,
  });

  bool get isUsed => usedAt != null;

  GiftcardIssueModel copyWith({GiftcardIssueStatus? status, DateTime? usedAt}) {
    return GiftcardIssueModel(
      id: id,
      product: product,
      pointSpent: pointSpent,
      status: status ?? this.status,
      issuedCode: issuedCode,
      issuedAt: issuedAt,
      expiresAt: expiresAt,
      usedAt: usedAt ?? this.usedAt,
    );
  }
}

extension GiftcardIssueStatusLabel on GiftcardIssueStatus {
  String get label {
    switch (this) {
      case GiftcardIssueStatus.requested:
        return '발급 대기중';
      case GiftcardIssueStatus.issued:
        return '사용 가능';
      case GiftcardIssueStatus.failed:
        return '발급 실패';
      case GiftcardIssueStatus.cancelled:
        return '취소됨';
      case GiftcardIssueStatus.expired:
        return '기간 만료';
    }
  }
}
