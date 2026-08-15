/// [정통사주 80종 · G그룹(건강) 실계산 전환] G03(대운별 건강 주의)/
/// G05(나에게 나쁜 음식)/G06(사주 체질)/G07(정신 건강 취약도)/G08(사고·
/// 수술수)/G10(회복력·면역) 계산 모듈.
///
/// B~F그룹과 마찬가지로 "원본 파이썬 이식"이 아니라 이번 세션에서 신규
/// 설계한 계산이다(사용자 최종 지시 §3 "G03/G05/G06/G08/G10 진행").
/// G01/G02(getLifeHealth 재사용)/G04(getLuckyItems 재사용)는 이미 배선되어
/// 있어 이 파일의 대상이 아니다.
///
/// [2026-08-15 G07 재검토 → 실계산 전환] G07(정신 건강 취약도)은 원래
/// "정신 건강은 명리학적으로 판정 근거가 약하다"는 이유로 placeholder로
/// 남아 있었으나, 재검토 결과 PHASE2([RelationshipsEngine.analyze])가 이미
/// 계산한 원진(怨嗔)·귀문(鬼門關殺) 관계(전통 명리학에서 심리적 예민함·
/// 신경성 증상과 연관 짓는 대표적 신살)와 `five_elements_rules.json`의
/// 화(火)/수(水) 오행 `excess` 필드(화 과다="다혈질·성급함·불면",
/// 수 과다="우울·공포·냉증" — 이미 원문에 명시된 심리적 성향 서술)를
/// 조합하면 새 판정 공식 없이 계산 가능함이 밝혀져 실계산으로 전환했다
/// (E08/E09/E10·F09와 동일한 재검토 패턴). G09(장수 가능성)는 여전히
/// 이번 라운드 구현 대상이 아니다(전통 명리학에 수명 판정 공식 자체가
/// 없어 삭제 대상으로 재검토 중).
///
/// [절대 원칙] 새로운 명리 판정 공식을 만들지 않는다. 여기서 쓰는 모든
/// 판정은 이미 검증된 순수 함수/고정 테이블/PHASE1~4 결과([daewoonsWithTenGod],
/// [SajuProfile.yongsin], [SajuProfile.sinsal], [SajuProfile.relationships],
/// [SajuResult.dayMasterStrength], [SajuResult.fiveElementsCount],
/// `five_elements_rules.json`)를 조회·조합하는 것뿐이다.
///
/// [건강 카테고리 표현 원칙 — 사용자 확정 지시 §6] G03/G05/G06/G07/G08/
/// G10은 의학적 진단처럼 표현하지 않는다. "사주 오행의 균형을 기준으로 한
/// 생활 참고 정보"로만 표현한다(B04에서 이미 확립된 원칙 재사용).
///
/// [profile 의존 카테고리의 안전 처리] G03(용신/기신)·G07(원진/귀문
/// 신살·관계)·G08(신살/관계)은 PHASE1~4가 계산한 [SajuProfile]에만
/// 존재하는 데이터를 조회한다. [profile]이 null이면(레거시
/// `SajuEngine.calculate()` 경로) 새로 계산하지 않고 "판단 불가"로
/// 안전하게 처리한다(B08/B09가 이미 확립한 패턴과 동일).
library;

import 'manseryeok/five_elements_engine.dart' show monthBranchToSeason;
import 'manseryeok/saju_profile.dart' show SajuProfile;
import 'saju_daewoon_modules.dart' show DaewoonWithTenGod, daewoonsWithTenGod;
import 'saju_engine.dart';
import 'saju_interpreter.dart' show SajuRules;

List<String> _asStrList(dynamic v) =>
    v == null ? const [] : (v as List).map((e) => e.toString()).toList();

String _gLabel(DaewoonWithTenGod d) =>
    '${d.luck.startAge}세(${d.luck.startYear}년, ${d.luck.ganZhiKr})';

// ============================================================
// G03 — 대운별 건강 주의 (기신(忌神) 오행 발동 시기 확인)
// ============================================================

class DaewoonHealthCautionResult {
  const DaewoonHealthCautionResult({
    required this.timeline,
    required this.cautionPeriods,
    required this.summary,
  });

  final List<String> timeline;
  final List<String> cautionPeriods;
  final String summary;
}

/// [B04와의 차별점] B04([getDaewoonHealthFlow])는 "원국에 이미 과다한
/// 오행"이 대운에서 더 강화되는 시기를 본다. G03은 다른 관점에서 접근한다
/// — PHASE3([Phase3AnalysisEngine])가 이미 계산한 기신(忌神,
/// [SajuProfile.yongsin]→[YongsinProfile.gisin]) 오행이 대운에서 발동하는
/// 시기를 본다(전통 용신/기신 이론 기준의 건강 주의 시기). 새 판정
/// 공식이 아니라 이미 계산된 기신 값을 대운 목록에서 조회하는 것뿐이다.
///
/// [profile]이 없으면(레거시 경로) 새로 용신/기신을 계산하지 않고 "판단
/// 불가"로 안전하게 처리한다(B08/B09와 동일 패턴).
DaewoonHealthCautionResult getDaewoonHealthCaution(
  SajuResult saju,
  SajuProfile? profile,
) {
  final gisinEl = profile?.yongsin?.gisin;
  if (gisinEl == null || gisinEl.isEmpty) {
    return const DaewoonHealthCautionResult(
      timeline: [],
      cautionPeriods: [],
      summary: '용신·기신 정보를 확인할 수 없어 대운별 건강 주의 시기를 판단하기 어려워요.',
    );
  }

  final list = daewoonsWithTenGod(saju);
  final timeline = <String>[];
  final cautions = <String>[];
  for (final d in list) {
    final label = _gLabel(d);
    final hit = d.stemElement == gisinEl || d.branchElement == gisinEl;
    if (hit) {
      timeline.add('$label — 기신($gisinEl) 기운이 들어와 컨디션 관리에 조금 더 신경 쓰면 좋은 시기');
      cautions.add(label);
    } else {
      timeline.add('$label — 기신 기운이 뚜렷하지 않아 비교적 무난한 시기');
    }
  }

  final summary = cautions.isEmpty
      ? '계산된 대운 범위 안에서는 기신($gisinEl) 기운이 뚜렷하게 들어오는 시기가 보이지 않아요. '
          '전반적으로 무난한 생활 관리가 가능한 흐름이에요.'
      : '${cautions.join(', ')} 시기에는 기신($gisinEl) 기운이 들어와요. 이 시기에는 평소보다 '
          '휴식·규칙적인 생활에 조금 더 신경 쓰면 좋아요. (※ 사주 오행의 균형을 기준으로 한 '
          '생활 참고 정보이며, 의학적 진단이 아니에요.)';

  return DaewoonHealthCautionResult(
    timeline: timeline,
    cautionPeriods: cautions,
    summary: summary,
  );
}

// ============================================================
// G05 — 나에게 나쁜 음식 (과다 오행의 food_good 역이용)
// ============================================================

class BadFoodResult {
  const BadFoodResult({
    required this.excessElements,
    required this.foodsToLimit,
    required this.message,
  });

  final List<String> excessElements;
  final List<String> foodsToLimit;
  final String message;
}

/// [food_bad 데이터 부재에 대한 대안 설계] `five_elements_rules.json`에는
/// 각 오행의 "좋은 음식"(food_good)만 있고 "나쁜 음식" 필드는 없다. 새로운
/// 판정 공식을 만드는 대신, A05([getLifeHealth])/[interpretHealth]가 이미
/// 채택한 "과다(≥3개) 오행" 판정 임계값을 그대로 재사용해, 원국에 이미
/// 넘치는 오행의 food_good 음식을 "과유불급이니 줄이면 좋은 음식"으로
/// 안내한다(기존 임계값 + 기존 매핑표의 조회 방향만 바꾼 것으로, 새
/// 명리 판정 공식이 아니다).
BadFoodResult getBadFood(SajuResult saju, SajuRules rules) {
  final counts = saju.fiveElementsCount;
  final excess = counts.entries.where((e) => e.value >= 3).map((e) => e.key).toList();

  if (excess.isEmpty) {
    return const BadFoodResult(
      excessElements: [],
      foodsToLimit: [],
      message: '오행이 비교적 고르게 분포되어 있어, 특별히 줄여야 할 음식은 뚜렷하지 않아요. '
          '평소처럼 균형 잡힌 식사를 유지하면 충분해요.',
    );
  }

  final foods = <String>{};
  for (final el in excess) {
    final rule = rules.fiveElements[el] as Map<String, dynamic>;
    foods.addAll(_asStrList(rule['food_good']));
  }
  final foodsList = foods.toList();

  return BadFoodResult(
    excessElements: excess,
    foodsToLimit: foodsList,
    message: '${excess.join(', ')} 기운이 원국에 이미 넘치는 편이에요(3개 이상). '
        '${foodsList.join(', ')}처럼 그 기운을 더 강하게 하는 음식은 과하게 섭취하지 않는 것이 '
        '좋아요. (※ 사주 오행의 균형을 기준으로 한 생활 참고 정보이며, 의학적 진단이 아니에요.)',
  );
}

// ============================================================
// G06 — 사주 체질 (일간 오행 + 월지 계절 조합)
// ============================================================

class ConstitutionResult {
  const ConstitutionResult({
    required this.element,
    required this.season,
    required this.personality,
    required this.organs,
    required this.message,
  });

  final String element;
  final String season;
  final String personality;
  final List<String> organs;
  final String message;
}

/// 일간 오행([SajuDayMaster.element])을 `five_elements_rules.json`에서
/// 조회하고, 월지([monthBranchToSeason] 고정 매핑)로 태어난 계절을 함께
/// 조합해 "체질 유형"을 안내한다. 새 판정 공식이 아니라 이미 존재하는
/// 두 고정 매핑표(오행별 특성표 + 월지-계절표)를 조합 조회하는 것뿐이다.
ConstitutionResult getConstitution(SajuResult saju, SajuRules rules) {
  final element = saju.dayMaster.element;
  final monthZhi = saju.pillars['month']!.zhi;
  final season = monthBranchToSeason[monthZhi] ?? '';
  final rule = rules.fiveElements[element] as Map<String, dynamic>;
  final personality = (rule['personality'] as String?) ?? '';
  final organs = _asStrList(rule['organ']);

  return ConstitutionResult(
    element: element,
    season: season,
    personality: personality,
    organs: organs,
    message: '일간 오행이 $element(이)라 "$element 체질"에 가까워요. $season철에 태어나 그 계절 '
        '기운의 영향도 함께 받아요. 평소 성향은 $personality 쪽에 가깝고, 몸에서는 '
        '${organs.join(', ')} 계통을 챙기면 좋은 편이에요. (※ 사주 오행의 균형을 기준으로 한 '
        '생활 참고 정보이며, 의학적 체질 진단이 아니에요.)',
  );
}

// ============================================================
// G07 — 정신 건강 취약도 (원진·귀문 관계 + 화·수 과다 오행 심리 성향)
// ============================================================

class MentalHealthSensitivityResult {
  const MentalHealthSensitivityResult({
    required this.relationTypes,
    required this.excessElements,
    required this.verdict,
    required this.message,
  });

  final List<String> relationTypes;
  final List<String> excessElements;
  final String verdict;
  final String message;
}

/// 원진(怨嗔)/귀문(鬼門關殺) 관계 종류(전통 명리학에서 심리적 예민함·
/// 신경성 증상과 연관 짓는 대표적 신살).
const Set<String> _mentalRelationTypes = {'원진', '귀문'};

/// 화(火, 다혈질·성급함·불면)/수(水, 우울·공포·냉증) 과다(≥3개) 여부 —
/// `five_elements_rules.json`의 `excess` 필드에 이미 명시된 심리적 성향을
/// 그대로 조회한다(A05/G05와 동일한 "과다(≥3개)" 임계값 재사용).
const Set<String> _mentalElements = {'화', '수'};

/// [SajuProfile.relationships](원진/귀문, PHASE2·[RelationshipsEngine]이
/// 이미 계산)와 [SajuResult.fiveElementsCount](화·수 과다)를 조회해
/// 조합한다. 새로 신살·관계를 계산하지 않는다 — [profile]이 없으면(레거시
/// 경로, 레거시 `SajuResult.relationships`에는 원진/귀문이 없음) "판단
/// 불가"로 안전하게 처리한다(G08과 동일 패턴).
MentalHealthSensitivityResult getMentalHealthSensitivity(
  SajuResult saju,
  SajuProfile? profile,
  SajuRules rules,
) {
  final relations = profile?.relationships;
  if (relations == null) {
    return const MentalHealthSensitivityResult(
      relationTypes: [],
      excessElements: [],
      verdict: '판단 불가',
      message: '원국의 원진·귀문 관계 정보를 확인할 수 없어 정신 건강 취약도를 판단하기 어려워요.',
    );
  }

  final relTypes = relations
      .where((r) => _mentalRelationTypes.contains(r.type))
      .map((r) => r.type)
      .toSet()
      .toList();

  final counts = saju.fiveElementsCount;
  final excess = _mentalElements.where((el) => (counts[el] ?? 0) >= 3).toList();

  final String verdict;
  final String message;
  if (relTypes.isNotEmpty && excess.isNotEmpty) {
    verdict = '예민한 편 — 마음 관리 신경 쓰면 좋음';
    final elDesc = excess
        .map((el) => '$el(${(rules.fiveElements[el] as Map<String, dynamic>)['excess']})')
        .join(', ');
    message = '원국에 ${relTypes.join('·')} 관계가 있고 $elDesc 성향도 함께 있어, 스트레스에 '
        '평소보다 예민하게 반응할 수 있어요. 규칙적인 휴식과 감정 표현 습관이 도움이 돼요. '
        '(※ 사주 오행의 균형을 기준으로 한 생활 참고 정보이며, 의학적 진단이 아니에요.)';
  } else if (relTypes.isNotEmpty) {
    verdict = '가벼운 예민형';
    message = '원국에 ${relTypes.join('·')} 관계가 있어, 신경 쓰이는 일에 예민하게 반응할 수 '
        '있어요. 스트레스 해소 루틴을 만들어두면 좋아요. (※ 사주 오행의 균형을 기준으로 한 '
        '생활 참고 정보이며, 의학적 진단이 아니에요.)';
  } else if (excess.isNotEmpty) {
    final elDesc = excess
        .map((el) => '$el(${(rules.fiveElements[el] as Map<String, dynamic>)['excess']})')
        .join(', ');
    verdict = '가벼운 예민형';
    message = '$elDesc 성향이 있어, 감정 기복에 조금 더 신경 쓰면 좋아요. (※ 사주 오행의 '
        '균형을 기준으로 한 생활 참고 정보이며, 의학적 진단이 아니에요.)';
  } else {
    verdict = '비교적 안정적';
    message = '원국에 정신적 예민함과 관련된 원진·귀문 관계나 화·수 과다 성향이 뚜렷하지 '
        '않아, 비교적 안정적인 편이에요. (※ 사주 오행의 균형을 기준으로 한 생활 참고 '
        '정보이며, 의학적 진단이 아니에요.)';
  }

  return MentalHealthSensitivityResult(
    relationTypes: relTypes,
    excessElements: excess,
    verdict: verdict,
    message: message,
  );
}

// ============================================================
// G08 — 사고·수술수 (양인·백호·괴강 신살 + 원국 자체 형충 확인)
// ============================================================

class InjurySurgeryRiskResult {
  const InjurySurgeryRiskResult({
    required this.specialStars,
    required this.clashTypes,
    required this.verdict,
    required this.message,
  });

  final List<String> specialStars;
  final List<String> clashTypes;
  final String verdict;
  final String message;
}

/// 양인(id '羊刃')/백호(id '白虎')/괴강(id '魁罡') 신살 여부.
const Set<String> _riskSinsalIds = {'羊刃', '白虎', '魁罡'};

/// 원국 자체(외부주 없음)의 형충 관계 종류.
const Set<String> _riskRelationTypes = {'지지충', '형', '자형', '삼형'};

/// [SajuProfile.sinsal](양인·백호·괴강 포함 20+종, PHASE2·[SinsalEngine]이
/// 이미 계산)과 [SajuProfile.relationships](원국 자체 형충, PHASE2·
/// [RelationshipsEngine.analyze]가 이미 계산)를 조회해 조합한다. 새로 신살·
/// 형충을 계산하지 않는다 — [profile]이 없으면(레거시 경로, 레거시
/// `SajuResult.sinsal`은 천을귀인/문창귀인/역마 3종뿐이라 양인/백호/괴강을
/// 판정할 수 없음) "판단 불가"로 안전하게 처리한다(B08/B09와 동일 패턴).
InjurySurgeryRiskResult getInjurySurgeryRisk(SajuProfile? profile) {
  final sinsal = profile?.sinsal;
  final relations = profile?.relationships;
  if (sinsal == null || relations == null) {
    return const InjurySurgeryRiskResult(
      specialStars: [],
      clashTypes: [],
      verdict: '판단 불가',
      message: '원국의 신살·형충 정보를 확인할 수 없어 사고·수술수를 판단하기 어려워요.',
    );
  }

  final stars = sinsal.where((s) => _riskSinsalIds.contains(s.id)).map((s) => s.nameKr).toList();
  final clashes = relations
      .where((r) => _riskRelationTypes.contains(r.type))
      .map((r) => r.type)
      .toSet()
      .toList();

  final String verdict;
  final String message;
  if (stars.isNotEmpty && clashes.isNotEmpty) {
    verdict = '주의가 필요한 편';
    message = '${stars.join('·')}과 원국 내 ${clashes.join('·')} 관계가 함께 있어, 평소보다 '
        '안전·건강 관리에 조금 더 신경 쓰면 좋아요. (※ 사주 명리학적 참고 정보이며, 의학적 '
        '진단이 아니에요.)';
  } else if (stars.isNotEmpty) {
    verdict = '가벼운 주의형';
    message = '${stars.join('·')}이 있어, 급하게 움직이는 상황(운동·운전 등)에서 조금 더 '
        '조심하면 좋아요. (※ 사주 명리학적 참고 정보이며, 의학적 진단이 아니에요.)';
  } else if (clashes.isNotEmpty) {
    verdict = '가벼운 주의형';
    message = '원국 내 ${clashes.join('·')} 관계가 있어, 사고·부상 등에 평소보다 유의하면 '
        '좋아요. (※ 사주 명리학적 참고 정보이며, 의학적 진단이 아니에요.)';
  } else {
    verdict = '비교적 안정적';
    message = '원국에 사고·수술과 관련된 신살(양인·백호·괴강)이나 형충 관계가 뚜렷하지 않아, '
        '비교적 평온한 흐름이에요. (※ 사주 명리학적 참고 정보이며, 의학적 진단이 아니에요.)';
  }

  return InjurySurgeryRiskResult(
    specialStars: stars,
    clashTypes: clashes,
    verdict: verdict,
    message: message,
  );
}

// ============================================================
// G10 — 회복력·면역 (일간 강도 + 수(水) 오행 개수)
// ============================================================

class ImmunityResult {
  const ImmunityResult({
    required this.strength,
    required this.waterCount,
    required this.verdict,
    required this.message,
  });

  final String strength;
  final int waterCount;
  final String verdict;
  final String message;
}

/// 이미 계산된 [SajuResult.dayMasterStrength]('身强(신강)'|'中和(중화)'|
/// '身弱(신약)')와 [SajuResult.fiveElementsCount]의 수(水) 오행 개수를
/// 조회해 조합한다. 새 판정 공식이 아니라 두 값을 조합 조회하는 것뿐이다.
/// [saju.dayMasterStrength]는 레거시/신규 경로 모두 항상 채워지므로
/// (레거시: [judgeStrength], 신규: [StrengthEngine]→어댑터) [SajuProfile]
/// 없이도 동작한다.
ImmunityResult getImmunity(SajuResult saju) {
  final strength = saju.dayMasterStrength;
  final waterCount = saju.fiveElementsCount['수'] ?? 0;
  final isStrong = strength.contains('强');
  final isWeak = strength.contains('弱');

  final String verdict;
  final String message;
  if (isStrong && waterCount >= 2) {
    verdict = '회복력 우수형';
    message = '일간이 신강하고 수(水, $waterCount) 기운도 충분해, 몸의 회복력과 기초 체력이 좋은 '
        '편이에요. (※ 사주 오행의 균형을 기준으로 한 생활 참고 정보이며, 의학적 진단이 아니에요.)';
  } else if (isStrong) {
    verdict = '기본 체력 양호형';
    message = '일간이 신강해 기본 체력은 좋은 편이지만, 수(水, $waterCount) 기운이 부족한 편이라 '
        '평소 수분 섭취와 휴식을 챙기면 회복력을 더 높일 수 있어요. (※ 사주 오행의 균형을 '
        '기준으로 한 생활 참고 정보이며, 의학적 진단이 아니에요.)';
  } else if (waterCount >= 2) {
    verdict = '꾸준한 관리 필요형';
    message = '수(水, $waterCount) 기운은 있지만 일간이 ${isWeak ? '신약한' : '중화에 가까운'} 편이라, '
        '무리하지 않는 선에서 꾸준히 체력을 관리하면 좋아요. (※ 사주 오행의 균형을 기준으로 한 '
        '생활 참고 정보이며, 의학적 진단이 아니에요.)';
  } else {
    verdict = '컨디션 관리 신경 써야 하는 편';
    message = '일간이 ${isWeak ? '신약하고' : '중화에 가깝고'} 수(水, $waterCount) 기운도 부족한 '
        '편이라, 평소보다 휴식·수면·규칙적인 생활에 신경 쓰면 좋아요. (※ 사주 오행의 균형을 '
        '기준으로 한 생활 참고 정보이며, 의학적 진단이 아니에요.)';
  }

  return ImmunityResult(
    strength: strength,
    waterCount: waterCount,
    verdict: verdict,
    message: message,
  );
}
