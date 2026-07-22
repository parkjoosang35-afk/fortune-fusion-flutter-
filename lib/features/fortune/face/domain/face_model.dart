/// 04A E-6 `face_readings` 대응 모델
/// 09단계 §3.2-④ 관상 프롬프트 출력 스키마(features/topic_results/summary) 반영
class FaceResultModel {
  final String id;
  final Map<String, String> features; // 이마/눈/코/입/턱 등 부위별 특징
  final Map<String, String> topicResults; // 재물/애정/직업/건강
  final String summary;
  final DateTime createdAt;

  const FaceResultModel({
    required this.id,
    required this.features,
    required this.topicResults,
    required this.summary,
    required this.createdAt,
  });
}
