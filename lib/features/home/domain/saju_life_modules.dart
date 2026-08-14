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
