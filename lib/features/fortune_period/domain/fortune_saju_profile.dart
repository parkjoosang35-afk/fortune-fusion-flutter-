/// [기간별 운세 — 사주정보 완전 여부/표시 헬퍼]
///
/// `saju_renewal_home_screen.dart`의 `_isProfileComplete()`와 동일한
/// 판정 기준(생년월일 + 성별 + 시간정보(입력 또는 "모름" 명시))을 쓰되,
/// 이 기능 전용 폼(`saju-input.jsx`)은 출생지(birthPlace)를 입력받지
/// 않으므로 그 조건은 제외한다. 서버 저장 모델(`UserModel`)은 두 기능이
/// 공유하지만, "이 화면 기준 완전 여부"는 기능별로 다를 수 있어 별도
/// 함수로 분리한다.
library;

import '../../auth/domain/user_model.dart';
import '../../../core/widgets/birthday_picker/birthday_picker_types.dart';

/// 기간별 운세 기준 "사주정보가 등록되어 있는지" 판정.
bool isFortuneSajuComplete(UserModel? user) {
  if (user == null) return false;
  if (user.birthDate == null || user.birthDate!.isEmpty) return false;
  if (user.gender != 'male' && user.gender != 'female') return false;
  final timeExplicit =
      user.birthTimeUnknown ||
      (user.birthTime != null && user.birthTime!.isNotEmpty);
  return timeExplicit;
}

/// `UserModel.birthTime`("HH:mm")에서 시(hour)를 뽑아 대응하는 12지신
/// 항목을 찾는다. `birth_input_screen.dart`의 `_zhiTimeForHour()`와
/// 동일한 로직.
BirthdayZhiTime? zhiTimeForBirthTime(String? birthTime) {
  if (birthTime == null || birthTime.isEmpty) return null;
  final parts = birthTime.split(':');
  if (parts.isEmpty) return null;
  final hour = int.tryParse(parts[0]);
  if (hour == null) return null;
  for (final z in kBirthdayZhiTimes) {
    if (z.rangeStart == hour) return z;
  }
  return null;
}

/// 생년월일시 요약 한 줄(마이페이지/프로필바에서 사용).
/// 예: "1992.03.14 양력 · 자시 · 여"
String formatFortuneSajuSummary(UserModel user) {
  final date = user.birthDate ?? '';
  final ymd = date.replaceAll('-', '.');
  final cal = user.isLunar ? '음력${user.isLeapMonth ? '(윤)' : ''}' : '양력';
  final zhi = zhiTimeForBirthTime(user.birthTime);
  final timeLabel = user.birthTimeUnknown
      ? '시 모름'
      : (zhi != null ? zhi.label : '시 모름');
  final genderLabel = user.gender == 'female' ? '여' : '남';
  return '$ymd $cal · $timeLabel · $genderLabel';
}
