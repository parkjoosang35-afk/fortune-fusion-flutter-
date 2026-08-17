/// 04A 도메인 A `users`+`user_profiles` 대응 Dart 모델(DTO)
///
/// [신통방통 2단계 - 회원/운세 프로필 통합] isLeapMonth(윤달 여부)/
/// birthTimeUnknown(출생시간 모름 여부)/birthPlace(출생지역) 3개 필드를
/// 추가한다. 계산엔진(ManseryeokCoreEngine, PHASE1~4)이 이미 지원하는
/// BirthInfo.isLeapMonth/birthPlace를 그대로 연결하는 값이며, 계산 로직
/// 자체는 전혀 변경하지 않는다.
/// - isLeapMonth: 음력(isLunar=true)일 때만 의미가 있고, 양력이면 항상
///   false로 취급한다(UI에서도 음력 선택 시에만 노출).
/// - birthTimeUnknown: true여도 계산엔진에는 기존과 동일하게 관례값(12:00)이
///   전달된다. 이 플래그는 결과 화면에서 "정확도가 낮을 수 있습니다" 안내
///   문구를 노출할지 판단하는 용도로만 사용한다.
class UserModel {
  final String id;
  final String nickname;
  final String? email;
  final String? birthDate; // YYYY-MM-DD
  final String? birthTime; // HH:mm, nullable
  final bool isLunar;
  final bool isLeapMonth;
  final bool birthTimeUnknown;
  final String? birthPlace;
  final String? gender;
  final String grade; // user_grades 연계(향후)

  const UserModel({
    required this.id,
    required this.nickname,
    this.email,
    this.birthDate,
    this.birthTime,
    this.isLunar = false,
    this.isLeapMonth = false,
    this.birthTimeUnknown = false,
    this.birthPlace,
    this.gender,
    this.grade = 'normal',
  });

  UserModel copyWith({
    String? nickname,
    String? email,
    String? birthDate,
    String? birthTime,
    bool? isLunar,
    bool? isLeapMonth,
    bool? birthTimeUnknown,
    String? birthPlace,
    String? gender,
  }) {
    return UserModel(
      id: id,
      nickname: nickname ?? this.nickname,
      email: email ?? this.email,
      birthDate: birthDate ?? this.birthDate,
      birthTime: birthTime ?? this.birthTime,
      isLunar: isLunar ?? this.isLunar,
      isLeapMonth: isLeapMonth ?? this.isLeapMonth,
      birthTimeUnknown: birthTimeUnknown ?? this.birthTimeUnknown,
      birthPlace: birthPlace ?? this.birthPlace,
      gender: gender ?? this.gender,
      grade: grade,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nickname': nickname,
    'email': email,
    'birth_date': birthDate,
    'birth_time': birthTime,
    'is_lunar': isLunar,
    'is_leap_month': isLeapMonth,
    'birth_time_unknown': birthTimeUnknown,
    'birth_place': birthPlace,
    'gender': gender,
    'grade': grade,
  };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'] as String,
    nickname: json['nickname'] as String,
    email: json['email'] as String?,
    birthDate: json['birth_date'] as String?,
    birthTime: json['birth_time'] as String?,
    isLunar: json['is_lunar'] as bool? ?? false,
    isLeapMonth: json['is_leap_month'] as bool? ?? false,
    birthTimeUnknown: json['birth_time_unknown'] as bool? ?? false,
    birthPlace: json['birth_place'] as String?,
    gender: json['gender'] as String?,
    grade: json['grade'] as String? ?? 'normal',
  );
}
