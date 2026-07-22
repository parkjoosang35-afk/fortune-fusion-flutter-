/// 04A 도메인 H(디지털 부적) 대응 모델
/// 07단계 §14 행운 경험(Luck Experience) 리추얼 배너에서 "오늘의 디지털 부적" 카드에 사용
class AmuletSummary {
  final bool hasActive;
  final String name;
  final String iconEmoji;

  const AmuletSummary({
    required this.hasActive,
    required this.name,
    required this.iconEmoji,
  });
}
