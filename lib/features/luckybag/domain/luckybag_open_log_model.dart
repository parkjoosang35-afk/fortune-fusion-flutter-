import 'luckybag_product_model.dart';

/// 04A `luckybag_open_logs`(I-5, 파티션 대상) 대응 - 내 개봉 이력(GET /history)
class LuckyBagOpenLogModel {
  final String id;
  final LuckyBagProductModel product;
  final LuckyBagGrade grade;
  final String rewardType;
  final String rewardLabel;
  final int? rewardAmount;
  final DateTime openedAt;

  const LuckyBagOpenLogModel({
    required this.id,
    required this.product,
    required this.grade,
    required this.rewardType,
    required this.rewardLabel,
    this.rewardAmount,
    required this.openedAt,
  });
}

/// 06§4.9 `GET /v1/luckybags/rewards/my` 대응 - 등급/보상타입별 집계 요약
class LuckyBagRewardSummaryEntry {
  final LuckyBagGrade grade;
  final int count;
  final int totalPointReward;

  const LuckyBagRewardSummaryEntry({
    required this.grade,
    required this.count,
    required this.totalPointReward,
  });
}
