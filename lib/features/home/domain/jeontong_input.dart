import 'package:flutter/foundation.dart' show immutable;

/// [정통사주 80종 · MVP 라스트 마일] 사용자가 입력 화면에서 채운 생년월일시
/// + 성별 + 음양력 + 이름(옵션)을 담는 불변 값 객체.
///
/// [설계 원칙] 이 클래스는 순수 값 객체(dart:core 전용, 신규 dependency
/// 0)이며, [JeontongReportBuilder.build]/[JeontongReportCache.getOrBuild]가
/// 이미 받고 있는 4축(userId/birthDateTimeUtc/gender/isLunar)과 필드를
/// 1:1로 맞춰 설계했다 — 향후(개인화 배선 미션) 결과 화면까지 값을 그대로
/// 실어 나를 때 별도 변환 계층 없이 바로 대응시킬 수 있게 하기 위함이다.
///
/// - [birthDateTimeLocal]은 사용자가 입력한 "현지(KST) 벽시계 시각"이다.
///   저장/전달 시에는 [birthDateTimeUtc] getter로 UTC 변환값을 사용한다
///   (jeontong_eighty_report_builder.dart의 "UTC 저장값 → KST 변환" 규약과
///   반대 방향의 변환 — KST 벽시계 시각을 UTC로 저장해두면 그 규약과
///   맞물려 원래 KST 값이 그대로 복원된다).
/// - [gender]는 'M' 또는 'F' 두 값만 허용한다(라디오 버튼 2択).
/// - [isLunar]는 기본값 false(양력)다.
/// - [name]은 선택 입력이며 비어 있으면 null로 정규화한다(빈 문자열 저장
///   방지 — 다운스트림에서 "이름 없음"과 "빈 문자열"을 혼동하지 않도록).
///
/// [신통방통 2단계 - 회원/운세 프로필 통합] [isLeapMonth]/[birthTimeUnknown]
/// 2개 필드를 추가한다. PHASE1~4 계산엔진 자체는 수정하지 않았으며, 이
/// 값 객체가 [JeontongReportBuilder.build]/[buildProfileAndSajuResultViaPhase1to4]
/// 에 이미 존재하던 파라미터를 그대로 통과시키는 역할만 한다.
/// - [isLeapMonth]: 음력([isLunar]=true)일 때만 실제 계산에 반영된다.
///   양력이면 항상 false로 취급(계산엔진에도 항상 false로 강제 전달).
/// - [birthTimeUnknown]: 계산에는 영향이 없다(관례값 12:00 그대로 사용).
///   결과 화면에서 "정확도가 낮을 수 있습니다" 안내 배지 노출 여부에만 쓴다.
@immutable
class JeontongInput {
  const JeontongInput({
    required this.birthDateTimeLocal,
    required this.gender,
    this.isLunar = false,
    this.isLeapMonth = false,
    this.birthTimeUnknown = false,
    this.name,
  });

  /// KST(한국 표준시) 기준 벽시계 생년월일시. 시(hour)/분(minute)까지 포함.
  final DateTime birthDateTimeLocal;

  /// 'M' | 'F'.
  final String gender;

  /// 음력 여부 — 기본 false(양력).
  final bool isLunar;

  /// 윤달(음력) 여부 — 음력일 때만 의미가 있다. 기본 false.
  final bool isLeapMonth;

  /// 출생시간을 모른다고 표시한 상태 — 계산에는 영향 없음(관례값 12:00),
  /// 결과 화면 안내 문구 노출 판단에만 사용. 기본 false.
  final bool birthTimeUnknown;

  /// 선택 입력 이름. 빈 문자열/공백만 있으면 null로 취급한다.
  final String? name;

  /// [birthDateTimeLocal]을 UTC로 변환한 값.
  /// KST는 UTC+9 고정 오프셋이므로, 로컬 벽시계 시각에서 9시간을 빼면
  /// 그 벽시계 시각을 나타내는 UTC 순간을 얻는다.
  DateTime get birthDateTimeUtc => DateTime.utc(
    birthDateTimeLocal.year,
    birthDateTimeLocal.month,
    birthDateTimeLocal.day,
    birthDateTimeLocal.hour,
    birthDateTimeLocal.minute,
  ).subtract(const Duration(hours: 9));

  /// 정규화된 이름 — 앞뒤 공백 제거 후 빈 문자열이면 null.
  String? get normalizedName {
    final trimmed = name?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  /// 양력이면 윤달 개념 자체가 없으므로 항상 false를 반환한다. 계산엔진에
  /// 전달할 때는 이 값을 사용해야 한다(원본 [isLeapMonth] 그대로 쓰면
  /// 양력인데 true인 잘못된 상태가 섞여 전달될 수 있음).
  bool get effectiveIsLeapMonth => isLunar ? isLeapMonth : false;

  JeontongInput copyWith({
    DateTime? birthDateTimeLocal,
    String? gender,
    bool? isLunar,
    bool? isLeapMonth,
    bool? birthTimeUnknown,
    String? name,
  }) {
    return JeontongInput(
      birthDateTimeLocal: birthDateTimeLocal ?? this.birthDateTimeLocal,
      gender: gender ?? this.gender,
      isLunar: isLunar ?? this.isLunar,
      isLeapMonth: isLeapMonth ?? this.isLeapMonth,
      birthTimeUnknown: birthTimeUnknown ?? this.birthTimeUnknown,
      name: name ?? this.name,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is JeontongInput &&
        other.birthDateTimeLocal == birthDateTimeLocal &&
        other.gender == gender &&
        other.isLunar == isLunar &&
        other.isLeapMonth == isLeapMonth &&
        other.birthTimeUnknown == birthTimeUnknown &&
        other.name == name;
  }

  @override
  int get hashCode => Object.hash(
    birthDateTimeLocal,
    gender,
    isLunar,
    isLeapMonth,
    birthTimeUnknown,
    name,
  );

  @override
  String toString() =>
      'JeontongInput(birthDateTimeLocal: $birthDateTimeLocal, gender: $gender, '
      'isLunar: $isLunar, isLeapMonth: $isLeapMonth, '
      'birthTimeUnknown: $birthTimeUnknown, name: $name)';
}
