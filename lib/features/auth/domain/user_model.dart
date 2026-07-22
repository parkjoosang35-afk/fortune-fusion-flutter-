/// 04A 도메인 A `users`+`user_profiles` 대응 Dart 모델(DTO)
class UserModel {
  final String id;
  final String nickname;
  final String? email;
  final String? birthDate; // YYYY-MM-DD
  final String? birthTime; // HH:mm, nullable
  final bool isLunar;
  final String? gender;
  final String grade; // user_grades 연계(향후)

  const UserModel({
    required this.id,
    required this.nickname,
    this.email,
    this.birthDate,
    this.birthTime,
    this.isLunar = false,
    this.gender,
    this.grade = 'normal',
  });

  UserModel copyWith({
    String? nickname,
    String? email,
    String? birthDate,
    String? birthTime,
    bool? isLunar,
    String? gender,
  }) {
    return UserModel(
      id: id,
      nickname: nickname ?? this.nickname,
      email: email ?? this.email,
      birthDate: birthDate ?? this.birthDate,
      birthTime: birthTime ?? this.birthTime,
      isLunar: isLunar ?? this.isLunar,
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
    gender: json['gender'] as String?,
    grade: json['grade'] as String? ?? 'normal',
  );
}
