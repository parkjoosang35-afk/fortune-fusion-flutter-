/// [정통사주 80종 전용 신규 엔진] 만세력 Core Engine — PHASE 1.
///
/// 37번 지시 §4 "먼저 정통사주 공통 만세력 엔진을 완성한다"와 §5 "만세력
/// Core Engine 완성"에 대응한다.
///
/// [절대 원칙]
/// - AI/LLM 호출 없음, 해시 기반 가짜 명식 없음 — 오직 `lunar` 패키지의
///   실제 만세력 계산(양력↔음력 변환, 24절기, 60갑자, 절입시각 기준
///   월주 계산)만 사용한다.
/// - 패키지가 이미 제공하는 계산(절기/60갑자/음력변환/윤달/대운시작시점)을
///   재구현하지 않는다 — 이 파일은 패키지 API를 "정책에 맞게 호출"하고
///   결과를 [SajuProfile] 형태로 정규화하는 역할만 한다.
/// - 기존 `saju_engine.dart`(`SajuEngine.calculate`)는 건드리지 않는다.
///   이 신규 엔진은 별도 진입점([ManseryeokCoreEngine.buildProfile])이며,
///   기존 호출부(`jeontong_eighty_report_builder.dart`)는 이번 Phase
///   1에서는 아직 연결하지 않는다(Phase 5에서 전환 예정 — 37번 지시
///   "각 단계가 실제 검증된 후 다음 단계로 넘어간다" 원칙).
library;

import 'package:lunar/lunar.dart';

import '../saju_engine.dart' show ganKr, zhiKr, ganElement, zhiElement;
import 'manseryeok_policy.dart';
import 'saju_profile.dart';

/// 정통사주 신규 엔진의 버전(37번 지시 §8/§21 대응). 기존 레거시 시스템의
/// 버전 체계와 무관한, 이 엔진 전용 네임스페이스다.
const String kJeontongSajuEngineVersion = 'jeontong-manseryeok-1.0.0';

/// PHASE 1 계산 결과를 담아 검증(테스트)이 쉽도록 만든 원시 산출물.
/// [SajuProfile]로 최종 변환되기 전 단계의 "패키지 원본 값"을 그대로
/// 노출해, 골든 테스트에서 lunar 패키지 API가 반환하는 실제 값과 1:1로
/// 대조할 수 있게 한다(37번 지시 §24 "1차: 년주/월주/일주/시주" 검증).
class ManseryeokCoreResult {
  const ManseryeokCoreResult({
    required this.solar,
    required this.lunar,
    required this.eightChar,
    required this.yearPillar,
    required this.monthPillar,
    required this.dayPillar,
    required this.hourPillar,
  });

  final Solar solar;
  final Lunar lunar;
  final EightChar eightChar;
  final Pillar yearPillar;
  final Pillar monthPillar;
  final Pillar dayPillar;
  final Pillar hourPillar;
}

class ManseryeokCoreEngine {
  ManseryeokCoreEngine._();

  /// 입력된 출생 벽시계 시각(이미 [BirthInfo.utcOffsetMinutes] 기준
  /// KST로 정규화되어 있다고 가정 — 정규화는 [normalizeToKst]에서 수행)을
  /// 받아 사주 8글자(년/월/일/시주)를 계산한다.
  ///
  /// [year]/[month]/[day]/[hour]/[minute]는 [calendarType]에 따라 양력
  /// 또는 음력 값이며, 음력이고 [isLeapMonth]=true 이면 해당 월의 윤달로
  /// 계산한다(37번 지시 §5 "윤달").
  static ManseryeokCoreResult calculatePillars({
    required int year,
    required int month,
    required int day,
    required int hour,
    int minute = 0,
    required CalendarInputType calendarType,
    bool isLeapMonth = false,
    ZiHourPolicy ziHourPolicy = ZiHourPolicy.lateZiSameDay,
  }) {
    late final Solar solar;
    late final Lunar lunar;

    if (calendarType == CalendarInputType.lunar) {
      // [윤달 지원] lunar 패키지는 윤달을 "월(month) 값의 음수"로
      // 표현한다(예: 윤2월 = -2). 사용자가 명시적으로 윤달이라고
      // 지정했을 때만 음수로 변환해 전달한다 — 그 외에는 절대
      // 임의로 윤달 처리하지 않는다(37번 지시 §34 절대 금지사항
      // "윤달을 일반 음력처럼 처리" 방지).
      final lunarMonth = isLeapMonth ? -month : month;
      lunar = Lunar.fromYmdHms(year, lunarMonth, day, hour, minute, 0);
      solar = lunar.getSolar();
    } else {
      solar = Solar.fromYmdHms(year, month, day, hour, minute, 0);
      lunar = solar.getLunar();
    }

    final eightChar = lunar.getEightChar();
    // [자시 정책 명시 적용] — 37번 지시 §5 "자시/야자시 정책".
    eightChar.setSect(ziHourPolicyToSect(ziHourPolicy));

    Pillar buildPillar(String stemHanja, String branchHanja) {
      final stemInfo = ganElement[stemHanja]!;
      final branchInfo = zhiElement[branchHanja]!;
      final jiaZi = '$stemHanja$branchHanja';
      return Pillar(
        stemHanja: stemHanja,
        branchHanja: branchHanja,
        stemKr: ganKr[stemHanja]!,
        branchKr: zhiKr[branchHanja]!,
        stemElement: stemInfo.$1,
        stemYinYang: stemInfo.$2,
        branchElement: branchInfo.$1,
        branchYinYang: branchInfo.$2,
        jiaZiIndex: LunarUtil.getJiaZiIndex(jiaZi),
      );
    }

    final yearPillar = buildPillar(
      eightChar.getYearGan(),
      eightChar.getYearZhi(),
    );
    final monthPillar = buildPillar(
      eightChar.getMonthGan(),
      eightChar.getMonthZhi(),
    );
    final dayPillar = buildPillar(eightChar.getDayGan(), eightChar.getDayZhi());
    final hourPillar = buildPillar(
      eightChar.getTimeGan(),
      eightChar.getTimeZhi(),
    );

    return ManseryeokCoreResult(
      solar: solar,
      lunar: lunar,
      eightChar: eightChar,
      yearPillar: yearPillar,
      monthPillar: monthPillar,
      dayPillar: dayPillar,
      hourPillar: hourPillar,
    );
  }

  /// 해외 출생 등, 출생지 표준시가 KST(UTC+9)와 다른 경우를 위한 벽시계
  /// 시각 변환 헬퍼(37번 지시 §5 "시간대"/"해외 출생 확장 구조").
  ///
  /// [birthWallClock]은 "출생지 현지 벽시계 시각"으로 해석되는
  /// [DateTime]이며(연/월/일/시/분만 사용, timezone 정보는 무시), 이를
  /// [birthUtcOffsetMinutes] 만큼 UTC로 되돌린 뒤 KST(+540분) 벽시계
  /// 시각으로 재환산한다. 국내 출생([birthUtcOffsetMinutes] ==
  /// [kstUtcOffsetMinutes])이면 값이 그대로 유지되어 기존 계산과
  /// 100% 동일한 결과를 낸다(회귀 없음).
  static DateTime normalizeToKst(
    DateTime birthWallClock, {
    required int birthUtcOffsetMinutes,
  }) {
    if (birthUtcOffsetMinutes == kstUtcOffsetMinutes) {
      return birthWallClock;
    }
    final naiveUtc = DateTime.utc(
      birthWallClock.year,
      birthWallClock.month,
      birthWallClock.day,
      birthWallClock.hour,
      birthWallClock.minute,
      birthWallClock.second,
    ).subtract(Duration(minutes: birthUtcOffsetMinutes));
    return naiveUtc.add(const Duration(minutes: kstUtcOffsetMinutes));
  }

  /// [SajuProfile] 전체(Phase 1 필드까지)를 생성하는 최상위 진입점.
  /// Phase 2~4 필드는 null로 남겨두고, 이후 각 Phase 엔진이
  /// `copyWith()`로 점진적으로 채운다.
  static SajuProfile buildProfile({
    required int year,
    required int month,
    required int day,
    required int hour,
    int minute = 0,
    required String gender,
    required CalendarInputType calendarType,
    bool isLeapMonth = false,
    String? birthPlace,
    int utcOffsetMinutes = kstUtcOffsetMinutes,
    ZiHourPolicy ziHourPolicy = ZiHourPolicy.lateZiSameDay,
    DaewoonStartPrecision daewoonStartPrecision =
        DaewoonStartPrecision.traditionalApprox,
  }) {
    return buildProfileWithCore(
      year: year,
      month: month,
      day: day,
      hour: hour,
      minute: minute,
      gender: gender,
      calendarType: calendarType,
      isLeapMonth: isLeapMonth,
      birthPlace: birthPlace,
      utcOffsetMinutes: utcOffsetMinutes,
      ziHourPolicy: ziHourPolicy,
      daewoonStartPrecision: daewoonStartPrecision,
    ).profile;
  }

  /// [buildProfile]과 동일하게 계산하되, Phase 2 이후 엔진들이 필요로
  /// 하는 [ManseryeokCoreResult](특히 `eightChar` — 십이운성 계산에
  /// 필요)까지 함께 반환한다. Phase 2 이후 재계산(이중 계산) 없이 같은
  /// 인스턴스를 그대로 전달해 회귀를 방지하기 위한 진입점이다.
  static ({SajuProfile profile, ManseryeokCoreResult core})
  buildProfileWithCore({
    required int year,
    required int month,
    required int day,
    required int hour,
    int minute = 0,
    required String gender,
    required CalendarInputType calendarType,
    bool isLeapMonth = false,
    String? birthPlace,
    int utcOffsetMinutes = kstUtcOffsetMinutes,
    ZiHourPolicy ziHourPolicy = ZiHourPolicy.lateZiSameDay,
    DaewoonStartPrecision daewoonStartPrecision =
        DaewoonStartPrecision.traditionalApprox,
  }) {
    // 해외 출생 등 시간대가 다르면 KST 벽시계 시각으로 정규화한다.
    final kst = normalizeToKst(
      DateTime(year, month, day, hour, minute),
      birthUtcOffsetMinutes: utcOffsetMinutes,
    );

    final core = calculatePillars(
      year: kst.year,
      month: kst.month,
      day: kst.day,
      hour: kst.hour,
      minute: kst.minute,
      calendarType: calendarType,
      isLeapMonth: isLeapMonth,
      ziHourPolicy: ziHourPolicy,
    );

    final birthInfo = BirthInfo(
      calendarType: calendarType,
      year: year,
      month: month,
      day: day,
      hour: hour,
      minute: minute,
      isLeapMonth: isLeapMonth,
      gender: gender,
      birthPlace: birthPlace,
      utcOffsetMinutes: utcOffsetMinutes,
    );

    final profile = SajuProfile(
      engineVersion: kJeontongSajuEngineVersion,
      birthInfo: birthInfo,
      solarDate:
          '${core.solar.getYear().toString().padLeft(4, '0')}-${core.solar.getMonth().toString().padLeft(2, '0')}-${core.solar.getDay().toString().padLeft(2, '0')} '
          '${core.solar.getHour().toString().padLeft(2, '0')}:${core.solar.getMinute().toString().padLeft(2, '0')}',
      lunarDate: core.lunar.toString(),
      lunarLeapMonth: core.lunar.getMonth() < 0,
      utcOffsetMinutes: utcOffsetMinutes,
      ziHourPolicy: ziHourPolicy,
      daewoonStartPrecision: daewoonStartPrecision,
      yearPillar: core.yearPillar,
      monthPillar: core.monthPillar,
      dayPillar: core.dayPillar,
      hourPillar: core.hourPillar,
    );

    return (profile: profile, core: core);
  }
}
