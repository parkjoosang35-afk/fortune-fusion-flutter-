/// 04A E-8 `compatibility_results` 대응 모델
/// 09단계 §3.2-⑥ 궁합 프롬프트 출력 스키마(score/topic_results/summary) 반영
class CompatibilityResultModel {
  final String id;
  final String nameA;
  final String nameB;
  final int score; // 0-100 궁합 점수
  final Map<String, String> topicResults; // 애정/성격/미래
  final String summary;
  final DateTime createdAt;

  const CompatibilityResultModel({
    required this.id,
    required this.nameA,
    required this.nameB,
    required this.score,
    required this.topicResults,
    required this.summary,
    required this.createdAt,
  });
}
