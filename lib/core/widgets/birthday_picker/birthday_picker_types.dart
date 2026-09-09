/// [BirthdayPickerModal 포팅 — 1/4: 데이터 모델]
///
/// 원본: `handoff-extract/BirthdayPickerModal.jsx`(신통방통 소원방 디자인
/// 핸드오프 패키지)의 상수·검증 로직을 Dart로 그대로 옮긴다. 이 위젯은
/// 정통사주69/AI사주/궁합 등 앱 전역의 생년월일+태어난시간 입력 화면을
/// 하나의 디자인으로 통일하기 위한 공용 컴포넌트다.
///
/// 값 자체(자시 23~01시, 12지신 순서, 검증 규칙)는 명리학 표준에 따른
/// 것으로 원본 JS와 완전히 동일하게 유지해야 한다 — 임의로 바꾸지 않는다.
library;

/// 12지신 시간대 1개 항목.
class BirthdayZhiTime {
  const BirthdayZhiTime({
    required this.zhi,
    required this.hanja,
    required this.rangeStart,
    required this.rangeEnd,
    required this.label,
    required this.hint,
  });

  /// 한글 지신명 (예: '자')
  final String zhi;

  /// 한자 (예: '子')
  final String hanja;

  /// 시작 시(24h). 자시는 23으로 시작해 다음날로 넘어간다.
  final int rangeStart;

  /// 종료 시(24h). 자시는 1(다음날 01시)로 끝난다.
  final int rangeEnd;

  /// 라벨 (예: '자시')
  final String label;

  /// 시간 힌트 (예: '23:00 – 01:00')
  final String hint;
}

/// 12지신 시간대 전체 목록 — 원본 JS `JIZHI_TIMES`와 순서·값 동일.
const List<BirthdayZhiTime> kBirthdayZhiTimes = [
  BirthdayZhiTime(
    zhi: '자',
    hanja: '子',
    rangeStart: 23,
    rangeEnd: 1,
    label: '자시',
    hint: '23:00 – 01:00',
  ),
  BirthdayZhiTime(
    zhi: '축',
    hanja: '丑',
    rangeStart: 1,
    rangeEnd: 3,
    label: '축시',
    hint: '01:00 – 03:00',
  ),
  BirthdayZhiTime(
    zhi: '인',
    hanja: '寅',
    rangeStart: 3,
    rangeEnd: 5,
    label: '인시',
    hint: '03:00 – 05:00',
  ),
  BirthdayZhiTime(
    zhi: '묘',
    hanja: '卯',
    rangeStart: 5,
    rangeEnd: 7,
    label: '묘시',
    hint: '05:00 – 07:00',
  ),
  BirthdayZhiTime(
    zhi: '진',
    hanja: '辰',
    rangeStart: 7,
    rangeEnd: 9,
    label: '진시',
    hint: '07:00 – 09:00',
  ),
  BirthdayZhiTime(
    zhi: '사',
    hanja: '巳',
    rangeStart: 9,
    rangeEnd: 11,
    label: '사시',
    hint: '09:00 – 11:00',
  ),
  BirthdayZhiTime(
    zhi: '오',
    hanja: '午',
    rangeStart: 11,
    rangeEnd: 13,
    label: '오시',
    hint: '11:00 – 13:00',
  ),
  BirthdayZhiTime(
    zhi: '미',
    hanja: '未',
    rangeStart: 13,
    rangeEnd: 15,
    label: '미시',
    hint: '13:00 – 15:00',
  ),
  BirthdayZhiTime(
    zhi: '신',
    hanja: '申',
    rangeStart: 15,
    rangeEnd: 17,
    label: '신시',
    hint: '15:00 – 17:00',
  ),
  BirthdayZhiTime(
    zhi: '유',
    hanja: '酉',
    rangeStart: 17,
    rangeEnd: 19,
    label: '유시',
    hint: '17:00 – 19:00',
  ),
  BirthdayZhiTime(
    zhi: '술',
    hanja: '戌',
    rangeStart: 19,
    rangeEnd: 21,
    label: '술시',
    hint: '19:00 – 21:00',
  ),
  BirthdayZhiTime(
    zhi: '해',
    hanja: '亥',
    rangeStart: 21,
    rangeEnd: 23,
    label: '해시',
    hint: '21:00 – 23:00',
  ),
];

/// 요일 표시용 상수 — 원본 JS `DAY_HANJA_KR` / `DAY_KO_KR`.
const List<String> kBirthdayDayHanjaKr = ['日', '月', '火', '水', '木', '金', '土'];
const List<String> kBirthdayDayKoKr = ['일', '월', '화', '수', '목', '금', '토'];

/// 최종 onConfirm 콜백에 담기는 "시간" 부분 값.
class BirthdayPickerTimeValue {
  const BirthdayPickerTimeValue({
    required this.zhi,
    required this.hanja,
    required this.rangeStart,
    required this.rangeEnd,
    required this.label,
  });

  final String zhi;
  final String hanja;
  final int rangeStart;
  final int rangeEnd;

  /// 표시용 라벨 (예: '자시 (23:00 – 01:00)')
  final String label;
}

/// 최종 onConfirm 콜백 값 — 원본 JS 스키마와 동일한 필드 구성.
class BirthdayPickerValue {
  const BirthdayPickerValue({
    required this.year,
    required this.month,
    required this.day,
    required this.weekday,
    this.time,
  });

  final int year;
  final int month;
  final int day;

  /// 0=일 .. 6=토 (Dart DateTime.weekday는 1=월..7=일이므로 변환해서 담음)
  final int weekday;

  /// null이면 "시간 모름"
  final BirthdayPickerTimeValue? time;

  /// ISO 날짜 문자열 (예: '1985-05-12')
  String get iso =>
      '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  /// 이 화면에서 흔히 필요한 DateTime 조합 — 시간이 있으면 해당 시(zhi)의
  /// 시작 시각을, 없으면 정오(12:00)를 기본값으로 사용한다.
  DateTime toDateTime() {
    final t = time;
    if (t == null) {
      return DateTime(year, month, day, 12, 0);
    }
    // 자시(23시 시작)는 해당 날짜 23:00으로 취급한다(사주 계산은 자시를
    // '전날 23시~당일 01시'로 보되, 입력 시각 자체는 그날 23:00으로 기록).
    return DateTime(year, month, day, t.rangeStart == 23 ? 23 : t.rangeStart, 0);
  }

  BirthdayPickerValue copyWith({
    int? year,
    int? month,
    int? day,
    int? weekday,
    BirthdayPickerTimeValue? time,
    bool clearTime = false,
  }) {
    return BirthdayPickerValue(
      year: year ?? this.year,
      month: month ?? this.month,
      day: day ?? this.day,
      weekday: weekday ?? this.weekday,
      time: clearTime ? null : (time ?? this.time),
    );
  }
}

/// 날짜 검증 결과 — 원본 JS `validateDateBP()`와 동일한 규칙.
class BirthdayDateValidation {
  const BirthdayDateValidation({required this.ok, this.field, this.msg});

  final bool ok;
  final String? field; // 'year' | 'month' | 'day'
  final String? msg;

  static const valid = BirthdayDateValidation(ok: true);
}

/// 원본 JS `validateDateBP(y, m, d)` 그대로 포팅.
BirthdayDateValidation validateBirthdayDate(int? y, int? m, int? d) {
  if (m != null) {
    if (m < 1 || m > 12) {
      return const BirthdayDateValidation(
        ok: false,
        field: 'month',
        msg: '1월부터 12월까지 있어요',
      );
    }
  }
  if (y != null) {
    final now = DateTime.now().year;
    if (y < 1900) {
      return const BirthdayDateValidation(
        ok: false,
        field: 'year',
        msg: '1900년 이후로 입력해주세요',
      );
    }
    if (y > now) {
      return BirthdayDateValidation(
        ok: false,
        field: 'year',
        msg: '$now년까지 입력할 수 있어요',
      );
    }
  }
  if (d != null && m != null && y != null) {
    final maxD = DateTime(y, m + 1, 0).day;
    if (d < 1 || d > maxD) {
      return BirthdayDateValidation(
        ok: false,
        field: 'day',
        msg: '$m월은 $maxD일까지 있어요',
      );
    }
  } else if (d != null) {
    if (d < 1 || d > 31) {
      return const BirthdayDateValidation(
        ok: false,
        field: 'day',
        msg: '1일부터 31일까지 있어요',
      );
    }
  }
  return BirthdayDateValidation.valid;
}
