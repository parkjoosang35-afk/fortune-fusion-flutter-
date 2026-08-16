/// [정통사주 80종 · 로컬 만세력 엔진] saju_engine_v4_final.zip 의
/// `modules/life_total.py`, `life_wealth.py`, `life_career.py`,
/// `life_love.py`, `life_health.py` 5개 평생운 모듈을 Dart로 완전 이식.
///
/// 모두 [SajuInterpreter.fullInterpretation]의 결과([SajuFullInterpretation])를
/// 입력으로 받아 파생 지표를 계산한다 — LLM/외부 서버 호출 없음.
library;

import 'saju_engine.dart';
import 'saju_interpreter.dart';

// ============================================================
// A01/A02 — 평생 총운 / 타고난 성격·기질 — get_life_total() 이식
// ============================================================

class LifeTotalResult {
  const LifeTotalResult({
    required this.headline,
    required this.coreNature,
    required this.personality,
    required this.strengths,
    required this.weaknesses,
    required this.fiveElements,
    required this.lifeTheme,
    required this.summary,
  });

  final String headline;
  final String coreNature;
  final String personality;
  final List<String> strengths;
  final List<String> weaknesses;
  final Map<String, int> fiveElements;
  final String lifeTheme;
  final String summary;
}

const Map<String, String> _lifeThemeByDominant = {
  '비견(比肩)': '동료·형제와 함께 성장하는 삶',
  '겁재(劫財)': '경쟁 속에서 단련되는 삶',
  '식신(食神)': '재능과 표현으로 풍요를 이루는 삶',
  '상관(傷官)': '창의력으로 세상을 흔드는 삶',
  '편재(偏財)': '큰돈과 활동의 사업가형 삶',
  '정재(正財)': '성실한 축적으로 안정을 이루는 삶',
  '편관(偏官/七殺)': '시련을 이겨내며 카리스마를 얻는 삶',
  '정관(正官)': '명예와 질서 속에서 성장하는 삶',
  '편인(偏印)': '학문·예술·직관의 심오한 삶',
  '정인(正印)': '배움과 인복이 넘치는 삶',
};

/// get_life_total() 이식.
LifeTotalResult getLifeTotal(SajuFullInterpretation interp) {
  final dm = interp.dayMasterAnalysis;
  final fe = interp.fiveElementsAnalysis;
  final tg = interp.tenGodsAnalysis;

  final theme = _lifeThemeByDominant[tg.dominantName] ?? '다채로운 흐름의 삶';

  return LifeTotalResult(
    headline: '${dm.title} — ${tg.dominantName} 중심 인생',
    coreNature: dm.nature,
    personality: dm.personality,
    strengths: dm.strengths,
    weaknesses: dm.weaknesses,
    fiveElements: fe.counts,
    lifeTheme: theme,
    summary:
        '${dm.title}. 지배 십신은 ${tg.dominantName}(${tg.dominantEasy}) '
        '${tg.dominantCount}개. $theme',
  );
}

// ============================================================
// A03/F01 — 평생 재물운 — get_life_wealth() 이식
// ============================================================

class LifeWealthResult {
  const LifeWealthResult({
    required this.verdict,
    required this.structure,
    required this.message,
    required this.assetStyle,
    required this.peakPeriod,
  });

  final String verdict;
  final String structure;
  final String message;
  final String assetStyle;
  final String peakPeriod;
}

const Map<String, String> _assetStyleByVerdict = {
  '재다신약': '부동산·현금 등 안정형 위주. 주식·코인 등 변동성 금물.',
  '재왕신강': '사업·투자 확대 가능. 리스크 감수형 유리.',
  '무재격': '지식재산·자격증·저작권 형태 재물.',
  '신강용재': '정재+편재 균형 운용. 월급+투자 조합.',
  '재약신약': '저축·현금성 자산 중심, 소액 분산투자.',
};

/// get_life_wealth() 이식.
LifeWealthResult getLifeWealth(SajuFullInterpretation interp) {
  final w = interp.wealthFortune;
  final dist = interp.tenGodsAnalysis.distribution;

  final wealthCount = (dist['정재'] ?? 0) + (dist['편재'] ?? 0);
  final officerCount = (dist['정관'] ?? 0) + (dist['편관'] ?? 0);
  final printerCount = (dist['정인'] ?? 0) + (dist['편인'] ?? 0);

  final String style;
  if (wealthCount >= 2 && officerCount >= 1) {
    style = '재관쌍미(財官雙美) — 재물과 명예를 동시에';
  } else if (wealthCount >= 2 && printerCount == 0) {
    style = '재성 편중 — 활동적 재물, 관리 부족';
  } else if (wealthCount == 0 && printerCount >= 2) {
    style = '인다무재(印多無財) — 명예형, 재물엔 담백';
  } else {
    style = '균형형';
  }

  return LifeWealthResult(
    verdict: w.verdict,
    structure: style,
    message: w.message,
    assetStyle: _assetStyleByVerdict[w.verdict] ?? '균형 잡힌 자산 배분',
    peakPeriod: '현재·다음 대운 참조 (재성 대운이 재물 정점)',
  );
}

// ============================================================
// A04/F02 — 평생 직업·명예운 — get_life_career() 이식
// ============================================================

class LifeCareerResult {
  const LifeCareerResult({
    required this.structure,
    required this.message,
    required this.recommendedJobs,
    required this.workStyle,
    required this.growthPath,
  });

  final String structure;
  final String message;
  final List<String> recommendedJobs;
  final String workStyle;
  final String growthPath;
}

String _workStyleByTitle(String title) {
  if (title.contains('신강')) return '리더·독립·창업형. 조직 내에서도 주도적 역할 유리.';
  if (title.contains('신약')) return '전문가·조력자·기획형. 안정된 조직에서 능력 발휘.';
  return '균형형. 조직·독립 모두 가능.';
}

/// get_life_career() 이식.
LifeCareerResult getLifeCareer(SajuFullInterpretation interp) {
  final c = interp.careerFortune;
  final dm = interp.dayMasterAnalysis;
  return LifeCareerResult(
    structure: c.structure,
    message: c.message,
    recommendedJobs: c.recommended,
    workStyle: _workStyleByTitle(dm.title),
    growthPath: '정인·정관 대운에서 안정, 식상·재성 대운에서 확장',
  );
}

// ============================================================
// A06 — 평생 배우자·결혼운 — get_life_love() 이식
// ============================================================

class LifeLoveResult {
  const LifeLoveResult({
    required this.spouseGod,
    required this.style,
    required this.message,
    required this.marriageTiming,
    required this.advice,
  });

  final String spouseGod;
  final String style;
  final String message;
  final String marriageTiming;
  final String advice;
}

/// get_life_love() 이식.
LifeLoveResult getLifeLove(SajuResult saju, SajuFullInterpretation interp) {
  final lv = interp.loveFortune;
  final dist = interp.tenGodsAnalysis.distribution;

  final int primary;
  final int secondary;
  final String spouseGod;
  if (saju.gender == 'male') {
    primary = dist['정재'] ?? 0;
    secondary = dist['편재'] ?? 0;
    spouseGod = '재성(처성)';
  } else {
    primary = dist['정관'] ?? 0;
    secondary = dist['편관'] ?? 0;
    spouseGod = '관성(부성)';
  }

  final String style;
  if (primary >= 1 && secondary == 0) {
    style = '정통형 — 정식·안정된 배우자, 오래가는 관계';
  } else if (secondary >= 2) {
    style = '다연형 — 이성 인연 활발, 신중한 선택 필요';
  } else if (primary == 0 && secondary == 0) {
    style = '만혼형 — 늦은 결혼 또는 특별한 인연';
  } else {
    style = '혼합형 — 정식 관계와 활발한 인연 병존';
  }

  return LifeLoveResult(
    spouseGod: spouseGod,
    style: style,
    message: lv.message,
    marriageTiming: '재성(남)·관성(여) 대운·세운에서 결혼 인연 활성',
    advice: '궁합·개운으로 보완 가능. 상대 일간과의 조화 중요.',
  );
}

// ============================================================
// A05 — 평생 건강운 — get_life_health() 이식
// ============================================================

class LifeHealthResult {
  const LifeHealthResult({
    required this.coreOrgans,
    required this.lifetimeWarnings,
    required this.adviceFood,
    required this.lifestyle,
  });

  final List<String> coreOrgans;
  final List<String> lifetimeWarnings;
  final List<String> adviceFood;
  final String lifestyle;
}

/// get_life_health() 이식.
LifeHealthResult getLifeHealth(SajuResult saju, SajuFullInterpretation interp) {
  final h = interp.healthFortune;
  final counts = saju.fiveElementsCount;

  final warnings = <String>[];
  void check(String el, String organs) {
    final c = counts[el] ?? 0;
    if (c == 0 || c >= 3) warnings.add(organs);
  }

  check('목', '간·담·눈');
  check('화', '심장·혈액');
  check('토', '위·비장·소화');
  check('금', '폐·대장·피부');
  check('수', '신장·방광·뼈');

  return LifeHealthResult(
    coreOrgans: h.coreOrgans,
    lifetimeWarnings: warnings,
    adviceFood: h.recommendedFood,
    lifestyle: '규칙적 수면·유산소 운동·수분 섭취가 최고의 보약',
  );
}

// ============================================================
// A07 — 평생 자녀운 — 신규(사용자 확정 지시 §7 A그룹) 구현.
//
// [십신 배정 근거] 자평명리(子平命理) 표준 관행 — 여명(女命)의 자녀성은
// 식상(食傷, 내가 생하는 오행), 남명(男命)의 자녀성은 관성(官星, 나를
// 극하는 오행 — 처(재성)가 관성을 낳는다는 재생관(財生官) 논리로 남편
// 입장에서 자식을 관성으로 봄)이다. [getLifeLove]가 이미 채택한
// "남=재성(처)/여=관성(부)" 배우자성 배정과 짝을 이루는 표준 조합.
// ============================================================

class LifeChildrenResult {
  const LifeChildrenResult({
    required this.childGod,
    required this.count,
    required this.style,
    required this.message,
    required this.timingHint,
  });

  final String childGod;
  final int count;
  final String style;
  final String message;
  final String timingHint;
}

LifeChildrenResult getLifeChildren(
  SajuResult saju,
  SajuFullInterpretation interp,
) {
  final dist = interp.tenGodsAnalysis.distribution;
  final String childGod;
  final int count;
  if (saju.gender == 'male') {
    childGod = '관성(자녀성)';
    count = (dist['정관'] ?? 0) + (dist['편관'] ?? 0);
  } else {
    childGod = '식상(자녀성)';
    count = (dist['식신'] ?? 0) + (dist['상관'] ?? 0);
  }

  final String style;
  final String message;
  if (count == 0) {
    style = '만연형 — 자녀 인연이 늦거나 특별한 노력이 필요한 흐름';
    message =
        '$childGod 부재. 자녀 인연이 다소 늦게 찾아오거나, $childGod이 들어오는 '
        '대운·세운에서 인연이 뚜렷해질 수 있어요.';
  } else if (count == 1) {
    style = '안정형 — 자녀와의 관계가 정착되는 흐름';
    message = '$childGod 1개. 자녀와 깊고 안정적인 인연을 맺는 흐름이에요.';
  } else if (count == 2) {
    style = '풍요형 — 자녀복이 두터운 흐름';
    message = '$childGod 2개. 자녀 인연이 풍부하고 다복한 흐름이에요.';
  } else {
    style = '다자녀형 — 자녀 관련 에너지가 강한 흐름';
    message =
        '$childGod 3개 이상. 자녀와 관련된 에너지가 강하게 흐르는 사주예요. '
        '자녀 각자의 개성을 존중하는 육아 방식이 잘 맞아요.';
  }

  return LifeChildrenResult(
    childGod: childGod,
    count: count,
    style: style,
    message: message,
    timingHint: '$childGod 대운·세운에서 자녀 관련 인연·경사가 두드러질 수 있어요.',
  );
}

// ============================================================
// A08 — 평생 부모·형제운 — 신규(§7 A그룹) 구현.
//
// [십신 배정 근거] 인성(정인·편인, 生我者)=부모(특히 모친), 비겁(비견·
// 겁재, 同五行者)=형제자매·동료. 성별 구분 없이 공통 적용되는 표준
// 배정(재성=부친으로 보는 학파도 있으나, 모친 중심의 인성 배정이 가장
// 보편적이라 이 원칙을 채택).
// ============================================================

class LifeParentsSiblingsResult {
  const LifeParentsSiblingsResult({
    required this.parentGod,
    required this.parentCount,
    required this.parentMessage,
    required this.siblingGod,
    required this.siblingCount,
    required this.siblingMessage,
  });

  final String parentGod;
  final int parentCount;
  final String parentMessage;
  final String siblingGod;
  final int siblingCount;
  final String siblingMessage;
}

LifeParentsSiblingsResult getLifeParentsSiblings(
  SajuFullInterpretation interp,
) {
  final dist = interp.tenGodsAnalysis.distribution;
  final parentCount = (dist['정인'] ?? 0) + (dist['편인'] ?? 0);
  final siblingCount = (dist['비견'] ?? 0) + (dist['겁재'] ?? 0);

  final String parentMessage;
  if (parentCount == 0) {
    parentMessage = '인성(부모성) 부재. 부모의 도움보다 스스로 개척하는 힘이 강한 사주예요.';
  } else if (parentCount <= 2) {
    parentMessage = '인성(부모성) $parentCount개. 부모·윗사람의 도움과 인복이 안정적으로 따르는 흐름이에요.';
  } else {
    parentMessage = '인성(부모성) $parentCount개. 인복은 넘치지만 의존적인 성향은 주의하면 좋아요.';
  }

  final String siblingMessage;
  if (siblingCount == 0) {
    siblingMessage = '비겁(형제성) 부재. 형제·동료보다 혼자 힘으로 해내는 성향이 강해요.';
  } else if (siblingCount <= 2) {
    siblingMessage = '비겁(형제성) $siblingCount개. 형제·동료와 협력하며 함께 성장하는 흐름이에요.';
  } else {
    siblingMessage = '비겁(형제성) $siblingCount개. 경쟁·독립심이 강하니 동업·금전 거래는 신중해야 해요.';
  }

  return LifeParentsSiblingsResult(
    parentGod: '인성(정인·편인)',
    parentCount: parentCount,
    parentMessage: parentMessage,
    siblingGod: '비겁(비견·겁재)',
    siblingCount: siblingCount,
    siblingMessage: siblingMessage,
  );
}

// ============================================================
// A09 — 평생 학업·시험운 — 신규(§7 A그룹) 구현.
//
// [근거] 인성(정인·편인)=학문·문서·수용력, 문창귀인(文昌貴人)=전통
// 명리학의 대표적 시험·학문 신살(SinsalEngine이 이미 계산해 레거시
// [SajuResult.sinsal]에 '文昌貴人(문창귀인)' 형태로 포함). 새 판정
// 로직을 만들지 않고 이미 계산된 두 값을 조합만 한다.
// ============================================================

class LifeStudyResult {
  const LifeStudyResult({
    required this.studyGodCount,
    required this.hasMunchang,
    required this.style,
    required this.message,
  });

  final int studyGodCount;
  final bool hasMunchang;
  final String style;
  final String message;
}

LifeStudyResult getLifeStudy(SajuResult saju, SajuFullInterpretation interp) {
  final dist = interp.tenGodsAnalysis.distribution;
  final studyGodCount = (dist['정인'] ?? 0) + (dist['편인'] ?? 0);
  final hasMunchang = saju.sinsal.any((s) => s.startsWith('文昌貴人'));

  final String style;
  final String message;
  if (studyGodCount >= 2 && hasMunchang) {
    style = '학업 최상형 — 인성과 문창귀인이 함께 발동';
    message =
        '인성(학업성) $studyGodCount개 + 문창귀인 보유. 집중력과 학습 이해력이 뛰어나고, '
        '시험·자격증운이 특히 강한 사주예요.';
  } else if (hasMunchang) {
    style = '시험운 발동형 — 문창귀인 보유';
    message = '문창귀인을 갖추어 시험·문서·자격증 운이 좋은 사주예요. 꾸준히 준비하면 좋은 결과로 이어질 가능성이 높아요.';
  } else if (studyGodCount >= 2) {
    style = '학구형 — 인성이 두터운 사주';
    message =
        '인성(학업성) $studyGodCount개. 배움과 탐구를 즐기는 성향이 강하고, 꾸준한 공부로 실력을 쌓는 타입이에요.';
  } else if (studyGodCount == 1) {
    style = '안정형 — 인성이 무난한 사주';
    message = '인성(학업성) 1개. 무난하게 학업을 이어가는 흐름이에요. 인성 대운·세운에서 학업운이 더 강해질 수 있어요.';
  } else {
    style = '실전형 — 이론보다 경험 중심';
    message = '인성(학업성)이 약한 사주예요. 이론 공부보다 실전 경험과 몸으로 익히는 학습 방식이 더 잘 맞을 수 있어요.';
  }

  return LifeStudyResult(
    studyGodCount: studyGodCount,
    hasMunchang: hasMunchang,
    style: style,
    message: message,
  );
}

// ============================================================
// A10 — 인생 5대 전환점 — 신규(§7 A그룹) 구현.
//
// [근거] DaewoonEngine이 이미 계산한 대운 목록(레거시 어댑터를 거치면
// [SajuResult.luckPillars])의 앞 5개 시작연령/연도를 그대로 나열한다 —
// 새 계산 없음, 순수 조회.
// ============================================================

class LifeTransitionPoint {
  const LifeTransitionPoint({
    required this.startAge,
    required this.startYear,
    required this.ganZhiKr,
  });

  final int startAge;
  final int startYear;
  final String ganZhiKr;
}

class LifeTransitionPointsResult {
  const LifeTransitionPointsResult({
    required this.points,
    required this.summary,
  });

  final List<LifeTransitionPoint> points;
  final String summary;
}

LifeTransitionPointsResult getLifeTransitionPoints(SajuResult saju) {
  final top5 = saju.luckPillars.take(5).toList();
  final points = [
    for (final lp in top5)
      LifeTransitionPoint(
        startAge: lp.startAge,
        startYear: lp.startYear,
        ganZhiKr: lp.ganZhiKr,
      ),
  ];

  final summary = points.isEmpty
      ? '대운 정보가 부족해 전환점을 계산할 수 없어요.'
      : '만 ${points.map((p) => '${p.startAge}세(${p.startYear}년)').join(', ')}에 '
            '새로운 대운(10년 단위 큰 흐름)이 시작돼요. 이 시점마다 인생의 방향이 크게 바뀔 수 있어요.';

  return LifeTransitionPointsResult(points: points, summary: summary);
}
