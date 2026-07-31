/// 04A 도메인 I(행복머니) 대응 모델
/// 07단계 §14 행운 경험(Luck Experience) 리추얼 배너에서 "받을 수 있는 행복머니" 카드에 사용
class LuckyBagSummary {
  final int pendingCount;
  final String grade; // common/rare/epic 중 가장 높은 등급

  const LuckyBagSummary({required this.pendingCount, required this.grade});
}
