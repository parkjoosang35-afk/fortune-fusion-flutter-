/// 04A 도메인F `compatibility_requests`(F-1)/`compatibility_results`(F-2) 대응 모델
/// 09단계 §3.2-⑥ 궁합 프롬프트 출력 스키마(score/topic_results/summary) 반영
/// 06§4.5 API 5종(request/result/history/share/save/compare) 대응 필드 보강
enum CompatibilityType { love, friend, business, family }

extension CompatibilityTypeLabel on CompatibilityType {
  String get label => switch (this) {
    CompatibilityType.love => '연인',
    CompatibilityType.friend => '친구',
    CompatibilityType.business => '동업/직장',
    CompatibilityType.family => '가족',
  };
}

class CompatibilityResultModel {
  final String id;
  final String nameA;
  final String nameB;
  final CompatibilityType type;
  final int score; // 0-100 궁합 점수
  final Map<String, String> topicResults; // 애정/성격/미래
  final String summary;
  final bool isSaved;
  final String? shareUrl;
  final DateTime createdAt;

  const CompatibilityResultModel({
    required this.id,
    required this.nameA,
    required this.nameB,
    required this.score,
    required this.topicResults,
    required this.summary,
    required this.createdAt,
    this.type = CompatibilityType.love,
    this.isSaved = false,
    this.shareUrl,
  });

  CompatibilityResultModel copyWith({bool? isSaved, String? shareUrl}) {
    return CompatibilityResultModel(
      id: id,
      nameA: nameA,
      nameB: nameB,
      type: type,
      score: score,
      topicResults: topicResults,
      summary: summary,
      createdAt: createdAt,
      isSaved: isSaved ?? this.isSaved,
      shareUrl: shareUrl ?? this.shareUrl,
    );
  }

  /// POST .../compatibility/request, GET .../history, GET .../result/:id 공통 응답 대응.
  /// [주의] 서버 응답에는 isSaved/shareUrl 필드가 없다(admin_web 스키마에 보관/공유
  /// 컬럼이 없음 — CompatibilityProvider가 클라이언트 로컬 상태로 별도 관리한다).
  factory CompatibilityResultModel.fromJson(Map<String, dynamic> json) {
    final topicResultsRaw =
        json['topicResults'] as Map<String, dynamic>? ?? const {};
    return CompatibilityResultModel(
      id: json['id'] as String,
      nameA: json['nameA'] as String? ?? '나',
      nameB: json['nameB'] as String? ?? '상대방',
      type: CompatibilityType.values.firstWhere(
        (t) => t.name == (json['type'] as String? ?? 'love'),
        orElse: () => CompatibilityType.love,
      ),
      score: json['score'] as int? ?? 0,
      topicResults: topicResultsRaw.map(
        (key, value) => MapEntry(key, value as String? ?? ''),
      ),
      summary: json['summary'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

/// 06§4.5 `GET /compatibility/compare?ids=` 대응 - 보관한 결과끼리 항목별 비교표
class CompatibilityCompareRow {
  final String topic;
  final Map<String, String> valueByResultId; // resultId -> 해당 항목 텍스트/점수

  const CompatibilityCompareRow({
    required this.topic,
    required this.valueByResultId,
  });
}
