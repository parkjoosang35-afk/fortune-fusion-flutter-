import '../../auth/domain/user_model.dart';
import 'jeontong_input.dart';

/// [신통방통 2단계 - 회원/운세 프로필 통합] 로그인 회원의 서버 프로필
/// ([UserModel] — `users`+`user_profiles` 대응 DTO)을 정통사주 계산
/// 파이프라인이 이미 사용하는 [JeontongInput] 값 객체로 변환하는 순수
/// 어댑터.
///
/// [설계 원칙]
/// - PHASE1~4 계산엔진, [SajuProfile], 기존 Adapter는 전혀 건드리지 않는다
///   — 이 파일은 "이미 존재하는 값을 옮기기만" 한다(새 계산 없음).
/// - 회원의 `birthDate`/`birthTime`이 아직 없으면(=ProfileCheckScreen을
///   아직 완료하지 않음) null을 반환한다. 호출부는 null이면 기존 폴백
///   경로(로컬 [JeontongProfileStore] 또는 결정론적 샘플)를 그대로 타야
///   한다 — 이 어댑터가 "로그인만 하면 무조건 서버 프로필을 강제"하지
///   않는다.
/// - `birthTime`이 null(=[UserModel.birthTimeUnknown]이 true인 경우가
///   전형적)이면 관례값 12:00을 사용한다(계산에는 항상 12:00, 정확도 저하
///   안내는 별도 [UserModel.birthTimeUnknown] 플래그로 화면에서 처리).
/// - `isLeapMonth`는 `isLunar`가 false이면 항상 false로 강제한다
///   (반영사항2: "양력에서는 사용하지 않도록 처리").
JeontongInput? userModelToJeontongInput(UserModel user) {
  final birthDate = user.birthDate;
  if (birthDate == null || birthDate.isEmpty) return null;

  final dateParts = birthDate.split('-');
  if (dateParts.length != 3) return null;
  final year = int.tryParse(dateParts[0]);
  final month = int.tryParse(dateParts[1]);
  final day = int.tryParse(dateParts[2]);
  if (year == null || month == null || day == null) return null;

  // 출생시간을 모르면(또는 저장되어 있지 않으면) 계산엔진 관례값 12:00을
  // 그대로 사용한다 — PHASE1~4가 기존에 항상 적용해온 규칙과 동일.
  int hour = 12;
  int minute = 0;
  final birthTime = user.birthTime;
  if (!user.birthTimeUnknown && birthTime != null && birthTime.isNotEmpty) {
    final timeParts = birthTime.split(':');
    if (timeParts.length == 2) {
      hour = int.tryParse(timeParts[0]) ?? 12;
      minute = int.tryParse(timeParts[1]) ?? 0;
    }
  }

  final gender = user.gender == 'M' || user.gender == 'male' ? 'M' : 'F';

  return JeontongInput(
    birthDateTimeLocal: DateTime(year, month, day, hour, minute),
    gender: gender,
    isLunar: user.isLunar,
    // 양력이면 윤달 개념이 없으므로 항상 false로 강제(반영사항2).
    isLeapMonth: user.isLunar ? user.isLeapMonth : false,
    birthTimeUnknown: user.birthTimeUnknown,
    name: user.nickname,
  );
}
