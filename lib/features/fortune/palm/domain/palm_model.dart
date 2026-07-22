/// 04A E-7 `palm_readings` 대응 모델
/// 09단계 §3.2-⑤ 손금 프롬프트 출력 스키마(lines/topic_results/summary) 반영
class PalmResultModel {
  final String id;
  final Map<String, String> lines; // 생명선/두뇌선/감정선/운명선
  final Map<String, String> topicResults; // 재물/애정/직업/건강
  final String summary;
  final DateTime createdAt;

  const PalmResultModel({
    required this.id,
    required this.lines,
    required this.topicResults,
    required this.summary,
    required this.createdAt,
  });
}
