/// [회원가입·본인 사주정보 통합 흐름 — 전면 검수 지시서 대응] 음력 날짜
/// 검증 공용 유틸리티.
///
/// [배경] `saju_input_screen.dart`(fortune_period 사주입력)와
/// `birth_input_screen.dart`(본인 사주정보 입력/수정) 양쪽 모두 과거에는
/// 음력 월의 일수를 실제 음력 데이터 없이 "무조건 30일"로 고정 처리하는
/// 버그가 있었다. 이는 음력 29일인 "작은달"에도 30일을 선택할 수 있게
/// 허용해, 존재하지 않는 음력 날짜(예: 2023년 음력 2월 30일 — 실제로는
/// 29일까지만 존재)가 서버에 저장될 수 있는 심각한 데이터 정합성 문제였다.
///
/// [해결 원칙] 이미 앱에 포함된 `lunar`(pub.dev, 6tail 저자 — 사주 계산
/// 엔진과 동일 출처) 패키지가 정확한 음력 월별 일수와 윤달 정보를 제공한다.
/// 이 패키지의 `LunarYear`/`LunarMonth` API를 그대로 사용해 "기존 만세력
/// 엔진 기준"으로 검증한다 — 자체 음력 계산 로직을 새로 구현하지 않는다
/// (사주 계산에 쓰이는 `manseryeok_core_engine.dart`와 동일 패키지·동일
/// 데이터 소스이므로, 입력 검증과 실제 사주 계산이 반드시 같은 결과를
/// 보장한다).
library;

import 'package:lunar/lunar.dart';

class LunarCalendarUtil {
  LunarCalendarUtil._();

  /// 주어진 음력 연도에 윤달이 있으면 그 월(1~12)을, 없으면 0을 반환한다.
  /// (`lunar` 패키지 `LunarYear.getLeapMonth()` 그대로 위임.)
  static int leapMonthOf(int year) {
    try {
      return LunarYear.fromYear(year).getLeapMonth();
    } catch (_) {
      return 0;
    }
  }

  /// 주어진 연도에 [month]월의 윤달이 실제로 존재하는지 여부.
  /// 예: 2023년은 윤2월이 있으므로 `hasLeapMonth(2023, 2) == true`.
  static bool hasLeapMonth(int year, int month) => leapMonthOf(year) == month;

  /// 음력 [year]년 [month]월(윤달이면 [isLeap]=true)의 실제 일수(29 또는
  /// 30)를 반환한다. 해당 월/윤달이 그 해에 존재하지 않으면 null.
  static int? daysInLunarMonth(int year, int month, {bool isLeap = false}) {
    try {
      final m = LunarMonth.fromYm(year, isLeap ? -month : month);
      return m?.getDayCount();
    } catch (_) {
      return null;
    }
  }

  /// 입력된 음력 생년월일(윤달 포함)이 "기존 만세력 엔진 기준"으로 실제
  /// 존재하는 날짜인지 검증한다. 양력 검증과 동일한 모양의 결과를 돌려주되
  /// 자세한 사유 문자열을 포함한다.
  ///
  /// - [year]/[month]/[day]: 사용자가 고른 음력 날짜 값
  /// - [isLeap]: "윤달" 선택 여부(일반달이면 false)
  static LunarDateValidation validateLunarDate({
    required int year,
    required int month,
    required int day,
    required bool isLeap,
  }) {
    if (month < 1 || month > 12) {
      return const LunarDateValidation(
        ok: false,
        message: '1월부터 12월까지 있어요',
      );
    }
    if (isLeap && !hasLeapMonth(year, month)) {
      final actualLeap = leapMonthOf(year);
      return LunarDateValidation(
        ok: false,
        message: actualLeap == 0
            ? '$year년(음력)에는 윤달이 없어요'
            : '$year년(음력)은 윤$actualLeap월만 윤달이에요',
      );
    }
    final maxDay = daysInLunarMonth(year, month, isLeap: isLeap);
    if (maxDay == null) {
      return const LunarDateValidation(ok: false, message: '음력 날짜를 확인해 주세요');
    }
    if (day < 1 || day > maxDay) {
      return LunarDateValidation(
        ok: false,
        message: '${isLeap ? '윤$month월' : '$month월'}은 $maxDay일까지 있어요',
        maxDay: maxDay,
      );
    }
    return LunarDateValidation(ok: true, maxDay: maxDay);
  }
}

class LunarDateValidation {
  const LunarDateValidation({required this.ok, this.message, this.maxDay});

  final bool ok;
  final String? message;

  /// 검증 통과 여부와 무관하게, 해당 (년, 월, 윤달여부) 조합의 실제
  /// 최대 일수(29 또는 30). 날짜 피커의 "일" 옵션 개수를 그릴 때 사용한다.
  final int? maxDay;
}
