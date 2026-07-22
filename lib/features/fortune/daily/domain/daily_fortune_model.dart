/// 04A E-4 `daily_fortunes` 대응 모델
class DailyFortuneModel {
  final String id;
  final DateTime date;
  final Map<String, int> categoryScores; // 총운/애정/재물/건강
  final String luckyColor;
  final int luckyNumber;
  final String summaryText;

  const DailyFortuneModel({
    required this.id,
    required this.date,
    required this.categoryScores,
    required this.luckyColor,
    required this.luckyNumber,
    required this.summaryText,
  });
}
