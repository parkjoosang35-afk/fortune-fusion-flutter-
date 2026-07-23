/// 04A 도메인A `user_grades`(마스터) 대응 Dart 모델
/// 등급은 활동점수(min_activity_score) 기준 자동 산정되며, 적립 시 point_earn_multiplier가 적용된다.
class GradeModel {
  final String code; // bronze/silver/gold/vip
  final String name;
  final int minActivityScore;
  final double pointEarnMultiplier;
  final int sortOrder;

  const GradeModel({
    required this.code,
    required this.name,
    required this.minActivityScore,
    required this.pointEarnMultiplier,
    required this.sortOrder,
  });

  factory GradeModel.fromJson(Map<String, dynamic> json) => GradeModel(
    code: json['code'] as String,
    name: json['name'] as String,
    minActivityScore: json['min_activity_score'] as int? ?? 0,
    pointEarnMultiplier:
        (json['point_earn_multiplier'] as num?)?.toDouble() ?? 1.0,
    sortOrder: json['sort_order'] as int? ?? 0,
  );
}
