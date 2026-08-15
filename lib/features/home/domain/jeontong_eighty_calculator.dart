/// [정통사주 80종 · 로컬 만세력 엔진] saju_engine_v4_final.zip 의
/// `modules/eighty_categories.py`(CATEGORY_INDEX 80개)를 Dart로 완전 이식.
///
/// 각 카테고리 함수는 [SajuResult] + [SajuFullInterpretation](+ 필요 시
/// [SajuFortuneRules])을 입력받아, 원본 파이썬과 동일한 키-값 구조의
/// [Map<String, dynamic>]을 반환한다. 이 Map은
/// [jeontong_eighty_report_builder.dart]에서 [FortuneReport]로 변환된다.
///
/// [플레이스홀더 정책] 원본 파이썬도 B02~B10, C06~C10, D04/D10, E01~E07(상대
/// 사주 필요) 등 다수를 `{"category":..., "message":...}` 형태의 안내
/// 플레이스홀더로 남겨두었다. 이 이식본도 동일하게 플레이스홀더를 그대로
/// 옮긴다(새 로직을 추가로 만들지 않음 — 원본과 1:1 대응 유지).
library;

import 'jeontong_eighty_matrix.dart';
import 'manseryeok/saju_profile.dart' show SajuProfile;
import 'saju_c_group_modules.dart';
import 'saju_daewoon_modules.dart';
import 'saju_engine.dart';
import 'saju_fortune_modules.dart';
import 'saju_fortune_rules.dart';
import 'saju_interpreter.dart';
import 'saju_life_modules.dart';

/// 80종 카테고리 1건의 계산 결과 — 원본 파이썬 dict를 그대로 옮긴 컨테이너.
/// 키 이름은 파이썬 원본의 키(스네이크/한글 혼용)를 그대로 보존해, 향후
/// 원본과의 대조 검증이 쉽도록 한다.
class JeontongCategoryResult {
  const JeontongCategoryResult({required this.category, required this.data});

  /// 결과의 "제목" 성격 필드(파이썬의 `category`/`title` 등에서 채움).
  final String category;

  /// 원본 파이썬 dict 그대로의 나머지 키-값.
  final Map<String, dynamic> data;

  String? str(String key) => data[key] as String?;
  List<String> strList(String key) =>
      (data[key] as List?)?.map((e) => e.toString()).toList() ?? const [];
}

/// 80종 계산에 필요한 컨텍스트 묶음(원국 + 해석 + 룰).
///
/// [원본과의 차이 - 의도적] 원본 파이썬 `eighty_categories.py`는 데모 실행을
/// 위해 세운/월운 연도를 2026년 8월로, "오늘의 운세"/"내일의 운세"조차
/// 2026-08-12/2026-08-13으로 하드코딩했다(`CATEGORY_INDEX`의 `get_year_fortune(s,
/// 2026)`, `get_daily_fortune(s, 2026, 8, 12)` 등). 이 이식본은 실제 서비스에서
/// "오늘/이달/올해"가 실제 달력 날짜를 반영해야 하므로, [referenceDate]
/// (기본값 `DateTime.now()`)를 기준으로 [year]/[month]를 유도하고, D02(오늘)/
/// D03(내일)/D05~D08(오늘 포커스)도 [referenceDate] 기준 오늘/내일 날짜를
/// 사용하도록 바꿨다. 골든 테스트는 [referenceDate]를 고정 날짜(2026-08-13)로
/// 주입해 결정론을 유지한다 — 이 경우 연/월이 우연히 원본과 동일한
/// 2026년 8월이 되어 결과 구조가 원본과 정확히 대조 가능하다.
class JeontongCalcContext {
  JeontongCalcContext({
    required this.saju,
    required this.interp,
    required this.rules,
    DateTime? referenceDate,
    this.profile,
  }) : referenceDate = referenceDate ?? DateTime.now(),
       year = (referenceDate ?? DateTime.now()).year,
       month = (referenceDate ?? DateTime.now()).month;

  final SajuResult saju;
  final SajuFullInterpretation interp;
  final SajuFortuneRules rules;

  /// "오늘"의 기준 시점 — D02/D03/D05~D08 계산에 사용.
  final DateTime referenceDate;

  /// C그룹(세운)·D01(월운) 대표 연/월 — [referenceDate]에서 유도.
  final int year;
  final int month;

  /// [B08/B09 전용] PHASE1~4가 이미 계산한 [SajuProfile](용신/기신 포함).
  /// PHASE1~4 신규 엔진 경로(`migratedCategoryIds`)를 탈 때만 non-null로
  /// 채워진다 — 레거시 `SajuEngine.calculate()` 경로에서는 null이며, 이
  /// 경우 [getBestDaewoonPeriods]/[getWorstDaewoonPeriods]가 "판단 불가"로
  /// 안전하게 처리한다(새로 용신을 계산하지 않는다).
  final SajuProfile? profile;
}

JeontongCategoryResult _placeholder(String category, String message) =>
    JeontongCategoryResult(category: category, data: {'message': message});

JeontongCategoryResult _needsPartner(String category) =>
    JeontongCategoryResult(category: category, data: {'note': '상대 사주 필요'});

// ============================================================
// A. 평생운 (10)
// ============================================================

JeontongCategoryResult _a01(JeontongCalcContext ctx) {
  final r = getLifeTotal(ctx.interp);
  return JeontongCategoryResult(
    category: '평생 총운',
    data: {
      'headline': r.headline,
      'core_nature': r.coreNature,
      'personality': r.personality,
      'strengths': r.strengths,
      'weaknesses': r.weaknesses,
      'five_elements': r.fiveElements,
      'life_theme': r.lifeTheme,
      'summary': r.summary,
    },
  );
}

JeontongCategoryResult _a02(JeontongCalcContext ctx) {
  // {"category":"성격·기질", **get_life_total(s)} 이식.
  final base = _a01(ctx);
  return JeontongCategoryResult(category: '성격·기질', data: base.data);
}

JeontongCategoryResult _a03(JeontongCalcContext ctx) {
  final r = getLifeWealth(ctx.interp);
  return JeontongCategoryResult(
    category: '평생 재물운',
    data: {
      'verdict': r.verdict,
      'structure': r.structure,
      'message': r.message,
      'asset_style': r.assetStyle,
      'peak_period': r.peakPeriod,
    },
  );
}

JeontongCategoryResult _a04(JeontongCalcContext ctx) {
  final r = getLifeCareer(ctx.interp);
  return JeontongCategoryResult(
    category: '평생 직업·명예운',
    data: {
      'structure': r.structure,
      'message': r.message,
      'recommended_jobs': r.recommendedJobs,
      'work_style': r.workStyle,
      'growth_path': r.growthPath,
    },
  );
}

JeontongCategoryResult _a05(JeontongCalcContext ctx) {
  final r = getLifeHealth(ctx.saju, ctx.interp);
  return JeontongCategoryResult(
    category: '평생 건강운',
    data: {
      'core_organs': r.coreOrgans,
      'lifetime_warnings': r.lifetimeWarnings,
      'advice_food': r.adviceFood,
      'lifestyle': r.lifestyle,
    },
  );
}

JeontongCategoryResult _a06(JeontongCalcContext ctx) {
  final r = getLifeLove(ctx.saju, ctx.interp);
  return JeontongCategoryResult(
    category: '평생 애정운',
    data: {
      'spouse_god': r.spouseGod,
      'style': r.style,
      'message': r.message,
      'marriage_timing': r.marriageTiming,
      'advice': r.advice,
    },
  );
}

JeontongCategoryResult _a07(JeontongCalcContext ctx) {
  final r = getLifeChildren(ctx.saju, ctx.interp);
  return JeontongCategoryResult(
    category: '평생 자녀운',
    data: {
      'child_god': r.childGod,
      'count': r.count,
      'style': r.style,
      'message': r.message,
      'timing_hint': r.timingHint,
    },
  );
}

JeontongCategoryResult _a08(JeontongCalcContext ctx) {
  final r = getLifeParentsSiblings(ctx.interp);
  return JeontongCategoryResult(
    category: '평생 부모·형제운',
    data: {
      'parent_god': r.parentGod,
      'parent_count': r.parentCount,
      'parent_message': r.parentMessage,
      'sibling_god': r.siblingGod,
      'sibling_count': r.siblingCount,
      'sibling_message': r.siblingMessage,
    },
  );
}

JeontongCategoryResult _a09(JeontongCalcContext ctx) {
  final r = getLifeStudy(ctx.saju, ctx.interp);
  return JeontongCategoryResult(
    category: '평생 학업·시험운',
    data: {
      'study_god_count': r.studyGodCount,
      'has_munchang': r.hasMunchang,
      'style': r.style,
      'message': r.message,
    },
  );
}

JeontongCategoryResult _a10(JeontongCalcContext ctx) {
  final r = getLifeTransitionPoints(ctx.saju);
  return JeontongCategoryResult(
    category: '인생 5대 전환점',
    data: {
      'points': [
        for (final p in r.points)
          {
            'start_age': p.startAge,
            'start_year': p.startYear,
            'gan_zhi_kr': p.ganZhiKr,
          },
      ],
      'summary': r.summary,
    },
  );
}

// ============================================================
// B. 대운 (10)
// ============================================================

JeontongCategoryResult _b01(JeontongCalcContext ctx) {
  final luck = ctx.interp.currentLuckAnalysis;
  return JeontongCategoryResult(
    category: '현재 대운',
    data: {
      'title': luck.title,
      'age_range': luck.ageRange,
      'gan_god_name': luck.ganGodName,
      'gan_god_easy': luck.ganGodEasy,
      'gan_god_positive': luck.ganGodPositive,
      'zhi_god_name': luck.zhiGodName,
      'zhi_god_easy': luck.zhiGodEasy,
      'zhi_god_positive': luck.zhiGodPositive,
      'message': luck.message,
    },
  );
}

JeontongCategoryResult _b02(JeontongCalcContext ctx) {
  final r = getDaewoonWealthFlow(ctx.saju);
  return JeontongCategoryResult(
    category: '대운별 재물 흐름',
    data: {
      'timeline': r.timeline,
      'peak_periods': r.peakPeriods,
      'summary': r.summary,
    },
  );
}

JeontongCategoryResult _b03(JeontongCalcContext ctx) {
  final r = getDaewoonCareerFlow(ctx.saju);
  return JeontongCategoryResult(
    category: '대운별 직업 변화',
    data: {
      'timeline': r.timeline,
      'shift_periods': r.shiftPeriods,
      'summary': r.summary,
    },
  );
}

JeontongCategoryResult _b04(JeontongCalcContext ctx) {
  final r = getDaewoonHealthFlow(ctx.saju);
  return JeontongCategoryResult(
    category: '대운별 건강 변화',
    data: {
      'timeline': r.timeline,
      'caution_periods': r.cautionPeriods,
      'summary': r.summary,
    },
  );
}

JeontongCategoryResult _b05(JeontongCalcContext ctx) {
  final r = getDaewoonLoveFlow(ctx.saju);
  return JeontongCategoryResult(
    category: '대운별 애정 변화',
    data: {
      'timeline': r.timeline,
      'active_periods': r.activePeriods,
      'summary': r.summary,
    },
  );
}

JeontongCategoryResult _b06(JeontongCalcContext ctx) {
  final r = getDaewoonTransitionCautions(ctx.saju);
  return JeontongCategoryResult(
    category: '대운 전환기 주의사항',
    data: {
      'timeline': r.timeline,
      'caution_windows': r.cautionWindows,
      'summary': r.summary,
    },
  );
}

JeontongCategoryResult _b07(JeontongCalcContext ctx) {
  final r = getNextDaewoonPreview(ctx.saju);
  return JeontongCategoryResult(
    category: '다음 대운 미리보기',
    data: {
      'has_next': r.hasNext,
      'start_age': r.startAge,
      'start_year': r.startYear,
      'gan_zhi_kr': r.ganZhiKr,
      'ten_gods': r.tenGods,
      'message': r.message,
    },
  );
}

JeontongCategoryResult _b08(JeontongCalcContext ctx) {
  final r = getBestDaewoonPeriods(ctx.saju, ctx.profile);
  return JeontongCategoryResult(
    category: '인생 최고 대운 시기',
    data: {
      'periods': r.periods,
      'summary': r.summary,
    },
  );
}

JeontongCategoryResult _b09(JeontongCalcContext ctx) {
  final r = getWorstDaewoonPeriods(ctx.saju, ctx.profile);
  return JeontongCategoryResult(
    category: '인생 최악 대운 시기',
    data: {
      'periods': r.periods,
      'summary': r.summary,
    },
  );
}

JeontongCategoryResult _b10(JeontongCalcContext ctx) {
  final r = getDaewoonSewoonCombo(ctx.saju, year: ctx.year);
  return JeontongCategoryResult(
    category: '대운×세운 조합',
    data: {
      'daewoon_gan_zhi_kr': r.daewoonGanZhiKr,
      'daewoon_ten_gods': r.daewoonTenGods,
      'sewoon_gan_zhi_kr': r.sewoonGanZhiKr,
      'sewoon_ten_gods': r.sewoonTenGods,
      'synergy': r.synergy,
      'message': r.message,
    },
  );
}

// ============================================================
// C. 세운(올해) (10)
// ============================================================

JeontongCategoryResult _yearFortuneToResult(
  JeontongCalcContext ctx,
  String category,
) {
  final r = getYearFortune(ctx.saju, ctx.rules, year: ctx.year);
  return JeontongCategoryResult(
    category: category,
    data: {
      'year_gan_zhi': r.yearGanZhi,
      'year_theme': r.yearTheme,
      'gan_god': r.ganGod,
      'zhi_god': r.zhiGod,
      'title': r.title,
      'overall': r.overall,
      'wealth': r.wealth,
      'career': r.career,
      'love': r.love,
      'health': r.health,
      'advice': r.advice,
    },
  );
}

JeontongCategoryResult _c06(JeontongCalcContext ctx) {
  final r = getYearlyMovementFortune(ctx.saju, year: ctx.year);
  return JeontongCategoryResult(
    category: '올해 이사·이동수',
    data: {
      'title': r.title,
      'overall': r.overall,
      'advice': r.advice,
    },
  );
}

JeontongCategoryResult _c07(JeontongCalcContext ctx) {
  final r = getYearlyExamFortune(ctx.saju, year: ctx.year);
  return JeontongCategoryResult(
    category: '올해 시험·자격운',
    data: {
      'title': r.title,
      'overall': r.overall,
      'advice': r.advice,
    },
  );
}

JeontongCategoryResult _c08(JeontongCalcContext ctx) {
  final r = getYearlyLegalRiskFortune(ctx.saju, year: ctx.year);
  return JeontongCategoryResult(
    category: '올해 소송·관재수',
    data: {
      'title': r.title,
      'overall': r.overall,
      'advice': r.advice,
    },
  );
}

JeontongCategoryResult _c09(JeontongCalcContext ctx) {
  final r = getYearlyRelationshipFortune(ctx.saju, year: ctx.year);
  return JeontongCategoryResult(
    category: '올해 인간관계',
    data: {
      'title': r.title,
      'overall': r.overall,
      'advice': r.advice,
    },
  );
}

JeontongCategoryResult _c10(JeontongCalcContext ctx) {
  final r = getYearlyMonthlyOverview(ctx.saju, ctx.rules, year: ctx.year);
  return JeontongCategoryResult(
    category: '올해 12개월 월별',
    data: {
      'overall': r.overall,
      'monthly_summary': r.monthlySummary,
    },
  );
}

// ============================================================
// D. 이달·오늘 (10)
// ============================================================

JeontongCategoryResult _monthlyFortuneToResult(JeontongCalcContext ctx) {
  final r = getMonthlyFortune(ctx.saju, ctx.rules, year: ctx.year, month: ctx.month);
  return JeontongCategoryResult(
    category: r.category,
    data: {
      'month_gan_zhi': r.monthGanZhi,
      'gan_god': r.ganGod,
      'zhi_god': r.zhiGod,
      'title': r.title,
      'overall': r.overall,
      'work': r.work,
      'wealth': r.wealth,
      'love': r.love,
      'health': r.health,
      'advice': r.advice,
    },
  );
}

Map<String, dynamic> _dailyFortuneToMap(DailyFortuneResult r) => {
  'day_gan_zhi': r.dayGanZhi,
  'gan_god': r.ganGod,
  'zhi_god': r.zhiGod,
  'title': r.title,
  'mood': r.mood,
  'overall': r.overall,
  'work': r.work,
  'wealth': r.wealth,
  'love': r.love,
  'lucky_time': r.luckyTime,
  'avoid_time': r.avoidTime,
  'lucky_color': r.luckyColor,
  'lucky_direction': r.luckyDirection,
  'lucky_number': r.luckyNumber,
};

JeontongCategoryResult _dailyFortuneToResult(
  JeontongCalcContext ctx, {
  int? year,
  int? month,
  int? day,
  String? focusTag,
  String? categoryOverride,
}) {
  final r = getDailyFortune(ctx.saju, ctx.rules, year: year, month: month, day: day);
  final data = _dailyFortuneToMap(r);
  if (focusTag != null) data['focus'] = focusTag;
  return JeontongCategoryResult(
    category: categoryOverride ?? r.category,
    data: data,
  );
}

JeontongCategoryResult _luckyItemsToResult(
  JeontongCalcContext ctx, {
  String category = '개운 아이템',
}) {
  final r = getLuckyItems(ctx.saju, ctx.rules);
  return JeontongCategoryResult(
    category: category,
    data: {
      'lack_element': r.lackElement,
      'colors': r.colors,
      'directions': r.directions,
      'numbers': r.numbers,
      'items': r.items,
      'food': r.food,
      'activities': r.activities,
      'advice': r.advice,
    },
  );
}

// ============================================================
// 80종 CATEGORY_INDEX 매핑 — eighty_categories.py 이식
// ============================================================

typedef _CategoryFn = JeontongCategoryResult Function(JeontongCalcContext ctx);

final Map<String, _CategoryFn> _categoryIndex = {
  // A. 평생운 (10)
  'A01': _a01,
  'A02': _a02,
  'A03': _a03,
  'A04': _a04,
  'A05': _a05,
  'A06': _a06,
  'A07': _a07,
  'A08': _a08,
  'A09': _a09,
  'A10': _a10,

  // B. 대운 (10)
  'B01': _b01,
  'B02': _b02,
  'B03': _b03,
  'B04': _b04,
  'B05': _b05,
  'B06': _b06,
  'B07': _b07,
  'B08': _b08,
  'B09': _b09,
  'B10': _b10,

  // C. 세운(올해) (10)
  'C01': (ctx) => _yearFortuneToResult(ctx, '${ctx.year}년 운세'),
  'C02': (ctx) => _yearFortuneToResult(ctx, '올해 재물운'),
  'C03': (ctx) => _yearFortuneToResult(ctx, '올해 직업운'),
  'C04': (ctx) => _yearFortuneToResult(ctx, '올해 애정운'),
  'C05': (ctx) => _yearFortuneToResult(ctx, '올해 건강운'),
  'C06': (ctx) => _c06(ctx),
  'C07': (ctx) => _c07(ctx),
  'C08': (ctx) => _c08(ctx),
  'C09': (ctx) => _c09(ctx),
  'C10': (ctx) => _c10(ctx),

  // D. 이달·오늘 (10)
  'D01': (ctx) => _monthlyFortuneToResult(ctx),
  'D02': (ctx) => _dailyFortuneToResult(
    ctx,
    year: ctx.referenceDate.year,
    month: ctx.referenceDate.month,
    day: ctx.referenceDate.day,
  ),
  'D03': (ctx) {
    final tomorrow = ctx.referenceDate.add(const Duration(days: 1));
    return _dailyFortuneToResult(
      ctx,
      year: tomorrow.year,
      month: tomorrow.month,
      day: tomorrow.day,
    );
  },
  'D04': (ctx) => _placeholder('이번 주', '7일 일진 조합'),
  'D05': (ctx) => _dailyFortuneToResult(
    ctx,
    year: ctx.referenceDate.year,
    month: ctx.referenceDate.month,
    day: ctx.referenceDate.day,
    focusTag: '재물',
  ),
  'D06': (ctx) => _dailyFortuneToResult(
    ctx,
    year: ctx.referenceDate.year,
    month: ctx.referenceDate.month,
    day: ctx.referenceDate.day,
    focusTag: '애정',
  ),
  'D07': (ctx) => _dailyFortuneToResult(
    ctx,
    year: ctx.referenceDate.year,
    month: ctx.referenceDate.month,
    day: ctx.referenceDate.day,
    focusTag: '건강',
  ),
  'D08': (ctx) => _dailyFortuneToResult(
    ctx,
    year: ctx.referenceDate.year,
    month: ctx.referenceDate.month,
    day: ctx.referenceDate.day,
    focusTag: '시간',
  ),
  'D09': (ctx) => _luckyItemsToResult(ctx),
  'D10': (ctx) => _placeholder('오늘 금기', '일진 충·형 발동 확인'),

  // E. 궁합 (10) — 상대 사주 필요(원본과 동일하게 플레이스홀더)
  'E01': (ctx) => _needsPartner('부부 궁합'),
  'E02': (ctx) => _needsPartner('연인 궁합'),
  'E03': (ctx) => _needsPartner('결혼 궁합'),
  'E04': (ctx) => _needsPartner('사업 궁합'),
  'E05': (ctx) => _needsPartner('직장 궁합'),
  'E06': (ctx) => _needsPartner('가족 궁합'),
  'E07': (ctx) => _needsPartner('친구 궁합'),
  'E08': (ctx) => _placeholder('띠 궁합', '연지 기준 12띠 대조'),
  'E09': (ctx) => _placeholder('오행 궁합', '오행 상보성 대조'),
  'E10': (ctx) => _placeholder('겉속궁합', '연주(겉)·일주(속) 분리 대조'),

  // F. 특수 주제 (10)
  'F01': (ctx) => _a03(ctx),
  'F02': (ctx) => _a04(ctx),
  'F03': (ctx) => _placeholder('사업 아이템', '일간 오행 기반 업종 추천'),
  'F04': (ctx) => _placeholder('창업 vs 직장', '관성 유무·공망 확인'),
  'F05': (ctx) => _placeholder('이직 타이밍', '관성 대운·세운 확인'),
  'F06': (ctx) => _placeholder('부동산', '토·재성 대운 확인'),
  'F07': (ctx) => _placeholder('투자 성향', '편재(공격)/정재(방어) 비율'),
  'F08': (ctx) => _placeholder('결혼 적령기', '재/관성 대운 확인'),
  'F09': (ctx) => _placeholder('출산 시기', '식신 세운 확인'),
  'F10': (ctx) => _placeholder('해외운', '역마·편재·수 오행 확인'),

  // G. 건강 (10)
  'G01': (ctx) => _a05(ctx),
  'G02': (ctx) => _a05(ctx),
  'G03': (ctx) => _placeholder('대운별 건강', '각 대운 오행 편중'),
  'G04': (ctx) => _luckyItemsToResult(ctx, category: '나에게 좋은 음식'),
  'G05': (ctx) => _placeholder('금기 음식', '과다 오행 강화 음식 피하기'),
  'G06': (ctx) => _placeholder('체질', '일간 오행+계절 기반'),
  'G07': (ctx) => _placeholder('정신 건강', '수·화 균형 확인'),
  'G08': (ctx) => _placeholder('사고수', '양인·백호·형충 확인'),
  'G09': (ctx) => _placeholder('장수', '오행 균형·인성 확인'),
  'G10': (ctx) => _placeholder('면역', '일간 강도·수 오행 확인'),

  // H. 개운·풍수 (10)
  'H01': (ctx) => _luckyItemsToResult(ctx, category: '행운의 색'),
  'H02': (ctx) => _luckyItemsToResult(ctx, category: '행운의 방향'),
  'H03': (ctx) => _luckyItemsToResult(ctx, category: '행운의 숫자'),
  'H04': (ctx) => _luckyItemsToResult(ctx, category: '행운의 보석'),
  'H05': (ctx) => _luckyItemsToResult(ctx, category: '부적·개운 아이템'),
  'H06': (ctx) => _placeholder('작명', '부족 오행 보완 자음/모음'),
  'H07': (ctx) => _luckyItemsToResult(ctx, category: '집·사무실 방향'),
  'H08': (ctx) => _placeholder('배치', '길방+오행 색조합'),
  'H09': (ctx) => _placeholder('반려동물', '띠·오행 대조'),
  'H10': (ctx) => _luckyItemsToResult(ctx, category: '개운 습관'),
};

/// 카테고리 id(예: 'A01')로 해당 80종 계산을 실행한다.
/// run_all_categories()의 단건 버전 — eighty_categories.py 이식.
JeontongCategoryResult runJeontongCategory(
  String categoryId,
  JeontongCalcContext ctx,
) {
  final fn = _categoryIndex[categoryId];
  if (fn == null) {
    return _placeholder(categoryId, '준비 중인 카테고리예요');
  }
  return fn(ctx);
}

/// [미션 3 · 35종 플레이스홀더 UX 안전장치] 위 `_categoryIndex`에서
/// `_placeholder(...)` 또는 `_needsPartner(...)`를 그대로 반환하는(=실제
/// 만세력 계산 없이 안내 메시지만 담는) 카테고리 id 35개의 정적 목록.
///
/// [2026-08-15 B02~B10 실계산 전환] B그룹(대운) 9종은 PHASE4 대운 데이터
/// 기반 실계산으로 전환되어 이 목록에서 제외되었다(44 → 35, 사용자 확정
/// 지시 §3/§4).
///
/// [2026-08-15 C06~C10 실계산 전환] C그룹(세운) 나머지 5종(이동수/시험운/
/// 관재수/인간관계/12개월)도 세운 간지 기반 실계산으로 전환되어 이
/// 목록에서 제외되었다(35 → 30, 사용자 확정 지시 §3 "C06~C10 진행").
/// C08(관재수)은 §5 "C08/D10 공통 엔진화" 지시에 따라
/// `RelationshipsEngine.analyzeExternal()`(원국+세운 교차 비교 공용
/// 메서드)을 사용한다.
///
/// [왜 정적 목록인가] `_categoryIndex`는 함수 매핑이라 런타임에 "이 id가
/// placeholder인지"를 알려면 [JeontongCalcContext](실제 사주 계산 결과)를
/// 먼저 만들어야 한다. 하지만 결과 화면은 프로필이 없는 방문자에게도
/// 즉시(계산 없이) 톤다운 배지를 보여줘야 하므로, 위 매핑 정의와 1:1로
/// 대조해 만든 고정 Set을 별도로 둔다(테스트
/// `jeontong_placeholder_categories_test.dart`가 이 목록과 실제
/// `runJeontongCategory()` 실행 결과의 일치를 회귀 검증한다 — 목록이
/// `_categoryIndex`와 어긋나면 테스트가 즉시 실패한다).
///
/// [UX 정책] 이 35종은 "계산이 안 된 결과"가 아니라 "아직 상세 만세력
/// 계산 대신 일반적인 명리 해설을 담은 카테고리"다. 차단하거나 숨기지
/// 않고, 결과 화면에 정직한 톤다운 안내만 추가한다(사용자 확정 지시 —
/// "일반 풀이 참고용 톤으로 정직하게 표시").
const Set<String> kJeontongPlaceholderCategoryIds = {
  // D. 이달·오늘
  'D04', 'D10',
  // E. 궁합 (전부 상대 사주 필요)
  'E01', 'E02', 'E03', 'E04', 'E05', 'E06', 'E07', 'E08', 'E09', 'E10',
  // F. 특수 주제
  'F03', 'F04', 'F05', 'F06', 'F07', 'F08', 'F09', 'F10',
  // G. 건강
  'G03', 'G05', 'G06', 'G07', 'G08', 'G09', 'G10',
  // H. 개운·풍수
  'H06', 'H08', 'H09',
};

/// 80종 전체 실행 — run_all_categories() 이식.
Map<String, JeontongCategoryResult> runAllJeontongCategories(
  JeontongCalcContext ctx,
) {
  final results = <String, JeontongCategoryResult>{};
  for (final entry in JeontongEightyMatrix.all) {
    results[entry.id] = runJeontongCategory(entry.id, ctx);
  }
  return results;
}
