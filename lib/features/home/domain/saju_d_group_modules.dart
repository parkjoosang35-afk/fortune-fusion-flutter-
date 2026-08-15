/// [정통사주 80종 · D04/D10 이달·오늘 그룹] 이번 주 운세 / 오늘 피해야 할 일
/// 계산 모듈.
///
/// C06~C10과 마찬가지로 "원본 파이썬 이식"이 아니라 이번 세션에서 신규
/// 설계한 계산이다(사용자 최종 지시 §3 "D04/D10" 진행). D02/D03/D05~D09가
/// 이미 채택한 패턴([getDailyFortune] — 실제 날짜의 일진 간지를 [Solar]로
/// 구해 일간 대비 십신을 계산)을 그대로 재사용해, [SajuProfile]이 없어도
/// (레거시 `SajuEngine.calculate()` 경로에서도) 동일하게 동작하게 한다.
///
/// [절대 원칙] 새로운 명리 판정 공식을 만들지 않는다. D04는 [getDailyFortune]
/// 을 7일 반복 호출(C10이 [getMonthlyFortune]을 12회 반복 호출한 것과 동일
/// 패턴)하는 것뿐이고, D10은 [RelationshipsEngine.analyzeExternal]
/// (C08과 동일한 공통 엔진)을 오늘 일진 간지로 호출하는 것뿐이다.
///
/// [C08/D10 공통 엔진화 — 사용자 확정 지시 §5] D10은 `saju_c_group_modules.dart`
/// 의 C08이 세운 간지로 호출한 것과 동일한
/// [RelationshipsEngine.analyzeExternal]을, 이번에는 "오늘 일진 간지"로
/// 호출한다. 개별 임시 코드를 만들지 않는다.
library;

import 'package:lunar/lunar.dart' show Solar;

import 'manseryeok/luck_pillar_factory.dart' show buildLuckPillar;
import 'manseryeok/relationships_engine.dart' show RelationshipsEngine;
import 'saju_engine.dart';
import 'saju_fortune_modules.dart' show getDailyFortune;
import 'saju_fortune_rules.dart' show SajuFortuneRules;

// ============================================================
// D04 — 이번 주 운세 (오늘부터 7일간의 getDailyFortune 반복 호출)
// ============================================================

class WeeklyFortuneResult {
  const WeeklyFortuneResult({
    required this.overall,
    required this.dailySummary,
  });

  final String overall;
  final List<String> dailySummary;
}

/// D02/D03/D05~D09가 이미 검증한 [getDailyFortune]을 [startDate]부터
/// 7일간 각각에 대해 재호출한다 — 새 일진 계산 로직을 만들지 않는다
/// (C10이 [getMonthlyFortune]을 12회 재사용한 것과 완전히 동일한 패턴).
WeeklyFortuneResult getWeeklyFortune(
  SajuResult saju,
  SajuFortuneRules rules, {
  required DateTime startDate,
}) {
  const weekdayKr = ['월', '화', '수', '목', '금', '토', '일'];
  final lines = <String>[];
  for (var i = 0; i < 7; i++) {
    final d = startDate.add(Duration(days: i));
    final r = getDailyFortune(saju, rules, year: d.year, month: d.month, day: d.day);
    final headline = r.title.isNotEmpty ? r.title : (r.overall.isNotEmpty ? r.overall : '흐름 정리 중');
    final wd = weekdayKr[(d.weekday - 1) % 7];
    lines.add('${d.month}/${d.day}($wd, ${r.dayGanZhi}) — $headline');
  }
  return WeeklyFortuneResult(
    overall: '${startDate.month}월 ${startDate.day}일부터 7일간의 흐름을 일진 십신 기준으로 정리했어요.',
    dailySummary: lines,
  );
}

// ============================================================
// D10 — 오늘 피해야 할 일 (§5 공통 관계 비교 엔진 사용, 오늘 일진 기준)
// ============================================================

class TodayAvoidResult {
  const TodayAvoidResult({
    required this.title,
    required this.overall,
    required this.advice,
  });

  final String title;
  final String overall;
  final String advice;
}

/// [§5 공통 엔진화] 오늘 일진 간지를 [RelationshipsEngine.analyzeExternal]
/// 로 원국 4주와 교차 비교해 형충파해원진귀문 관계를 찾는다. C08(세운
/// 버전)과 완전히 동일한 함수를 "오늘 일진"으로만 바꿔 호출한다.
///
/// [표현 원칙] "반드시 사고가 난다"는 단정적 진단이 아니라 "평소보다
/// 조심하면 좋은 날"이라는 완곡한 표현만 사용한다.
TodayAvoidResult getTodayAvoidFortune(
  SajuResult saju, {
  required DateTime date,
}) {
  final solar = Solar.fromYmd(date.year, date.month, date.day);
  final lunar = solar.getLunar();
  final dGan = lunar.getDayGan();
  final dZhi = lunar.getDayZhi();

  final yearPillar = buildLuckPillar(saju.pillars['year']!.gan, saju.pillars['year']!.zhi);
  final monthPillar = buildLuckPillar(saju.pillars['month']!.gan, saju.pillars['month']!.zhi);
  final dayPillar = buildLuckPillar(saju.pillars['day']!.gan, saju.pillars['day']!.zhi);
  final hourPillar = buildLuckPillar(saju.pillars['hour']!.gan, saju.pillars['hour']!.zhi);
  final iljinPillar = buildLuckPillar(dGan, dZhi);

  final relations = RelationshipsEngine.analyzeExternal(
    yearPillar: yearPillar,
    monthPillar: monthPillar,
    dayPillar: dayPillar,
    hourPillar: hourPillar,
    externalPillar: iljinPillar,
    externalLabel: '일진',
  );
  const cautionTypes = {'지지충', '형', '자형', '삼형', '파', '해', '원진', '귀문', '천간충'};
  final cautionHits = relations.where((r) => cautionTypes.contains(r.type)).toList();

  final mm = date.month.toString().padLeft(2, '0');
  final dd = date.day.toString().padLeft(2, '0');
  final label = '${date.year}-$mm-$dd $dGan$dZhi (${ganKr[dGan]}${zhiKr[dZhi]})';

  if (cautionHits.isNotEmpty) {
    final types = cautionHits.map((r) => r.type).toSet().join('·');
    return TodayAvoidResult(
      title: '오늘은 신중함이 필요한 날',
      overall: '$label 일진이 원국과 $types 관계를 이뤄, 다툼·실수·감정 기복이 '
          '평소보다 커지기 쉬운 날이에요.',
      advice: '중요한 계약이나 큰 결정은 다음으로 미루고, 감정적인 대응은 자제하면 좋아요.',
    );
  }
  return TodayAvoidResult(
    title: '오늘은 무난하게 지나가는 날',
    overall: '$label 일진에서는 원국과 형충파해 관계가 뚜렷하게 발동하지 않아, '
        '비교적 평온하게 지나갈 가능성이 높은 날이에요.',
    advice: '특별히 피해야 할 일은 없지만, 평소 하던 대로 차분하게 지내면 좋아요.',
  );
}
