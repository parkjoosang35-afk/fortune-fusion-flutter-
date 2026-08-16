/// [정통사주 80종 · 로컬 만세력 엔진] saju_engine_v4_final.zip 의
/// `modules/eighty_categories.py`(CATEGORY_INDEX 80개)를 Dart로 완전 이식.
///
/// 각 카테고리 함수는 [SajuResult] + [SajuFullInterpretation](+ 필요 시
/// [SajuFortuneRules])을 입력받아, 원본 파이썬과 동일한 키-값 구조의
/// [Map<String, dynamic>]을 반환한다. 이 Map은
/// [jeontong_eighty_report_builder.dart]에서 [FortuneReport]로 변환된다.
///
/// [플레이스홀더 정책] 원본 파이썬은 B02~B10, C06~C10, D04/D10,
/// E01~E07(상대 사주 필요) 등 다수를 `{"category":..., "message":...}`
/// 형태의 안내 플레이스홀더로 남겨두었으나, 이후 사용자 확정 지시에 따라
/// B02~B10/C06~C10/D04/D10/F03~F08/F10/F09/E08~E10/G03~G08/G10은 순차적으로
/// PHASE1~4 기반 실계산으로 전환 완료되었다(아래 [kJeontongPlaceholderCategoryIds]
/// 갱신 이력 참고). 끝까지 구현 불가로 판정된 나머지 11종(E01~E07/G09/
/// H06/H08/H09)은 카탈로그([JeontongEightyMatrix])에서 완전히 삭제되어
/// 현재 총 카테고리 수는 69종이다(80종 숫자에 집착하지 않음 — 사용자 확정
/// 지시 §4/§7).
library;

import 'interpretation/analyzers/career_analyzer.dart';
import 'interpretation/analyzers/health_analyzer.dart';
import 'interpretation/analyzers/life_overall_analyzer.dart';
import 'interpretation/analyzers/love_analyzer.dart';
import 'interpretation/analyzers/wealth_analyzer.dart';
import 'jeontong_eighty_matrix.dart';
import 'manseryeok/saju_profile.dart' show SajuProfile;
import 'saju_c_group_modules.dart';
import 'saju_d_group_modules.dart';
import 'saju_daewoon_modules.dart';
import 'saju_e_group_modules.dart';
import 'saju_engine.dart';
import 'saju_f_group_modules.dart';
import 'saju_fortune_modules.dart';
import 'saju_fortune_rules.dart';
import 'saju_g_group_modules.dart';
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

// ============================================================
// A. 평생운 (10)
// ============================================================

/// [j7 · A01 해석 로직 마이그레이션 — 사용자 지시 §21 13단계 "실제 화면
/// 연결(wiring)", A05(HealthAnalyzer) wiring과 동일한 패턴] 레거시
/// `getLifeTotal()`(지배 십신 이름 하나로 `_lifeThemeByDominant` 10개짜리
/// 고정 테이블을 룩업하는 단순 방식)을 폐기하고, [LifeOverallAnalyzer]
/// (SajuProfile의 십신 5대범주 집계·신강신약·용신/기신·오행 편중·신살을
/// 직접 조회해 매번 새로 판정)의 결과를 사용한다.
///
/// [키 이름 유지 이유] `JeontongCategoryResult.data`의 8개 키(headline/
/// core_nature/personality/strengths/weaknesses/five_elements/life_theme/
/// summary)는 그대로 유지한다 — 소비자 코드
/// ([JeontongReportBuilder._mapCalculatedResultToReport]의
/// `_overviewFieldOrder`/`_listFieldLabels`, [JeontongResultTextExtractor]의
/// `_titlePriority`/`_bodyPriority`)가 이미 이 키들을 소비하도록 되어
/// 있으므로, 키 이름은 유지한 채 "값의 출처"만 레거시→LifeOverallAnalyzer로
/// 교체한다(§7 "필드 삭제 금지"와 같은 정신).
///
/// [five_elements 예외] 레거시 `five_elements` 키는 `Map<String,int>`
/// 타입 계약(오행별 개수)이라, [LifeOverallAnalysis]의 dominant/deficient
/// (List<String>) 로는 동일 타입을 만들 수 없다. 이 값은 이미 PHASE1~4가
/// 계산해둔 [SajuProfile.fiveElements.totalCount]를 그대로 재사용한다
/// (§0 "PHASE1~4 재계산 금지" — 새 오행 카운트를 계산하지 않고 이미 계산된
/// 값을 조회만 한다).
///
/// 신규 고유 필드(dominantTenGodCategory 등) 원본도 향후 이야기체 고도화를
/// 위해 함께 data에 보존한다(§7 "확장 시 기존 필드 삭제 금지"와 대칭 원칙).
///
/// [방어적 폴백] `ctx.profile`이 null이면 레거시 `getLifeTotal()` 경로로
/// 안전하게 폴백한다(§0과 동일한 안전 원칙).
JeontongCategoryResult _a01(JeontongCalcContext ctx) {
  final profile = ctx.profile;
  if (profile != null) {
    final analysis = const LifeOverallAnalyzer().analyze(
      profile,
      referenceDate: ctx.referenceDate,
    );
    final dayElement = analysis.interpretationContext['dayElement'] ?? '';
    return JeontongCategoryResult(
      category: '평생 총운',
      data: {
        'headline': '$dayElement 기운 · ${analysis.dominantTenGodCategory} 중심 · ${analysis.strengthVerdict}',
        'core_nature': analysis.coreNatureDescription,
        'personality': analysis.strengths.join(', '),
        'strengths': analysis.strengths,
        'weaknesses': analysis.weaknesses,
        'five_elements': profile.fiveElements?.totalCount ?? const <String, int>{},
        'life_theme': analysis.lifeTheme,
        'summary':
            '${analysis.dominantTenGodCategory} 기운이 두드러지는 구조이며, ${analysis.lifeTheme}',
        // 신규 고유 필드 보존(향후 이야기체 고도화용, §7 필드 삭제 금지).
        'dominantTenGodCategory': analysis.dominantTenGodCategory,
        'coreNatureDescription': analysis.coreNatureDescription,
        'notableSinsal': analysis.notableSinsal,
        'strengthVerdict': analysis.strengthVerdict,
        'yongsinElement': analysis.yongsinElement,
        'gisinElement': analysis.gisinElement,
        'favorableConditions': analysis.favorableConditions,
        'cautionConditions': analysis.cautionConditions,
      },
    );
  }
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

/// [j7 · A03 해석 로직 마이그레이션 — A05 wiring과 동일 패턴] 레거시
/// `getLifeWealth()`(재성/관성/인성 개수로 4분류 + verdict 문자열 하나로
/// `_assetStyleByVerdict` 5개짜리 고정 테이블을 룩업하는 방식)를 폐기하고,
/// [WealthAnalyzer](SajuProfile의 재성/비겁/인성 분포·신강신약·용신/기신·
/// 대운을 직접 조회해 매번 새로 판정)의 결과를 사용한다.
///
/// [키 이름 유지 이유] `JeontongCategoryResult.data`의 5개 키(verdict/
/// structure/message/asset_style/peak_period)는 그대로 유지한다 —
/// F01이 `_a03(ctx)`를 그대로 재사용하므로(dispatch map), 이 함수 하나만
/// 고치면 A03/F01 두 카테고리 모두에 자동 반영된다.
///
/// [방어적 폴백] `ctx.profile`이 null이면 레거시 `getLifeWealth()` 경로로
/// 안전하게 폴백한다.
JeontongCategoryResult _a03(JeontongCalcContext ctx) {
  final profile = ctx.profile;
  if (profile != null) {
    final analysis = const WealthAnalyzer().analyze(
      profile,
      referenceDate: ctx.referenceDate,
    );
    return JeontongCategoryResult(
      category: '평생 재물운',
      data: {
        'verdict': analysis.wealthStrength,
        'structure': analysis.wealthPattern,
        'message': '${analysis.incomePattern}. ${analysis.riskPattern}',
        'asset_style': analysis.assetManagementStyle,
        'peak_period': analysis.wealthPeakDaewoonLabel.isNotEmpty
            ? analysis.wealthPeakDaewoonLabel
            : '현재·다음 대운 참조 (재성 대운이 재물 정점)',
        // 신규 고유 필드 보존(향후 이야기체 고도화용, §7 필드 삭제 금지).
        'wealthPattern': analysis.wealthPattern,
        'wealthStrength': analysis.wealthStrength,
        'incomePattern': analysis.incomePattern,
        'riskPattern': analysis.riskPattern,
        'assetManagementStyle': analysis.assetManagementStyle,
        'wealthPeakDaewoonLabel': analysis.wealthPeakDaewoonLabel,
        'favorableConditions': analysis.favorableConditions,
        'cautionConditions': analysis.cautionConditions,
      },
    );
  }
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

/// [j7 · A04 해석 로직 마이그레이션 — A05 wiring과 동일 패턴] 레거시
/// `getLifeCareer()`(`SajuInterpreter.interpretCareer()`의 4분류 고정
/// 문장 + 일간 title 문자열 포함 여부만 보는 `_workStyleByTitle`)를
/// 폐기하고, [CareerAnalyzer](SajuProfile의 관살/인성/식상/비겁 분포·
/// 신강신약·용신/기신·대운·일간을 직접 조회해 매번 새로 판정)의 결과를
/// 사용한다.
///
/// [키 이름 유지 이유] `JeontongCategoryResult.data`의 5개 키(structure/
/// message/recommended_jobs/work_style/growth_path)는 그대로 유지한다 —
/// F02가 `_a04(ctx)`를 그대로 재사용하므로(dispatch map), 이 함수 하나만
/// 고치면 A04/F02 두 카테고리 모두에 자동 반영된다.
///
/// [방어적 폴백] `ctx.profile`이 null이면 레거시 `getLifeCareer()` 경로로
/// 안전하게 폴백한다.
JeontongCategoryResult _a04(JeontongCalcContext ctx) {
  final profile = ctx.profile;
  if (profile != null) {
    final analysis = const CareerAnalyzer().analyze(
      profile,
      referenceDate: ctx.referenceDate,
    );
    return JeontongCategoryResult(
      category: '평생 직업·명예운',
      data: {
        'structure': analysis.careerPattern,
        'message': '${analysis.careerStrength}. ${analysis.careerRiskPattern}',
        'recommended_jobs': analysis.suitableFields,
        'work_style': analysis.workStyle,
        'growth_path': analysis.careerPeakDaewoonLabel.isNotEmpty
            ? '${analysis.careerPeakDaewoonLabel} 시기에 직업·명예 성장 흐름이 강해짐'
            : '정인·정관 대운에서 안정, 식상·재성 대운에서 확장',
        // 신규 고유 필드 보존(향후 이야기체 고도화용, §7 필드 삭제 금지).
        'careerPattern': analysis.careerPattern,
        'careerStrength': analysis.careerStrength,
        'workStyle': analysis.workStyle,
        'suitableFields': analysis.suitableFields,
        'careerRiskPattern': analysis.careerRiskPattern,
        'careerPeakDaewoonLabel': analysis.careerPeakDaewoonLabel,
        'favorableConditions': analysis.favorableConditions,
        'cautionConditions': analysis.cautionConditions,
      },
    );
  }
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

/// [j7 · A05 해석 로직 마이그레이션 — 사용자 지시 §21 13단계 "실제 화면
/// 연결(wiring)"] 레거시 `getLifeHealth()`(오행 개수≥3/=0만 보는 단순
/// 룩업)를 폐기하고, [HealthAnalyzer](SajuProfile의 오행 편중·신강신약·
/// 신살·용신/기신·대운을 직접 조회해 매번 새로 판정)의 결과를 사용한다.
///
/// [키 이름 유지 이유] `JeontongCategoryResult.data`의 4개 키
/// (core_organs/lifetime_warnings/advice_food/lifestyle)는 그대로
/// 유지한다 — [JeontongNarrativeInterpreter._healthNarrativeFromLifeData]
/// (A05/G01/G02 공유)와 [JeontongReportBuilder._mapCalculatedResultToReport]
/// 의 필드명 매핑 체인이 이미 이 4개 키를 소비하도록 되어 있으므로, 키
/// 이름은 유지한 채 "값의 출처"만 레거시→HealthAnalyzer로 교체하면 두
/// 소비자 코드를 건드리지 않고도 개인화된 신규 분석 결과가 그대로
/// 화면에 반영된다(§7 "필드 삭제 금지"와 같은 정신 — 기존 소비자를
/// 깨지 않으면서 내부 산출 로직만 근본적으로 교체).
/// 다만 향후 이야기체를 더 정교하게 다듬을 수 있도록,
/// [HealthAnalysis] 고유 필드(healthConstitutionPattern 등) 원본도
/// 함께 data에 보존해 둔다(§7 "확장 시 기존 필드 삭제 금지"와 대칭되는
/// 원칙 — 새 필드를 추가할 뿐 기존 키를 없애지 않는다).
///
/// [방어적 폴백] `ctx.profile`이 null이면(A05가 `migratedCategoryIds`
/// 밖에서 호출되는 경우는 실제로는 없지만, 테스트 등에서 profile 없이
/// [JeontongCalcContext]를 구성하는 경우를 대비) PHASE1~4 값을 새로
/// 계산하지 않고, 레거시 `getLifeHealth()` 경로로 안전하게 폴백한다
/// (§0 "PHASE1~4 재계산 금지"와 동일한 안전 원칙).
JeontongCategoryResult _a05(JeontongCalcContext ctx) {
  final profile = ctx.profile;
  if (profile != null) {
    final analysis = const HealthAnalyzer().analyze(
      profile,
      referenceDate: ctx.referenceDate,
    );
    return JeontongCategoryResult(
      category: '평생 건강운',
      data: {
        'core_organs': analysis.vulnerableOrgans,
        'lifetime_warnings': analysis.cautionConditions,
        'advice_food': analysis.recommendedCare,
        'lifestyle': '${analysis.healthConstitutionPattern} · ${analysis.healthVitality}',
        // 신규 고유 필드 보존(향후 이야기체 고도화용, §7 필드 삭제 금지).
        'healthConstitutionPattern': analysis.healthConstitutionPattern,
        'healthVitality': analysis.healthVitality,
        'healthRiskPattern': analysis.healthRiskPattern,
        'healthCautionDaewoonLabel': analysis.healthCautionDaewoonLabel,
        'favorableConditions': analysis.favorableConditions,
      },
    );
  }
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

/// [j7 · A06 해석 로직 마이그레이션 — A05 wiring과 동일 패턴] 레거시
/// `getLifeLove()`(배우자성(남=재성/여=관성) 정편 개수만으로 정통형/
/// 다연형/만혼형/혼합형 4분류하는 단순 룩업)를 폐기하고,
/// [LoveAnalyzer](SajuProfile의 십신 분포·신강신약·배우자궁(일지) 관계·
/// 신살(년살/육해살)·용신/기신·대운을 직접 조회해 매번 새로 판정)의
/// 결과를 사용한다.
///
/// [키 이름 유지 이유] `JeontongCategoryResult.data`의 5개 키(spouse_god/
/// style/message/marriage_timing/advice)는 그대로 유지한다 —
/// [JeontongNarrativeInterpreter]의 A06 case와
/// [JeontongReportBuilder]의 필드명 매핑 체인이 이미 이 5개 키를
/// 소비하도록 되어 있으므로, 키 이름은 유지한 채 "값의 출처"만
/// 레거시→LoveAnalyzer로 교체한다(§7과 대칭되는 원칙 — 새 필드를
/// 추가할 뿐 기존 키를 없애지 않는다).
///
/// [방어적 폴백] `ctx.profile`이 null이면 레거시 `getLifeLove()` 경로로
/// 안전하게 폴백한다.
JeontongCategoryResult _a06(JeontongCalcContext ctx) {
  final profile = ctx.profile;
  if (profile != null) {
    final analysis = const LoveAnalyzer().analyze(
      profile,
      referenceDate: ctx.referenceDate,
    );
    final spouseGod = profile.birthInfo.gender == 'male' ? '재성(처성)' : '관성(부성)';
    return JeontongCategoryResult(
      category: '평생 애정운',
      data: {
        'spouse_god': spouseGod,
        'style': analysis.spousePattern,
        'message': '${analysis.spouseBondStrength}. ${analysis.spousePalaceCondition}',
        'marriage_timing': analysis.marriagePeakDaewoonLabel.isNotEmpty
            ? '${analysis.marriagePeakDaewoonLabel} 시기에 혼인·인연운이 가장 활발해질 가능성'
            : '배우자성·용신 대운에서 결혼 인연이 활성화됨',
        'advice': analysis.recommendedApproach,
        // 신규 고유 필드 보존(향후 이야기체 고도화용, §7 필드 삭제 금지).
        'spousePattern': analysis.spousePattern,
        'spouseBondStrength': analysis.spouseBondStrength,
        'spousePalaceCondition': analysis.spousePalaceCondition,
        'romanceRiskPattern': analysis.romanceRiskPattern,
        'marriagePeakDaewoonLabel': analysis.marriagePeakDaewoonLabel,
        'favorableConditions': analysis.favorableConditions,
        'cautionConditions': analysis.cautionConditions,
      },
    );
  }
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

// ============================================================
// G03/G05/G06/G08/G10 — 2026-08-15 실계산 배선(사용자 확정 지시 §3)
// ============================================================

JeontongCategoryResult _g03(JeontongCalcContext ctx) {
  final r = getDaewoonHealthCaution(ctx.saju, ctx.profile);
  return JeontongCategoryResult(
    category: '대운별 건강 주의',
    data: {
      'timeline': r.timeline,
      'caution_periods': r.cautionPeriods,
      'summary': r.summary,
    },
  );
}

JeontongCategoryResult _g05(JeontongCalcContext ctx) {
  final rules = SajuRules.cachedOrNull!;
  final r = getBadFood(ctx.saju, rules);
  return JeontongCategoryResult(
    category: '나에게 나쁜 음식',
    data: {
      'excess_elements': r.excessElements,
      'foods_to_limit': r.foodsToLimit,
      'message': r.message,
    },
  );
}

JeontongCategoryResult _g06(JeontongCalcContext ctx) {
  final rules = SajuRules.cachedOrNull!;
  final r = getConstitution(ctx.saju, rules);
  return JeontongCategoryResult(
    category: '사주 체질',
    data: {
      'element': r.element,
      'season': r.season,
      'personality': r.personality,
      'organs': r.organs,
      'message': r.message,
    },
  );
}

JeontongCategoryResult _g07(JeontongCalcContext ctx) {
  final rules = SajuRules.cachedOrNull!;
  final r = getMentalHealthSensitivity(ctx.saju, ctx.profile, rules);
  return JeontongCategoryResult(
    category: '정신 건강 취약도',
    data: {
      'relation_types': r.relationTypes,
      'excess_elements': r.excessElements,
      'verdict': r.verdict,
      'message': r.message,
    },
  );
}

JeontongCategoryResult _g08(JeontongCalcContext ctx) {
  final r = getInjurySurgeryRisk(ctx.profile);
  return JeontongCategoryResult(
    category: '사고·수술수',
    data: {
      'special_stars': r.specialStars,
      'clash_types': r.clashTypes,
      'verdict': r.verdict,
      'message': r.message,
    },
  );
}

JeontongCategoryResult _g10(JeontongCalcContext ctx) {
  final r = getImmunity(ctx.saju);
  return JeontongCategoryResult(
    category: '회복력·면역',
    data: {
      'strength': r.strength,
      'water_count': r.waterCount,
      'verdict': r.verdict,
      'message': r.message,
    },
  );
}

JeontongCategoryResult _b08(JeontongCalcContext ctx) {
  final r = getBestDaewoonPeriods(ctx.saju, ctx.profile);
  return JeontongCategoryResult(
    category: '인생 최고 대운 시기',
    data: {'periods': r.periods, 'summary': r.summary},
  );
}

JeontongCategoryResult _b09(JeontongCalcContext ctx) {
  final r = getWorstDaewoonPeriods(ctx.saju, ctx.profile);
  return JeontongCategoryResult(
    category: '인생 최악 대운 시기',
    data: {'periods': r.periods, 'summary': r.summary},
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

/// [2026-08-17 C01~C05 소카테고리 차별화] `getYearFortune()`은 총운/재물/
/// 직업/애정/건강 5개 영역을 한 번에 계산해 반환하지만, 각 소카테고리는
/// 자신의 주제에 해당하는 영역만 노출해야 한다("올해 건강운을 보면
/// 건강운만 나와야지, 재물·직업·애정까지 다 섞여 나오면 안 된다" — 사용자
/// 지적 원문). [focusField]가 'overall'이면 C01(총운)처럼 전체 총평만,
/// 그 외(wealth/career/love/health)면 해당 영역 텍스트만 `data`에 담는다.
/// 이렇게 하면 `_mapCalculatedResultToReport`의 `_aspectFieldLabels` 순회가
/// 데이터에 실제로 존재하는 키만 카드로 만들기 때문에, 다른 영역의 문구가
/// 함께 나오는 일이 원천적으로 사라진다.
JeontongCategoryResult _yearFortuneToResult(
  JeontongCalcContext ctx,
  String category, {
  required String focusField,
}) {
  final r = getYearFortune(ctx.saju, ctx.rules, year: ctx.year);
  final byField = <String, String>{
    'overall': r.overall,
    'wealth': r.wealth,
    'career': r.career,
    'love': r.love,
    'health': r.health,
  };
  final focusText = byField[focusField] ?? r.overall;
  return JeontongCategoryResult(
    category: category,
    data: {
      'year_gan_zhi': r.yearGanZhi,
      'year_theme': r.yearTheme,
      'gan_god': r.ganGod,
      'zhi_god': r.zhiGod,
      'title': r.title,
      // focusField 키 하나만 담는다 — 예: C02(재물운)이면 'wealth' 키만
      // 존재하므로 다른 영역(직업/애정/건강) 문구는 이 결과에 아예 없다.
      focusField: focusText,
      'advice': r.advice,
    },
  );
}

JeontongCategoryResult _c06(JeontongCalcContext ctx) {
  final r = getYearlyMovementFortune(ctx.saju, year: ctx.year);
  return JeontongCategoryResult(
    category: '올해 이사·이동수',
    data: {'title': r.title, 'overall': r.overall, 'advice': r.advice},
  );
}

JeontongCategoryResult _c07(JeontongCalcContext ctx) {
  final r = getYearlyExamFortune(ctx.saju, year: ctx.year);
  return JeontongCategoryResult(
    category: '올해 시험·자격운',
    data: {'title': r.title, 'overall': r.overall, 'advice': r.advice},
  );
}

JeontongCategoryResult _c08(JeontongCalcContext ctx) {
  final r = getYearlyLegalRiskFortune(ctx.saju, year: ctx.year);
  return JeontongCategoryResult(
    category: '올해 소송·관재수',
    data: {'title': r.title, 'overall': r.overall, 'advice': r.advice},
  );
}

JeontongCategoryResult _c09(JeontongCalcContext ctx) {
  final r = getYearlyRelationshipFortune(ctx.saju, year: ctx.year);
  return JeontongCategoryResult(
    category: '올해 인간관계',
    data: {'title': r.title, 'overall': r.overall, 'advice': r.advice},
  );
}

JeontongCategoryResult _c10(JeontongCalcContext ctx) {
  final r = getYearlyMonthlyOverview(ctx.saju, ctx.rules, year: ctx.year);
  return JeontongCategoryResult(
    category: '올해 12개월 월별',
    data: {'overall': r.overall, 'monthly_summary': r.monthlySummary},
  );
}

// ============================================================
// D. 이달·오늘 (10)
// ============================================================

JeontongCategoryResult _monthlyFortuneToResult(JeontongCalcContext ctx) {
  final r = getMonthlyFortune(
    ctx.saju,
    ctx.rules,
    year: ctx.year,
    month: ctx.month,
  );
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

/// 공통 부가 정보(간지/십신/시간대 등)만 담는다 — 카테고리별 본문 필드는
/// [_dailyFortuneToResult]가 [focusField]에 맞춰 별도로 추가한다.
Map<String, dynamic> _dailyFortuneCommonMap(DailyFortuneResult r) => {
  'day_gan_zhi': r.dayGanZhi,
  'gan_god': r.ganGod,
  'zhi_god': r.zhiGod,
  'title': r.title,
  'lucky_time': r.luckyTime,
  'avoid_time': r.avoidTime,
  'lucky_color': r.luckyColor,
  'lucky_direction': r.luckyDirection,
  'lucky_number': r.luckyNumber,
};

/// [2026-08-17 D02/D03/D05~D08 소카테고리 차별화] C그룹과 동일한 원칙 —
/// D02(오늘의 운세)는 총운(overall+mood)을, D05(오늘의 재물운)는 wealth만,
/// D06(오늘의 애정운)은 love만, D07(오늘의 건강운)은 health만, D08(오늘의
/// 길흉 시간대)은 시간대 정보 중심으로 노출한다. 과거의 `focusTag`는
/// `data['focus']`에 저장만 되고 리포트 빌더가 전혀 읽지 않아 실질적으로
/// 무의미했다 — [focusField]를 실제 데이터 키 선택에 사용하도록 바꿨다.
JeontongCategoryResult _dailyFortuneToResult(
  JeontongCalcContext ctx, {
  int? year,
  int? month,
  int? day,
  required String focusField,
  String? categoryOverride,
}) {
  final r = getDailyFortune(
    ctx.saju,
    ctx.rules,
    year: year,
    month: month,
    day: day,
  );
  final data = _dailyFortuneCommonMap(r);
  switch (focusField) {
    case 'wealth':
      data['wealth'] = r.wealth;
      break;
    case 'love':
      data['love'] = r.love;
      break;
    case 'health':
      data['health'] = r.health;
      break;
    case 'time':
      // D08(길흉 시간대) — lucky_time/avoid_time은 실계산값이지만 그 자체는
      // 짧은 단어(예: '오전 9~11시')라 리포트 본문(overview/subDescription)
      // 자리를 채우지 못한다. 두 실계산값을 그대로 조합한 문장을
      // 'overall'에 담아, 랜덤 플레이스홀더로 폴백되지 않고 이 카테고리
      // 고유의 실계산 결과가 본문에 노출되게 한다.
      data['overall'] =
          '오늘 움직이기 좋은 시간대는 ${r.luckyTime}. '
          '반대로 ${r.avoidTime}은(는) 피하는 게 좋은 흐름이에요.';
      break;
    case 'overall':
    default:
      data['overall'] = r.overall;
      data['mood'] = r.mood;
      data['work'] = r.work;
      break;
  }
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

/// [2026-08-15 D04 실계산 배선] D02/D03/D05~D09가 이미 사용하는
/// [getDailyFortune]을 오늘부터 7일간 반복 호출한다(C10이 [getMonthlyFortune]
/// 을 12회 반복 호출한 것과 동일 패턴, 사용자 확정 지시 §3 "D04/D10 진행").
JeontongCategoryResult _d04(JeontongCalcContext ctx) {
  final r = getWeeklyFortune(ctx.saju, ctx.rules, startDate: ctx.referenceDate);
  return JeontongCategoryResult(
    category: '이번 주 운세',
    data: {'overall': r.overall, 'daily_summary': r.dailySummary},
  );
}

/// [2026-08-15 D10 실계산 배선 · §5 공통 엔진화] C08(세운 버전)과 동일한
/// [RelationshipsEngine.analyzeExternal]을 오늘 일진 간지로 호출한다.
/// 개별 임시 코드 없이 공통 엔진을 재사용(사용자 확정 지시 §5).
JeontongCategoryResult _d10(JeontongCalcContext ctx) {
  final r = getTodayAvoidFortune(ctx.saju, date: ctx.referenceDate);
  return JeontongCategoryResult(
    category: '오늘 피해야 할 일',
    data: {'title': r.title, 'overall': r.overall, 'advice': r.advice},
  );
}

// ============================================================
// E. 궁합 (10) — E08/E09/E10 실계산 (본인 사주만으로 계산 가능한
// 자기참조형 궁합 3종, 2026-08-15 재검토 후 구현 전환)
// ============================================================

JeontongCategoryResult _e08(JeontongCalcContext ctx) {
  final r = getZodiacAnimalCompatibility(ctx.saju, ctx.rules);
  return JeontongCategoryResult(
    category: '띠 궁합',
    data: {
      'my_animal': r.myAnimal,
      'best_matches': r.bestMatches,
      'worst_matches': r.worstMatches,
      'summary': r.summary,
    },
  );
}

JeontongCategoryResult _e09(JeontongCalcContext ctx) {
  final r = getFiveElementCompatibility(ctx.saju);
  return JeontongCategoryResult(
    category: '오행 궁합',
    data: {
      'my_element': r.myElement,
      'supportive_element': r.supportiveElement,
      'supported_element': r.supportedElement,
      'clashing_element': r.clashingElement,
      'clashed_by_element': r.clashedByElement,
      'summary': r.summary,
    },
  );
}

JeontongCategoryResult _e10(JeontongCalcContext ctx) {
  final r = getOuterInnerCompatibility(ctx.saju);
  return JeontongCategoryResult(
    category: '겉궁합 vs 속궁합',
    data: {
      'outer_element': r.outerElement,
      'inner_element': r.innerElement,
      'relation': r.relation,
      'summary': r.summary,
    },
  );
}

// ============================================================
// F. 특수 주제 (10) — F03~F08/F10 실계산
// ============================================================

JeontongCategoryResult _f03(JeontongCalcContext ctx) {
  final r = getBusinessItemFit(ctx.saju, ctx.interp);
  return JeontongCategoryResult(
    category: '맞는 사업 아이템',
    data: {
      'element': r.element,
      'items': r.items,
      'style': r.style,
      'message': r.message,
    },
  );
}

JeontongCategoryResult _f04(JeontongCalcContext ctx) {
  final r = getCareerVsBusinessFit(ctx.saju, ctx.interp);
  return JeontongCategoryResult(
    category: '창업 vs 직장',
    data: {
      'officer_count': r.officerCount,
      'gongmang_hits_officer': r.gongmangHitsOfficer,
      'verdict': r.verdict,
      'message': r.message,
    },
  );
}

JeontongCategoryResult _f05(JeontongCalcContext ctx) {
  final r = getJobChangeTiming(ctx.saju, year: ctx.year);
  return JeontongCategoryResult(
    category: '이직 타이밍',
    data: {
      'current_daewoon_hit': r.currentDaewoonHit,
      'current_year_hit': r.currentYearHit,
      'upcoming_periods': r.upcomingPeriods,
      'verdict': r.verdict,
      'message': r.message,
    },
  );
}

JeontongCategoryResult _f06(JeontongCalcContext ctx) {
  final r = getRealEstateTiming(ctx.saju);
  return JeontongCategoryResult(
    category: '부동산 매매 타이밍',
    data: {
      'timeline': r.timeline,
      'peak_periods': r.peakPeriods,
      'summary': r.summary,
    },
  );
}

JeontongCategoryResult _f07(JeontongCalcContext ctx) {
  final r = getInvestmentStyle(ctx.interp);
  return JeontongCategoryResult(
    category: '투자 성향 분석',
    data: {
      'aggressive_count': r.aggressiveCount,
      'defensive_count': r.defensiveCount,
      'style': r.style,
      'message': r.message,
    },
  );
}

JeontongCategoryResult _f08(JeontongCalcContext ctx) {
  final r = getMarriageTiming(ctx.saju);
  return JeontongCategoryResult(
    category: '결혼 적령기',
    data: {
      'spouse_god_label': r.spouseGodLabel,
      'active_periods': r.activePeriods,
      'nearest_period': r.nearestPeriod,
      'message': r.message,
    },
  );
}

JeontongCategoryResult _f09(JeontongCalcContext ctx) {
  final r = getGoodChildbirthTiming(ctx.saju);
  return JeontongCategoryResult(
    category: '자녀 출산 좋은 해',
    data: {
      'child_god_label': r.childGodLabel,
      'timeline': r.timeline,
      'active_periods': r.activePeriods,
      'summary': r.summary,
    },
  );
}

JeontongCategoryResult _f10(JeontongCalcContext ctx) {
  final r = getOverseasFortune(ctx.saju, ctx.interp);
  return JeontongCategoryResult(
    category: '유학·해외 진출운',
    data: {
      'has_yeokma': r.hasYeokma,
      'wealth_count': r.wealthCount,
      'water_count': r.waterCount,
      'score': r.score,
      'style': r.style,
      'message': r.message,
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
  // [2026-08-17] 각 소카테고리는 반드시 자신의 주제(focusField)에 해당하는
  // 영역만 결과에 담는다 — C02(재물운)엔 wealth만, C05(건강운)엔 health만.
  'C01': (ctx) =>
      _yearFortuneToResult(ctx, '${ctx.year}년 운세', focusField: 'overall'),
  'C02': (ctx) => _yearFortuneToResult(ctx, '올해 재물운', focusField: 'wealth'),
  'C03': (ctx) => _yearFortuneToResult(ctx, '올해 직업운', focusField: 'career'),
  'C04': (ctx) => _yearFortuneToResult(ctx, '올해 애정운', focusField: 'love'),
  'C05': (ctx) => _yearFortuneToResult(ctx, '올해 건강운', focusField: 'health'),
  'C06': (ctx) => _c06(ctx),
  'C07': (ctx) => _c07(ctx),
  'C08': (ctx) => _c08(ctx),
  'C09': (ctx) => _c09(ctx),
  'C10': (ctx) => _c10(ctx),

  // D. 이달·오늘 (10)
  // [2026-08-17] D02(오늘 총운)/D03(내일 총운)은 focusField: 'overall',
  // D05~D08은 각자의 주제(재물/애정/건강/시간) 필드만 노출한다.
  'D01': (ctx) => _monthlyFortuneToResult(ctx),
  'D02': (ctx) => _dailyFortuneToResult(
    ctx,
    year: ctx.referenceDate.year,
    month: ctx.referenceDate.month,
    day: ctx.referenceDate.day,
    focusField: 'overall',
  ),
  'D03': (ctx) {
    final tomorrow = ctx.referenceDate.add(const Duration(days: 1));
    return _dailyFortuneToResult(
      ctx,
      year: tomorrow.year,
      month: tomorrow.month,
      day: tomorrow.day,
      focusField: 'overall',
    );
  },
  'D04': (ctx) => _d04(ctx),
  'D05': (ctx) => _dailyFortuneToResult(
    ctx,
    year: ctx.referenceDate.year,
    month: ctx.referenceDate.month,
    day: ctx.referenceDate.day,
    focusField: 'wealth',
  ),
  'D06': (ctx) => _dailyFortuneToResult(
    ctx,
    year: ctx.referenceDate.year,
    month: ctx.referenceDate.month,
    day: ctx.referenceDate.day,
    focusField: 'love',
  ),
  'D07': (ctx) => _dailyFortuneToResult(
    ctx,
    year: ctx.referenceDate.year,
    month: ctx.referenceDate.month,
    day: ctx.referenceDate.day,
    focusField: 'health',
  ),
  'D08': (ctx) => _dailyFortuneToResult(
    ctx,
    year: ctx.referenceDate.year,
    month: ctx.referenceDate.month,
    day: ctx.referenceDate.day,
    focusField: 'time',
  ),
  'D09': (ctx) => _luckyItemsToResult(ctx),
  'D10': (ctx) => _d10(ctx),

  // E. 궁합 (3) — E01~E07(상대 사주 필요 궁합)은 2026-08-16 카탈로그에서
  // 완전 삭제됨(구현 불가 확정). E08~E10은 재검토 결과 본인 사주만으로
  // 계산 가능한 자기참조형 카테고리로 판정되어 실계산 전환(2026-08-15).
  'E08': (ctx) => _e08(ctx),
  'E09': (ctx) => _e09(ctx),
  'E10': (ctx) => _e10(ctx),

  // F. 특수 주제 (10)
  'F01': (ctx) => _a03(ctx),
  'F02': (ctx) => _a04(ctx),
  'F03': (ctx) => _f03(ctx),
  'F04': (ctx) => _f04(ctx),
  'F05': (ctx) => _f05(ctx),
  'F06': (ctx) => _f06(ctx),
  'F07': (ctx) => _f07(ctx),
  'F08': (ctx) => _f08(ctx),
  'F09': (ctx) => _f09(ctx),
  'F10': (ctx) => _f10(ctx),

  // G. 건강 (9) — G09(장수)는 2026-08-16 카탈로그에서 완전 삭제됨(계산
  // 불가 확정: sinsal_engine.dart에 관련 신살 계산 근거 없음).
  'G01': (ctx) => _a05(ctx),
  'G02': (ctx) => _a05(ctx),
  'G03': (ctx) => _g03(ctx),
  'G04': (ctx) => _luckyItemsToResult(ctx, category: '나에게 좋은 음식'),
  'G05': (ctx) => _g05(ctx),
  'G06': (ctx) => _g06(ctx),
  'G07': (ctx) => _g07(ctx),
  'G08': (ctx) => _g08(ctx),
  'G10': (ctx) => _g10(ctx),

  // H. 개운·풍수 (7) — H06(작명)/H08(배치)/H09(반려동물)는 2026-08-16
  // 카탈로그에서 완전 삭제됨(H06: 성명학 데이터 부재, H08: H02/H07과 완전
  // 중복, H09: 명리학적 근거 부재).
  'H01': (ctx) => _luckyItemsToResult(ctx, category: '행운의 색'),
  'H02': (ctx) => _luckyItemsToResult(ctx, category: '행운의 방향'),
  'H03': (ctx) => _luckyItemsToResult(ctx, category: '행운의 숫자'),
  'H04': (ctx) => _luckyItemsToResult(ctx, category: '행운의 보석'),
  'H05': (ctx) => _luckyItemsToResult(ctx, category: '부적·개운 아이템'),
  'H07': (ctx) => _luckyItemsToResult(ctx, category: '집·사무실 방향'),
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

/// [미션 3 · 플레이스홀더 UX 안전장치] 위 `_categoryIndex`에서
/// `_placeholder(...)`를 그대로 반환하는(=실제 만세력 계산 없이 안내
/// 메시지만 담는) 카테고리 id의 정적 목록. 원래 35개였으나, 아래 이력을
/// 거쳐 현재는 **빈 Set**이다 — 남은 모든 카테고리가 PHASE1~4 기반
/// 실계산으로 전환되었거나(구현 가능 판정), 계산 불가/완전 중복으로
/// 확정된 항목은 카탈로그([JeontongEightyMatrix])에서 완전히 삭제되었기
/// 때문이다(사용자 확정 지시 §4 "구현 불가능하면 즉시 삭제").
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
/// [2026-08-15 D04/D10 실계산 전환] D그룹(이달·오늘) 나머지 2종(이번 주
/// 운세/오늘 피해야 할 일)도 실계산으로 전환되어 이 목록에서 제외되었다
/// (30 → 28, 사용자 확정 지시 §3 "D04/D10 진행"). D04는 [getDailyFortune]
/// 을 7일 반복 호출하고, D10은 §5 지시에 따라 C08과 동일한
/// `RelationshipsEngine.analyzeExternal()`을 오늘 일진 간지로 호출한다.
///
/// [2026-08-15 F03~F08/F10 실계산 전환] F그룹(특수 주제) 7종(사업
/// 아이템/창업vs직장/이직 타이밍/부동산 매매 타이밍/투자 성향/결혼
/// 적령기/유학·해외 진출운)도 PHASE1~4 기반 실계산으로 전환되어 이
/// 목록에서 제외되었다(28 → 21, 사용자 확정 지시 §3 "F03~F08/F10 진행",
/// 사용자 승인 "응").
///
/// [2026-08-15 F09 실계산 전환] F09(자녀 출산 좋은 해)도 A07
/// ([getLifeChildren])의 자녀성 배정(남=관성/여=식상)과 B05
/// ([getDaewoonLoveFlow])의 대운 타임라인 발동 패턴을 조합해 실계산으로
/// 전환되었다(21 → 20, §4 "구현 불가능하면 즉시 삭제" 원칙에 따라 재검토
/// 후 구현 가능 판정). `saju_f_group_modules.dart`의
/// [getGoodChildbirthTiming] 참고.
///
/// [2026-08-15 E08/E09/E10 실계산 전환] E08(띠 궁합)/E09(오행
/// 궁합)/E10(겉속궁합)은 원래 `_needsPartner`가 아니라 `_placeholder`로
/// 배선되어 있었고, 그 안내 문구 자체가 "연지 기준 12띠 대조"/"오행
/// 상보성 대조"/"연주(겉)·일주(속) 분리 대조"로 바본 사주만으로 계산
/// 가능함을 이미 암시하고 있었다 — F09와 동일한 재검토 패턴으로 실계산
/// 전환(20 → 17). E01~E07은 진짜 상대방 사주가 필요해 구현 불가로
/// 남고(삭제 후보), E08/E09/E10만 자기참조형으로 분리된다.
/// `saju_e_group_modules.dart`의 [getZodiacAnimalCompatibility]/
/// [getFiveElementCompatibility]/[getOuterInnerCompatibility] 참고.
///
/// [2026-08-16 최종 삭제 — E01~E07/G09/H06/H08/H09] 남아있던 마지막
/// 플레이스홀더 11종을 카탈로그에서 완전히 삭제했다(20 → 9 → 0, §3
/// "구현 불가능 카테고리 최종 삭제" 단계).
/// - E01~E07(부부/연인/결혼/사업/상사부하/부모자녀/형제친구 궁합): 상대방의
///   생년월일시가 반드시 필요한 관계형 궁합이나, 본 앱은 사용자 본인
///   사주만 입력받으므로 상대 명식을 계산할 방법이 없어 구현 불가 확정.
/// - G09(장수 가능성): `sinsal_engine.dart`가 실제로 계산하는 신살
///   id(空亡/12신살/羊刃/魁罡/白虎/元辰)에 "장수"를 판정할 근거 데이터가
///   없어(天德貴人은 자산 텍스트에만 있고 계산 엔진에는 없음) 구현 불가
///   확정.
/// - H06(작명): 성명학(획수·자음모음 오행 판정) 데이터가 `assets/jeontong/
///   rules/*.json`에 전혀 존재하지 않아 구현 불가 확정.
/// - H08(침대·책상 배치): `getLuckyItems().directions`가 H02(행운의
///   방향)/H07(집·사무실 방향)과 완전히 동일한 데이터를 반환해, 고유 판정
///   근거가 없는 완전 중복으로 확정.
/// - H09(반려동물 궁합): "사람-반려동물 띠 궁합"이라는 명리학 이론 자체가
///   존재하지 않아, 구현 시 신규 판정 공식을 창조하게 되므로(원칙 §2/§7
///   위배) 삭제 확정.
///
/// 위 11종은 [JeontongEightyMatrix]에서도 함께 제거되었으므로 더 이상
/// `_categoryIndex`나 결과 화면에 등장하지 않는다. 따라서 이 Set은 현재
/// **빈 Set**이다 — 향후 새로운 플레이스홀더가 추가되지 않는 한 계속 비어
/// 있어야 정상이다. 완전히 제거하지 않고 빈 Set으로 남겨두는 이유는, 이
/// 안전장치 메커니즘 자체(및 이를 검증하는
/// `jeontong_placeholder_categories_test.dart`)를 향후 다른 카테고리가
/// 계산 불가로 판정될 경우 재사용할 수 있도록 하기 위함이다.
///
/// [왜 정적 목록인가] `_categoryIndex`는 함수 매핑이라 런타임에 "이 id가
/// placeholder인지"를 알려면 [JeontongCalcContext](실제 사주 계산 결과)를
/// 먼저 만들어야 한다. 하지만 결과 화면은 프로필이 없는 방문자에게도
/// 즉시(계산 없이) 톤다운 배지를 보여줘야 하므로, 위 매핑 정의와 1:1로
/// 대조해 만든 고정 Set을 별도로 둔다(테스트
/// `jeontong_placeholder_categories_test.dart`가 이 목록과 실제
/// `runJeontongCategory()` 실행 결과의 일치를 회귀 검증한다 — 목록이
/// `_categoryIndex`와 어긋나면 테스트가 즉시 실패한다).
const Set<String> kJeontongPlaceholderCategoryIds = {};

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
