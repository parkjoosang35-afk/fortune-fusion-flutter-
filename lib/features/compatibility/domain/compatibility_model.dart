/// [궁합(C그룹) 신규 구현] 궁합 결과 모델.
///
/// admin_web `POST/GET /api/public/compatibility/*` 응답 스키마
/// `{id,nameA,nameB,type,score,topicResults,summary,createdAt}`에 1:1 대응한다.
/// (사주/이름 운세 모델과 동일하게 백엔드가 이미 결정론적 규칙 기반으로
/// 점수/토픽 결과를 산출해주므로, 클라이언트는 별도 계산 로직 없이 그대로
/// 표시만 한다.)
class CompatibilityResultModel {
  final String id;
  final String nameA;
  final String nameB;

  /// love/friend/business/family (04A 명시 화이트리스트, admin_web과 동일)
  final String type;

  /// 0~100
  final int score;

  /// 예: {'애정': '...', '성격': '...', '미래': '...'}
  final Map<String, String> topicResults;
  final String summary;
  final DateTime createdAt;

  const CompatibilityResultModel({
    required this.id,
    required this.nameA,
    required this.nameB,
    required this.type,
    required this.score,
    required this.topicResults,
    required this.summary,
    required this.createdAt,
  });

  factory CompatibilityResultModel.fromJson(Map<String, dynamic> json) {
    final rawTopics = json['topicResults'] as Map<String, dynamic>? ?? {};
    return CompatibilityResultModel(
      id: json['id'] as String,
      nameA: json['nameA'] as String? ?? '나',
      nameB: json['nameB'] as String? ?? '상대방',
      type: json['type'] as String? ?? 'love',
      score: (json['score'] as num?)?.toInt() ?? 0,
      topicResults: rawTopics.map((k, v) => MapEntry(k, v.toString())),
      summary: json['summary'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

/// 궁합 유형 4종(04A 명시 화이트리스트) - admin_web CompatibilityRequest.type과 동일.
enum CompatibilityType { love, friend, business, family }

extension CompatibilityTypeLabel on CompatibilityType {
  String get apiValue => name;

  String get label => switch (this) {
    CompatibilityType.love => '애정운',
    CompatibilityType.friend => '우정운',
    CompatibilityType.business => '사업운',
    CompatibilityType.family => '가족운',
  };
}
