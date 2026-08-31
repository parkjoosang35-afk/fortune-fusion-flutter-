/// [관상·손금 신통방통 리스킨] 손금 촬영 시 선택하는 손 방향.
/// 오른손 = 현재·후천운, 왼손 = 과거·선천운 (핸드오프 문구 기준).
enum PalmHandSide {
  right,
  left;

  /// 서버 API 파라미터/바디에 실어 보낼 문자열 값.
  String get apiValue => this == PalmHandSide.right ? 'right' : 'left';
}

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
