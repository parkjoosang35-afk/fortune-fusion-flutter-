// shrine_saju_adapter.dart — [사용자 확정 결정 ②] 신당(神堂) 부적에 표기할
// 사주 8자를, 신당 스타터의 플레이스홀더 saju() 함수(날짜를 한자로만 바꾸는
// 가짜 계산)가 아니라 이 프로젝트에 이미 존재하는 정통사주 만세력 엔진
// (JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4)으로 실제 계산한다.
//
// 표준 불변 제약: "판정은 결정론적 규칙 코드로만", "기존 엔진 재구현 금지,
// 기존 Repository/엔드포인트 재사용"을 준수 — 이 어댑터는 새로운 계산을
// 추가하지 않고 기존 엔진의 결과(Pillar 4개의 한자)를 신당 부적의 세로쓰기
// 표기 형식으로 옮기기만 한다.
import '../../home/domain/jeontong_eighty_report_builder.dart';
import '../../home/domain/manseryeok/saju_profile.dart';

class ShrineSajuAdapter {
  ShrineSajuAdapter._();

  /// [hourLabel]은 '子時'..'亥時' 중 하나(shrineHours) 또는 null(모름).
  /// shrineHours의 각 시(時)는 2시간 범위를 대표하는 간지시 — 범위의
  /// 시작 시각(23/1/3/5/7/9/11/13/15/17/19/21)을 실제 계산에 사용한다
  /// (기존 만세력 엔진의 ZiHourPolicy.lateZiSameDay 기본 정책과 함께
  /// 적용되어 자시(23~1시) 경계도 안전하게 처리된다).
  static const Map<String, int> _hourStart = {
    '子時': 23, '丑時': 1, '寅時': 3, '卯時': 5, '辰時': 7, '巳時': 9,
    '午時': 11, '未時': 13, '申時': 15, '酉時': 17, '戌時': 19, '亥時': 21,
  };

  /// 생년월일(+시, 선택)로 사주 원국을 계산해 [SajuProfile]을 반환한다.
  /// 시(時)를 모르면 정오(12시)로 계산하되, [buildPillars]가 hourPillar를
  /// 결과에서 제외해 화면에는 노출하지 않는다.
  static SajuProfile buildProfile({required DateTime birth, String? hourLabel}) {
    final hour = (hourLabel != null && _hourStart.containsKey(hourLabel))
        ? _hourStart[hourLabel]!
        : 12;
    final kst = DateTime(birth.year, birth.month, birth.day, hour);
    final result = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
      kst: kst,
      gender: 'unknown',
      isLunar: false,
      referenceDate: DateTime.now(),
    );
    return result.profile;
  }

  /// 부적 VerticalText용 — 연주·월주·일주(한자 4자씩, 시를 알면 시주까지
  /// 8자)를 세로쓰기 한 줄 문자열로 합친다. 예: "庚午 癸未 甲子 壬申".
  static String verticalPillarText({required DateTime birth, String? hourLabel}) {
    final profile = buildProfile(birth: birth, hourLabel: hourLabel);
    final knowsHour = hourLabel != null && _hourStart.containsKey(hourLabel);
    final buf = StringBuffer()
      ..write(profile.yearPillar.hanja)
      ..write(profile.monthPillar.hanja)
      ..write(profile.dayPillar.hanja);
    if (knowsHour) buf.write(profile.hourPillar.hanja);
    return buf.toString();
  }
}
