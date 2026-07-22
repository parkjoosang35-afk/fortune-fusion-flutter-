/// 04A E-2 `fortune_results` + E-3 `saju_charts` 대응 모델
class SajuPillars {
  final String year;
  final String month;
  final String day;
  final String? hour;

  const SajuPillars({
    required this.year,
    required this.month,
    required this.day,
    this.hour,
  });
}

class SajuResultModel {
  final String id;
  final SajuPillars pillars;
  final Map<String, int> fiveElements; // 목화토금수
  final Map<String, String> topicResults; // 재물/애정/직업/건강
  final String summary;
  final DateTime createdAt;

  const SajuResultModel({
    required this.id,
    required this.pillars,
    required this.fiveElements,
    required this.topicResults,
    required this.summary,
    required this.createdAt,
  });
}
