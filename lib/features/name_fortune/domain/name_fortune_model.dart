/// [운세 카테고리 확장] 이름 운세(성명학) - 신규 카테고리 모델.
///
/// admin_web `POST /api/public/fortune/name` 응답 스키마
/// `{id,name,hanja,birthDate,gender,resultText,createdAt,balance,refundAmount,pointSpent}`에
/// 1:1 대응한다. 사주/궁합과 달리 토픽 분기나 다중 섹션이 없는 단일 텍스트
/// 생성형 카테고리라 모델 구조가 가장 단순하다.
class NameFortuneResultModel {
  final String id;
  final String name;
  final String? hanja;
  final String? birthDate;
  final String? gender;
  final String resultText;
  final DateTime createdAt;

  const NameFortuneResultModel({
    required this.id,
    required this.name,
    required this.resultText,
    required this.createdAt,
    this.hanja,
    this.birthDate,
    this.gender,
  });

  factory NameFortuneResultModel.fromJson(Map<String, dynamic> json) {
    return NameFortuneResultModel(
      id: json['id'] as String,
      name: json['name'] as String,
      hanja: json['hanja'] as String?,
      birthDate: json['birthDate'] as String?,
      gender: json['gender'] as String?,
      resultText: json['resultText'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
