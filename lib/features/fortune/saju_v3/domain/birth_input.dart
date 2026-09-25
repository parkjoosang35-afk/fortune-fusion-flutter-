// 신통방통 사주 엔진 - BirthInput 모델
// 모든 사주 관련 API의 공통 요청 바디

class BirthInput {
  final String? name;
  final int year;
  final int month;
  final int day;
  final int hour;
  final int minute;
  final String gender; // "male" or "female"
  final bool isLunar;

  const BirthInput({
    this.name,
    required this.year,
    required this.month,
    required this.day,
    this.hour = 12,
    this.minute = 0,
    this.gender = 'male',
    this.isLunar = false,
  });

  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        'year': year,
        'month': month,
        'day': day,
        'hour': hour,
        'minute': minute,
        'gender': gender,
        'is_lunar': isLunar,
      };

  factory BirthInput.fromJson(Map<String, dynamic> j) => BirthInput(
        name: j['name'] as String?,
        year: j['year'] as int,
        month: j['month'] as int,
        day: j['day'] as int,
        hour: (j['hour'] ?? 12) as int,
        minute: (j['minute'] ?? 0) as int,
        gender: (j['gender'] ?? 'male') as String,
        isLunar: (j['is_lunar'] ?? false) as bool,
      );
}
