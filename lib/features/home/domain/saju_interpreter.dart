/// [정통사주 80종 · 로컬 해석 레이어] saju_engine_v4_final.zip 의
/// `saju_interpreter.py` 를 Dart로 완전 이식한 파일.
///
/// - [SajuEngine]이 계산한 사주 원국([SajuResult])을 입력받아, 룰 DB
///   (`assets/jeontong/rules/*.json`) 기반 템플릿 조립으로 해석 텍스트를
///   생성한다. LLM 호출 없음 · 외부 서버 호출 없음 · 호출 비용 0원.
/// - 원본 파이썬의 9개 `interpret_*()` 함수 + `full_interpretation()`을
///   그대로 1:1 대응시켜 이식했다.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'saju_engine.dart';

// ============================================================
// 룰 DB 로더 (jeontong_easy_term_toggle.dart 의 EasyTerms 패턴과 동일)
// ============================================================

/// `assets/jeontong/rules/*.json` 3종을 로드/캐시하는 싱글톤.
///
/// [SajuInterpreter]가 rules 를 동기적으로 참조할 수 있도록, 사용 전에
/// 반드시 [SajuRules.preload]를 1회 호출해 두어야 한다(앱 시작 시 또는
/// 결과 화면 `initState()`에서 fire-and-forget으로 미리 걸어두는 방식을
/// 권장 — `JeontongEasyTermToggle.preload()`와 동일 패턴).
class SajuRules {
  const SajuRules._(this.dayMaster, this.tenGods, this.fiveElements);

  final Map<String, dynamic> dayMaster;
  final Map<String, dynamic> tenGods;
  final Map<String, dynamic> fiveElements;

  static SajuRules? _cached;

  static SajuRules? get cachedOrNull => _cached;

  static Future<SajuRules> _load() async {
    Future<Map<String, dynamic>> loadJson(String name) async {
      final raw = await rootBundle.loadString('assets/jeontong/rules/$name');
      return jsonDecode(raw) as Map<String, dynamic>;
    }

    final results = await Future.wait([
      loadJson('day_master_rules.json'),
      loadJson('ten_gods_rules.json'),
      loadJson('five_elements_rules.json'),
    ]);
    return SajuRules._(results[0], results[1], results[2]);
  }

  /// fire-and-forget 프리로드. 이미 로드돼 있으면 즉시 반환한다.
  static Future<void> preload() async {
    if (_cached != null) return;
    _cached = await _load();
  }

  /// 테스트 전용 — 캐시 초기화.
  static void resetForTest() => _cached = null;
}

// ============================================================
// 해석 결과 모델 (Python dict 구조를 그대로 클래스로 옮김)
// ============================================================

class DayMasterInterpretation {
  const DayMasterInterpretation({
    required this.title,
    required this.nature,
    required this.personality,
    required this.strengths,
    required this.weaknesses,
    required this.careerFit,
  });

  final String title;
  final String nature;
  final String personality;
  final List<String> strengths;
  final List<String> weaknesses;
  final List<String> careerFit;
}

class FiveElementsInterpretation {
  const FiveElementsInterpretation({
    required this.counts,
    required this.excess,
    required this.lack,
    required this.analysis,
    required this.recommendedColor,
    required this.recommendedDirection,
    required this.goodFood,
    required this.healthFocus,
  });

  final Map<String, int> counts;
  final List<String> excess;
  final List<String> lack;
  final List<String> analysis;
  final List<String> recommendedColor;
  final String recommendedDirection;
  final List<String> goodFood;
  final List<String> healthFocus;
}

class TenGodDetail {
  const TenGodDetail({
    required this.god,
    required this.easy,
    required this.count,
    required this.meaning,
    required this.positive,
    required this.negative,
  });

  final String god;
  final String easy;
  final int count;
  final String meaning;
  final String positive;
  final String negative;
}

class TenGodsInterpretation {
  const TenGodsInterpretation({
    required this.distribution,
    required this.dominantName,
    required this.dominantEasy,
    required this.dominantCount,
    required this.details,
  });

  final Map<String, int> distribution;
  final String dominantName;
  final String dominantEasy;
  final int dominantCount;
  final List<TenGodDetail> details;
}

class WealthInterpretation {
  const WealthInterpretation({
    required this.wealthGodCount,
    required this.verdict,
    required this.message,
  });

  final int wealthGodCount;
  final String verdict;
  final String message;
}

class CareerInterpretation {
  const CareerInterpretation({
    required this.structure,
    required this.message,
    required this.recommended,
  });

  final String structure;
  final String message;
  final List<String> recommended;
}

class LoveInterpretation {
  const LoveInterpretation({
    required this.spouseGod,
    required this.count,
    required this.message,
  });

  final String spouseGod;
  final int count;
  final String message;
}

class HealthInterpretation {
  const HealthInterpretation({
    required this.coreOrgans,
    required this.warnings,
    required this.recommendedFood,
  });

  final List<String> coreOrgans;
  final List<String> warnings;
  final List<String> recommendedFood;
}

class SinsalItem {
  const SinsalItem({required this.name, required this.meaning});

  final String name;
  final String meaning;
}

class SinsalInterpretation {
  const SinsalInterpretation({required this.list});

  final List<SinsalItem> list;
}

class CurrentLuckInterpretation {
  const CurrentLuckInterpretation({
    required this.title,
    this.ageRange,
    this.ganGodName,
    this.ganGodEasy,
    this.ganGodPositive,
    this.zhiGodName,
    this.zhiGodEasy,
    this.zhiGodPositive,
    this.message,
  });

  final String title;
  final String? ageRange;
  final String? ganGodName;
  final String? ganGodEasy;
  final String? ganGodPositive;
  final String? zhiGodName;
  final String? zhiGodEasy;
  final String? zhiGodPositive;
  final String? message;
}

/// full_interpretation() 의 통합 결과 — 80종 운세의 기초 데이터.
class SajuFullInterpretation {
  const SajuFullInterpretation({
    required this.saju,
    required this.dayMasterAnalysis,
    required this.fiveElementsAnalysis,
    required this.tenGodsAnalysis,
    required this.wealthFortune,
    required this.careerFortune,
    required this.loveFortune,
    required this.healthFortune,
    required this.sinsalAnalysis,
    required this.currentLuckAnalysis,
  });

  final SajuResult saju;
  final DayMasterInterpretation dayMasterAnalysis;
  final FiveElementsInterpretation fiveElementsAnalysis;
  final TenGodsInterpretation tenGodsAnalysis;
  final WealthInterpretation wealthFortune;
  final CareerInterpretation careerFortune;
  final LoveInterpretation loveFortune;
  final HealthInterpretation healthFortune;
  final SinsalInterpretation sinsalAnalysis;
  final CurrentLuckInterpretation currentLuckAnalysis;
}

// ============================================================
// 해석 로직 — saju_interpreter.py 의 interpret_*() 이식
// ============================================================

class SajuInterpreter {
  SajuInterpreter._();

  static List<String> _strList(dynamic v) =>
      (v as List).map((e) => e.toString()).toList();

  /// interpret_day_master() 이식
  static DayMasterInterpretation interpretDayMaster(
    SajuResult saju,
    SajuRules rules,
  ) {
    final dm = saju.dayMaster;
    final strength = saju.dayMasterStrength;
    final rule = rules.dayMaster[dm.gan] as Map<String, dynamic>;

    final String level;
    final String levelKr;
    if (strength.contains('强')) {
      level = 'strong';
      levelKr = '신강';
    } else if (strength.contains('中')) {
      level = 'middle';
      levelKr = '중화';
    } else {
      level = 'weak';
      levelKr = '신약';
    }

    final personality = (rule['personality'] as Map<String, dynamic>)[level] as String;

    return DayMasterInterpretation(
      title: '일간: ${rule['kr']} (${dm.image}) · $levelKr',
      nature: rule['nature'] as String,
      personality: personality,
      strengths: _strList(rule['strengths']),
      weaknesses: _strList(rule['weaknesses']),
      careerFit: _strList(rule['career_fit']),
    );
  }

  /// interpret_five_elements() 이식
  static FiveElementsInterpretation interpretFiveElements(
    SajuResult saju,
    SajuRules rules,
  ) {
    final counts = saju.fiveElementsCount;
    final dayEl = saju.dayMaster.element;

    final excess = counts.entries.where((e) => e.value >= 3).map((e) => e.key).toList();
    final lack = counts.entries.where((e) => e.value == 0).map((e) => e.key).toList();

    final lines = <String>[];
    for (final el in excess) {
      final rule = rules.fiveElements[el] as Map<String, dynamic>;
      lines.add('[${rule['kr']} 과다 ${counts[el]}개] ${rule['excess']}');
    }
    for (final el in lack) {
      final rule = rules.fiveElements[el] as Map<String, dynamic>;
      lines.add('[${rule['kr']} 부재] ${rule['lack']}');
    }

    final dayElRule = rules.fiveElements[dayEl] as Map<String, dynamic>;

    return FiveElementsInterpretation(
      counts: counts,
      excess: excess,
      lack: lack,
      analysis: lines,
      recommendedColor: _strList(dayElRule['color']),
      recommendedDirection: dayElRule['direction'] as String,
      goodFood: _strList(dayElRule['food_good']),
      healthFocus: _strList(dayElRule['organ']),
    );
  }

  /// interpret_ten_gods() 이식
  static TenGodsInterpretation interpretTenGods(
    SajuResult saju,
    SajuRules rules,
  ) {
    final tg = saju.tenGods;
    final tally = <String, int>{};
    for (final name in tg.values) {
      tally[name] = (tally[name] ?? 0) + 1;
    }

    final dominant = tally.entries.reduce((a, b) => a.value >= b.value ? a : b);

    final sortedEntries = tally.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final details = <TenGodDetail>[];
    for (final entry in sortedEntries) {
      final rule = rules.tenGods[entry.key] as Map<String, dynamic>;
      details.add(
        TenGodDetail(
          god: rule['kr'] as String,
          easy: rule['easy'] as String,
          count: entry.value,
          meaning: rule['meaning'] as String,
          positive: rule['positive'] as String,
          negative: rule['negative'] as String,
        ),
      );
    }

    final dominantRule = rules.tenGods[dominant.key] as Map<String, dynamic>;

    return TenGodsInterpretation(
      distribution: tally,
      dominantName: dominantRule['kr'] as String,
      dominantEasy: dominantRule['easy'] as String,
      dominantCount: dominant.value,
      details: details,
    );
  }

  /// interpret_wealth() 이식
  static WealthInterpretation interpretWealth(SajuResult saju) {
    final tg = saju.tenGods;
    const wealthGods = ['정재', '편재'];
    final wealthCount = tg.values.where((v) => wealthGods.contains(v)).length;
    final strength = saju.dayMasterStrength;

    final String verdict;
    final String msg;
    if (wealthCount >= 3 && strength.contains('弱')) {
      verdict = '재다신약';
      msg = '돈복은 많은데 내 그릇이 작음. 큰돈 기회 자주 오나 관리 어려움. 동업·투자·보증 주의. 배우자에게 재물 관리 위임 유리.';
    } else if (wealthCount >= 3 && strength.contains('强')) {
      verdict = '재왕신강';
      msg = '재물운 최상. 사업·투자·유통에서 큰 성공 가능. 활동력·야망 발휘하는 시기 유리.';
    } else if (wealthCount == 0) {
      verdict = '무재격';
      msg = '재물성 없음. 명예·학문·기술 중심 삶이 유리. 무리한 사업보다 전문성 축적 권장.';
    } else if (strength.contains('强')) {
      verdict = '신강용재';
      msg = '재물을 감당할 힘 있음. 안정적 재물 축적 가능. 정재(월급·저축)+편재(투자) 균형 유리.';
    } else {
      verdict = '재약신약';
      msg = '재물·본인 모두 약함. 큰돈보다 안정적 소득에 집중. 저축·현금성 자산 위주.';
    }

    return WealthInterpretation(
      wealthGodCount: wealthCount,
      verdict: verdict,
      message: msg,
    );
  }

  /// interpret_career() 이식
  static CareerInterpretation interpretCareer(
    SajuResult saju,
    SajuRules rules,
  ) {
    final tg = saju.tenGods;
    final dm = saju.dayMaster.gan;
    final officer = tg.values.where((v) => v == '정관' || v == '편관').length;
    final printer = tg.values.where((v) => v == '정인' || v == '편인').length;
    final output = tg.values.where((v) => v == '식신' || v == '상관').length;

    final rule = rules.dayMaster[dm] as Map<String, dynamic>;
    final fits = _strList(rule['career_fit']);

    final String style;
    final String msg;
    if (officer >= 2 && printer >= 1) {
      style = '관인상생(官印相生)';
      msg = '공직·대기업·전문직에서 안정적 성장. 명예·자격증 기반 커리어 유리.';
    } else if (output >= 2) {
      style = '식상격';
      msg = '표현·창작·기획·강연·교육 분야 최적. 자기 재능으로 승부하는 프리랜서·크리에이터에 강함.';
    } else if (officer == 0 && printer == 0) {
      style = '무관무인';
      msg = '조직 부적응 성향. 독립·자영업·전문가 노선이 사주에 맞음.';
    } else {
      style = '혼합격';
      msg = '다방면 커리어 가능. 시기별 대운에 따라 조직·독립 조합 활용.';
    }

    return CareerInterpretation(structure: style, message: msg, recommended: fits);
  }

  /// interpret_love() 이식
  static LoveInterpretation interpretLove(SajuResult saju) {
    final tg = saju.tenGods;
    final gender = saju.gender;

    final List<String> spouseGods;
    final String spouseName;
    if (gender == 'male') {
      spouseGods = const ['정재', '편재'];
      spouseName = '재성(처성)';
    } else {
      spouseGods = const ['정관', '편관'];
      spouseName = '관성(부성)';
    }

    final spouseCount = tg.values.where((v) => spouseGods.contains(v)).length;

    final String msg;
    if (spouseCount == 0) {
      msg = '$spouseName 부재. 배우자 인연이 늦거나 특별한 노력 필요. 궁합·개운으로 보완 권장.';
    } else if (spouseCount == 1) {
      msg = '$spouseName 1개. 정식·안정된 배우자 인연. 결혼 후 관계 오래 유지.';
    } else if (spouseCount == 2) {
      msg = '$spouseName 2개. 이성 인연 활발. 결혼 전 진지한 선택 필요.';
    } else {
      msg = '$spouseName 3개 이상. 이성 인연 과다. 삼각관계·재혼 가능성 있어 신중한 선택 권장.';
    }

    return LoveInterpretation(spouseGod: spouseName, count: spouseCount, message: msg);
  }

  /// interpret_health() 이식
  static HealthInterpretation interpretHealth(
    SajuResult saju,
    SajuRules rules,
  ) {
    final counts = saju.fiveElementsCount;
    final dayEl = saju.dayMaster.element;

    final warnings = <String>[];
    counts.forEach((el, c) {
      final rule = rules.fiveElements[el] as Map<String, dynamic>;
      final organs = _strList(rule['organ']);
      if (c >= 3) {
        warnings.add('${rule['kr']} 과다 → ${organs.join(', ')} 계통 주의');
      } else if (c == 0) {
        warnings.add('${rule['kr']} 부재 → ${organs.join(', ')} 계통 약함');
      }
    });

    final dayRule = rules.fiveElements[dayEl] as Map<String, dynamic>;
    return HealthInterpretation(
      coreOrgans: _strList(dayRule['organ']),
      warnings: warnings,
      recommendedFood: _strList(dayRule['food_good']),
    );
  }

  static const Map<String, String> _sinsalDict = {
    '天乙貴人(천을귀인)': '최고의 귀인. 위기 때 도와줄 사람이 반드시 등장. 인복 최상.',
    '文昌貴人(문창귀인)': '공부·문서·시험운 별. 학문·자격증·저술에 유리.',
    '驛馬(역마)': '이동·여행·해외·이사 별. 활동 반경 넓음, 무역·유통·글로벌 업무 유리.',
  };

  /// interpret_sinsal() 이식
  static SinsalInterpretation interpretSinsal(SajuResult saju) {
    final results = saju.sinsal
        .map((s) => SinsalItem(name: s, meaning: _sinsalDict[s] ?? ''))
        .toList();
    return SinsalInterpretation(list: results);
  }

  /// interpret_current_luck() 이식
  static CurrentLuckInterpretation interpretCurrentLuck(
    SajuResult saju,
    SajuRules rules,
  ) {
    final luck = saju.currentLuck;
    if (luck == null) {
      return const CurrentLuckInterpretation(title: '현재 대운', message: '대운 정보 없음');
    }

    final ganZhi = luck.ganZhi;
    if (ganZhi.length < 2) {
      return const CurrentLuckInterpretation(title: '현재 대운', message: '대운 정보 부족');
    }

    final gan = ganZhi.substring(0, 1);
    final zhi = ganZhi.substring(1, 2);
    final dayGan = saju.dayMaster.gan;

    final ganGod = getTenGod(dayGan, gan);
    final zhiGod = getTenGod(dayGan, zhi);

    final ganRule = rules.tenGods[ganGod] as Map<String, dynamic>;
    final zhiRule = rules.tenGods[zhiGod] as Map<String, dynamic>;

    return CurrentLuckInterpretation(
      title: '현재 대운: ${luck.ganZhiKr} (${luck.startYear}~${luck.startYear + 9})',
      ageRange: '${luck.startAge}~${luck.startAge + 9}세',
      ganGodName: ganRule['kr'] as String,
      ganGodEasy: ganRule['easy'] as String,
      ganGodPositive: ganRule['positive'] as String,
      zhiGodName: zhiRule['kr'] as String,
      zhiGodEasy: zhiRule['easy'] as String,
      zhiGodPositive: zhiRule['positive'] as String,
      message:
          '천간 ${ganRule['kr']} + 지지 ${zhiRule['kr']} 대운. '
          '${ganRule['positive']} · ${zhiRule['positive']} 흐름이 10년간 이어짐.',
    );
  }

  /// full_interpretation() 이식 — 80종 운세의 기초가 되는 통합 해석.
  ///
  /// 호출 전 [SajuRules.preload]가 완료되어 있어야 한다(미완료 시
  /// [StateError]).
  static SajuFullInterpretation fullInterpretation(SajuResult saju) {
    final rules = SajuRules.cachedOrNull;
    if (rules == null) {
      throw StateError(
        'SajuRules 가 아직 로드되지 않았습니다. SajuRules.preload()를 '
        '먼저 await 하세요.',
      );
    }
    return SajuFullInterpretation(
      saju: saju,
      dayMasterAnalysis: interpretDayMaster(saju, rules),
      fiveElementsAnalysis: interpretFiveElements(saju, rules),
      tenGodsAnalysis: interpretTenGods(saju, rules),
      wealthFortune: interpretWealth(saju),
      careerFortune: interpretCareer(saju, rules),
      loveFortune: interpretLove(saju),
      healthFortune: interpretHealth(saju, rules),
      sinsalAnalysis: interpretSinsal(saju),
      currentLuckAnalysis: interpretCurrentLuck(saju, rules),
    );
  }
}
