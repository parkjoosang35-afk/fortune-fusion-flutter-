import 'luckybag_product_model.dart';

/// 04A `luckybag_reward_pools`(I-3) 대응 - 확률공개(GET /:id/probabilities) 모델
class LuckyBagRewardPoolModel {
  final String id;
  final LuckyBagGrade grade;
  final String rewardType; // point/amulet/giftcard_fragment/none
  final String rewardLabel; // 화면 표시용 설명(예: "500P", "재물 부적")
  final int? rewardAmount; // point 보상일 경우 금액
  final double probability; // 확률(%), 그룹 합=100

  const LuckyBagRewardPoolModel({
    required this.id,
    required this.grade,
    required this.rewardType,
    required this.rewardLabel,
    this.rewardAmount,
    required this.probability,
  });
}

/// 06§6.2 `POST /v1/luckybags/:id/open` 응답 대응 - 개봉 결과
class LuckyBagOpenResult {
  final String openLogId;
  final LuckyBagGrade grade;
  final String rewardType;
  final String rewardLabel;
  final int? rewardAmount;
  final int remainingBalance;

  const LuckyBagOpenResult({
    required this.openLogId,
    required this.grade,
    required this.rewardType,
    required this.rewardLabel,
    this.rewardAmount,
    required this.remainingBalance,
  });
}
