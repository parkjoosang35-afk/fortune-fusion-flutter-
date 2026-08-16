/// [정통사주 80종 · 로컬 만세력 엔진] saju_engine_v4_final.zip 의
/// `modules/year_fortune.py`, `monthly_fortune.py`, `daily_fortune.py`,
/// `lucky_items.py`, `compatibility.py` 5개 모듈을 Dart로 완전 이식.
///
/// 세운/월운/일운은 각각 해당 연/월/일의 간지를 [Solar.fromYmd]로 직접
/// 구해(원국과 무관하게, 원본 파이썬과 동일하게 `Solar.fromYmd(year, 6, 15)`
/// 등 대표일 기준) 일간 대비 십신을 계산한 뒤 rules JSON을 룩업한다.
library;

import 'package:lunar/lunar.dart';

import 'saju_engine.dart';
import 'saju_fortune_rules.dart';

Map<String, dynamic> _asMap(dynamic v) =>
    (v as Map?)?.cast<String, dynamic>() ?? const {};

List<T> _asList<T>(dynamic v) =>
    (v as List?)?.map((e) => e as T).toList() ?? const [];

// ============================================================
// C그룹(세운) — get_year_fortune() 이식
// ============================================================

class YearFortuneResult {
  const YearFortuneResult({
    required this.category,
    required this.yearGanZhi,
    required this.yearTheme,
    required this.ganGod,
    required this.zhiGod,
    required this.title,
    required this.overall,
    required this.wealth,
    required this.career,
    required this.love,
    required this.health,
    required this.advice,
  });

  final String category;
  final String yearGanZhi;
  final String yearTheme;
  final String ganGod;
  final String zhiGod;
  final String title;
  final String overall;
  final String wealth;
  final String career;
  final String love;
  final String health;
  final String advice;
}

/// get_year_fortune() 이식. [year] 기본값 2026(원본과 동일한 대표 연도).
YearFortuneResult getYearFortune(
  SajuResult saju,
  SajuFortuneRules rules, {
  int year = 2026,
}) {
  final solar = Solar.fromYmd(year, 6, 15);
  final lunar = solar.getLunar();
  final yGan = lunar.getYearGan();
  final yZhi = lunar.getYearZhi();

  final dayGan = saju.dayMaster.gan;
  final ganGod = getTenGod(dayGan, yGan);
  final zhiGod = getTenGod(dayGan, yZhi);

  final byTenGod = _asMap(rules.yearFortune['by_ten_god']);
  final rule = _asMap(byTenGod[ganGod]);
  final theme =
      (_asMap(rules.luckPillar['yearly_theme_by_stem'])[yGan] as String?) ?? '';

  return YearFortuneResult(
    category: '$year년 운세',
    yearGanZhi: '$yGan$yZhi (${ganKr[yGan]}${zhiKr[yZhi]})',
    yearTheme: theme,
    ganGod: ganGod,
    zhiGod: zhiGod,
    title: (rule['title'] as String?) ?? '',
    overall: (rule['overall'] as String?) ?? '',
    wealth: (rule['wealth'] as String?) ?? '',
    career: (rule['career'] as String?) ?? '',
    love: (rule['love'] as String?) ?? '',
    health: (rule['health'] as String?) ?? '',
    advice: (rule['advice'] as String?) ?? '',
  );
}

// ============================================================
// D01 — 이달의 운세 — get_monthly_fortune() 이식
// ============================================================

class MonthlyFortuneResult {
  const MonthlyFortuneResult({
    required this.category,
    required this.monthGanZhi,
    required this.ganGod,
    required this.zhiGod,
    required this.title,
    required this.overall,
    required this.work,
    required this.wealth,
    required this.love,
    required this.health,
    required this.advice,
  });

  final String category;
  final String monthGanZhi;
  final String ganGod;
  final String zhiGod;
  final String title;
  final String overall;
  final String work;
  final String wealth;
  final String love;
  final String health;
  final String advice;
}

/// get_monthly_fortune() 이식. [year]/[month] 기본값 2026/8(원본과 동일).
MonthlyFortuneResult getMonthlyFortune(
  SajuResult saju,
  SajuFortuneRules rules, {
  int year = 2026,
  int month = 8,
}) {
  final solar = Solar.fromYmd(year, month, 15);
  final lunar = solar.getLunar();
  final mGan = lunar.getMonthGan();
  final mZhi = lunar.getMonthZhi();

  final dayGan = saju.dayMaster.gan;
  final ganGod = getTenGod(dayGan, mGan);
  final zhiGod = getTenGod(dayGan, mZhi);

  final byTenGod = _asMap(rules.monthlyFortune['by_ten_god']);
  final rule = _asMap(byTenGod[ganGod]);

  return MonthlyFortuneResult(
    category: '$year년 $month월 운세',
    monthGanZhi: '$mGan$mZhi (${ganKr[mGan]}${zhiKr[mZhi]})',
    ganGod: ganGod,
    zhiGod: zhiGod,
    title: (rule['title'] as String?) ?? '',
    overall: (rule['overall'] as String?) ?? '',
    work: (rule['work'] as String?) ?? '',
    wealth: (rule['wealth'] as String?) ?? '',
    love: (rule['love'] as String?) ?? '',
    health: (rule['health'] as String?) ?? '',
    advice: (rule['advice'] as String?) ?? '',
  );
}

// ============================================================
// D02/D03 — 오늘/내일의 운세 — get_daily_fortune() 이식
// ============================================================

class DailyFortuneResult {
  const DailyFortuneResult({
    required this.category,
    required this.dayGanZhi,
    required this.ganGod,
    required this.zhiGod,
    required this.title,
    required this.mood,
    required this.overall,
    required this.work,
    required this.wealth,
    required this.love,
    required this.health,
    required this.luckyTime,
    required this.avoidTime,
    required this.luckyColor,
    required this.luckyDirection,
    required this.luckyNumber,
  });

  final String category;
  final String dayGanZhi;
  final String ganGod;
  final String zhiGod;
  final String title;
  final String mood;
  final String overall;
  final String work;
  final String wealth;
  final String love;
  final String health;
  final String luckyTime;
  final String avoidTime;
  final List<String> luckyColor;
  final List<String> luckyDirection;
  final List<int> luckyNumber;
}

/// get_daily_fortune() 이식. [year]/[month]/[day]가 모두 null이면 UTC 오늘.
DailyFortuneResult getDailyFortune(
  SajuResult saju,
  SajuFortuneRules rules, {
  int? year,
  int? month,
  int? day,
}) {
  int y = year ?? 0;
  int m = month ?? 0;
  int d = day ?? 0;
  if (year == null) {
    final today = DateTime.now().toUtc();
    y = today.year;
    m = today.month;
    d = today.day;
  }

  final solar = Solar.fromYmd(y, m, d);
  final lunar = solar.getLunar();
  final dGan = lunar.getDayGan();
  final dZhi = lunar.getDayZhi();

  final dayGan = saju.dayMaster.gan;
  final ganGod = getTenGod(dayGan, dGan);
  final zhiGod = getTenGod(dayGan, dZhi);

  final byTenGod = _asMap(rules.dailyFortune['by_ten_god']);
  final rule = _asMap(byTenGod[ganGod]);

  // 부족한 오행 기반 개운 — min(counts, key=counts.get) 이식.
  // Dart Map 은 삽입 순서를 보존하므로, saju.fiveElementsCount 의 삽입
  // 순서(목/화/토/금/수, saju_engine.dart 참고)가 파이썬 dict 순서와
  // 동일해 동률(tie) 시 첫 항목을 고르는 동작까지 1:1로 일치한다.
  String lackEl = saju.fiveElementsCount.keys.first;
  int lackMin = saju.fiveElementsCount[lackEl] ?? 0;
  saju.fiveElementsCount.forEach((el, c) {
    if (c < lackMin) {
      lackMin = c;
      lackEl = el;
    }
  });
  final lucky = _asMap(_asMap(rules.luckyItems['by_element_lack'])[lackEl]);

  final mm = m.toString().padLeft(2, '0');
  final dd = d.toString().padLeft(2, '0');

  return DailyFortuneResult(
    category: '$y-$mm-$dd 오늘의 운세',
    dayGanZhi: '$dGan$dZhi (${ganKr[dGan]}${zhiKr[dZhi]})',
    ganGod: ganGod,
    zhiGod: zhiGod,
    title: (rule['title'] as String?) ?? '',
    mood: (rule['mood'] as String?) ?? '',
    overall: (rule['overall'] as String?) ?? '',
    work: (rule['work'] as String?) ?? '',
    wealth: (rule['wealth'] as String?) ?? '',
    love: (rule['love'] as String?) ?? '',
    health: (rule['health'] as String?) ?? '',
    luckyTime: (rule['lucky_time'] as String?) ?? '',
    avoidTime: (rule['avoid_time'] as String?) ?? '',
    luckyColor: _asList<String>(lucky['colors']),
    luckyDirection: _asList<String>(lucky['directions']),
    luckyNumber: _asList<int>(lucky['numbers']),
  );
}

// ============================================================
// H그룹(개운·풍수) — get_lucky_items() 이식
// ============================================================

class LuckyItemsResult {
  const LuckyItemsResult({
    required this.lackElement,
    required this.colors,
    required this.directions,
    required this.numbers,
    required this.items,
    required this.food,
    required this.activities,
    required this.advice,
  });

  final String lackElement;
  final List<String> colors;
  final List<String> directions;
  final List<int> numbers;
  final List<String> items;
  final List<String> food;
  final List<String> activities;
  final String advice;
}

/// get_lucky_items() 이식.
LuckyItemsResult getLuckyItems(SajuResult saju, SajuFortuneRules rules) {
  String lackEl = saju.fiveElementsCount.keys.first;
  int lackMin = saju.fiveElementsCount[lackEl] ?? 0;
  saju.fiveElementsCount.forEach((el, c) {
    if (c < lackMin) {
      lackMin = c;
      lackEl = el;
    }
  });
  final lucky = _asMap(_asMap(rules.luckyItems['by_element_lack'])[lackEl]);

  return LuckyItemsResult(
    lackElement: lackEl,
    colors: _asList<String>(lucky['colors']),
    directions: _asList<String>(lucky['directions']),
    numbers: _asList<int>(lucky['numbers']),
    items: _asList<String>(lucky['items']),
    food: _asList<String>(lucky['food']),
    activities: _asList<String>(lucky['activities']),
    advice: (lucky['advice'] as String?) ?? '',
  );
}

// ============================================================
// E그룹(궁합) — get_compatibility() 이식 (상대방 사주 필요)
// ============================================================

class CompatibilityResult {
  const CompatibilityResult({
    required this.personADayMaster,
    required this.personADayZhi,
    required this.personBDayMaster,
    required this.personBDayZhi,
    required this.ganScore,
    required this.ganNote,
    required this.zhiRelationType,
    required this.zhiRelationNote,
    required this.finalScore,
    required this.band,
    required this.bandDesc,
  });

  final String personADayMaster;
  final String personADayZhi;
  final String personBDayMaster;
  final String personBDayZhi;
  final int ganScore;
  final String ganNote;
  final String zhiRelationType;
  final String zhiRelationNote;
  final int finalScore;
  final String band;
  final String bandDesc;
}

(int low, int high) _bandRange(String b) {
  switch (b) {
    case '90+':
      return (90, 100);
    case '80-89':
      return (80, 89);
    case '70-79':
      return (70, 79);
    case '60-69':
      return (60, 69);
    case '50-59':
      return (50, 59);
    default:
      return (0, 49);
  }
}

/// get_compatibility() 이식.
CompatibilityResult getCompatibility(
  SajuResult sajuA,
  SajuResult sajuB,
  SajuFortuneRules rules,
) {
  final aGan = sajuA.dayMaster.gan;
  final bGan = sajuB.dayMaster.gan;
  final aZhi = sajuA.pillars['day']!.zhi;
  final bZhi = sajuB.pillars['day']!.zhi;

  final ganToGan = _asMap(rules.compatibility['gan_to_gan']);
  final combo = '$aGan$bGan';
  final ganResult = _asMap(ganToGan[combo]);
  final ganScore = (ganResult['score'] as int?) ?? 60;
  final ganNote = (ganResult['note'] as String?) ?? '표준 궁합';

  final zhiCombos = _asMap(rules.compatibility['zhi_combos']);
  final zhiPair = '$aZhi$bZhi';
  final zhiPairR = '$bZhi$aZhi';
  String zhiRelation = '무관';
  String zhiNote = '';
  for (final entry in zhiCombos.entries) {
    final info = _asMap(entry.value);
    final pairs = _asList<String>(info['pairs']);
    for (final p in pairs) {
      if (p.length == 2 && (zhiPair == p || zhiPairR == p)) {
        zhiRelation = entry.key;
        zhiNote = (info['note'] as String?) ?? '';
      }
    }
  }

  int finalScore = ganScore;
  switch (zhiRelation) {
    case '六合':
      finalScore += 8;
      break;
    case '三合':
      finalScore += 5;
      break;
    case '沖':
      finalScore -= 15;
      break;
    case '刑':
      finalScore -= 10;
      break;
  }
  finalScore = finalScore.clamp(0, 100);

  String band = '0-49';
  for (final b in const ['90+', '80-89', '70-79', '60-69', '50-59']) {
    final (low, high) = _bandRange(b);
    if (finalScore >= low && finalScore <= high) {
      band = b;
      break;
    }
  }
  final bandDesc =
      (rules.compatibility['score_bands'] as Map?)?[band] as String? ?? '';

  return CompatibilityResult(
    personADayMaster: '$aGan(${ganKr[aGan]})',
    personADayZhi: '$aZhi(${zhiKr[aZhi]})',
    personBDayMaster: '$bGan(${ganKr[bGan]})',
    personBDayZhi: '$bZhi(${zhiKr[bZhi]})',
    ganScore: ganScore,
    ganNote: ganNote,
    zhiRelationType: zhiRelation,
    zhiRelationNote: zhiNote,
    finalScore: finalScore,
    band: band,
    bandDesc: bandDesc,
  );
}
