/// [정통사주 69종 개인화 해석 엔진 — A07 독립 파이프라인] 평생 자녀운
/// Narrative Generator.
///
/// [A01/A03/A04/A05/A06과 동일한 구조로 신규 구현] 이 클래스는 어떤
/// 판단도 새로 하지 않는다. [ChildrenAnalyzer]가 이미 끝낸 판단
/// ([ChildrenAnalysis]의 childPattern/childBondStrength/
/// childPalaceCondition/childRiskPattern/childRearingApproach/
/// childBlessingDaewoonLabel 및 coreEvidence/supportingEvidence)을
/// 입력으로 받아, 그 근거들을 term_translation_layer의 4단계 변환을
/// 참고해 사람이 읽는 한국어 문장으로 "표현"만 한다.
///
/// [절대 원칙 — §9 금지 문구] "사주 뿌리부터", "오행의 흐름을 보면",
/// "여기에 더해", "사주는 정해진 운명" 같은, 어떤 카테고리에도 붙일 수 있는
/// 범용 문구는 사용하지 않는다. 모든 문장은 [ChildrenAnalysis]의 실제
/// 필드값(childPattern 이름, 자녀성/인성 개수, 일간, 자녀궁 관계, 대운
/// 라벨 등)이 문장 안에 구체적으로 드러나야 한다 — 같은 childPattern이라도
/// interpretationContext 수치가 다르면 문장의 구체적 근거 설명이 달라진다.
///
/// [명리학 용어 서술 방식 — A01/A03/A04/A05/A06과 동일 원칙 처음부터 적용]
/// 자녀성(관살/식상)·인성 5대 그룹 용어, 신강신약, 자녀궁 관련 신살(공망·
/// 겁살·재살) 같은 명리학 전문용어는 삭제하지 않고 그대로 유지하되, 이
/// Narrative 안에서 처음 등장할 때만 term_translation_layer.dart의
/// [TermTracker]/tenGodGroupPhrase/strengthPhrase/sinsalPhrase/
/// yongsinPhrase 헬퍼로 "용어(쉬운 의미)"를 함께 풀어 쓰고, 같은 용어가
/// 다시 등장하면 축약형만 사용한다(§7 용어 반복 금지). 계산/개인화 로직
/// 자체는 전혀 바뀌지 않는다 — [ChildrenAnalysis]가 이미 내린 판단을
/// "어떻게 설명하는가"만 바뀐다.
///
/// [A07 고유 특징] childPalaceCondition(자녀궁=시지가 관여된 합충형파해/
/// 원진 관계)은 다른 카테고리가 쓰지 않는 A07만의 근거이므로,
/// characteristics 단계에서 반드시 별도 문장으로 풀어낸다.
library;

import '../../manseryeok/saju_profile.dart';
import '../analysis_evidence.dart';
import '../analyzers/children_analysis.dart';
import '../fortune_narrative.dart';
import '../interpretation_rules.dart';
import '../narrative_generator.dart';
import '../term_translation_layer.dart';

class ChildrenNarrativeGenerator
    implements NarrativeGenerator<ChildrenAnalysis> {
  const ChildrenNarrativeGenerator();

  /// 'A — B' 형식으로 저장된 childPattern/childBondStrength 문자열을
  /// (이름, 설명)으로 분리한다. ' — '가 없으면 전체를 이름으로 취급한다
  /// (방어적 처리, health/career/wealth/love Generator와 동일 유틸).
  (String name, String desc) _split(String labeled) {
    final idx = labeled.indexOf(' — ');
    if (idx == -1) return (labeled, '');
    return (labeled.substring(0, idx), labeled.substring(idx + 3));
  }

  @override
  FortuneNarrative generate(
    SajuProfile profile,
    ChildrenAnalysis analysis, {
    InterpretationRules rules = InterpretationRules.standard,
  }) {
    final ctx = analysis.interpretationContext;
    final (patternName, patternDesc) = _split(analysis.childPattern);
    final (bondName, bondDesc) = _split(analysis.childBondStrength);

    final childCategory = ctx['childCategory'] ?? '';
    final childCount = int.tryParse(ctx['childCount'] ?? '0') ?? 0;
    final inseongCount = int.tryParse(ctx['inseongCount'] ?? '0') ?? 0;
    final strengthVerdict = ctx['strengthVerdict'] ?? '';
    final yongsinElement = ctx['yongsinElement'] ?? '';
    final foundChildRiskSinsal = (ctx['foundChildRiskSinsal'] ?? '')
        .split(',')
        .where((s) => s.trim().isNotEmpty)
        .toList();
    final dayGanKr = profile.dayPillar.stemKr;
    final dayGanHanja = profile.dayPillar.stemHanja;
    // [신규] 이 Narrative 생성 과정 전체에서 공유하는 용어 추적기(§7).
    final terms = TermTracker();

    // ── ① 핵심 결과(coreResult) ──
    final coreResultAll = <String>[
      '$dayGanKr($dayGanHanja) 일간의 이 사주는 $patternName 구조를 갖고 있어요. $patternDesc.',
      if (bondDesc.isNotEmpty) '여기에 $bondName 상태가 더해져, $bondDesc.',
    ];
    final coreResult = coreResultAll
        .take(rules.maxCoreResultSentences)
        .toList();

    // ── ② 왜 이런 결과가 나왔는가(whyThisResult) — coreEvidence를
    // sourceField 기준으로 하나씩 자연어로 풀어낸다(§7 근거 추적성).
    // [명리학 용어 서술 방식 개선] 자녀성(관살/식상)·인성 그룹 용어와
    // 신강신약 판정어, 자녀궁 신살은 각각 tenGodGroupPhrase/strengthPhrase/
    // sinsalPhrase로 감싸, 이 Narrative 안에서 처음 등장할 때만
    // "용어(쉬운 의미)" 형태로 풀어 쓰고 재등장 시 축약형만 쓴다(§7/§8) ──
    final whyThisResult = <String>[];
    for (final e in analysis.coreEvidence) {
      switch (e.sourceField) {
        case 'birthInfo.gender + tenGods+hiddenStems(5대범주 집계)':
          whyThisResult.add(
            '원국과 지장간을 함께 보면 자녀를 상징하는 '
            '${tenGodGroupPhrase(terms, childCategory)} $childCount개, '
            '육아를 돕는 기운인 ${tenGodGroupPhrase(terms, '인성')} $inseongCount개가 나타나요.',
          );
        case 'childCount/inseongCount 조합':
          whyThisResult.add(
            '${tenGodGroupPhrase(terms, childCategory)}·${tenGodGroupPhrase(terms, '인성')} 개수의 '
            '조합을 기준으로 판단했을 때, 이 사주는 $patternName 쪽으로 기울어요.',
          );
        case 'strength.verdict + 자녀성 개수':
          whyThisResult.add(
            '${strengthPhrase(terms, strengthVerdict)}으로 판정되는데, '
            '이 힘이 ${tenGodGroupPhrase(terms, childCategory)} $childCount개를 감당하는 정도를 결정해요.',
          );
        case 'relationships(시지 관여 합충형파해/원진, PHASE2 실계산)':
          whyThisResult.add(
            '자녀궁(시지)의 관계를 보면 ${analysis.childPalaceCondition}.',
          );
        case '신살(자녀궁 공망/겁살/재살) + 자녀성 부재 조합':
          if (foundChildRiskSinsal.isNotEmpty) {
            final phrases = foundChildRiskSinsal
                .map((s) => sinsalPhrase(terms, s))
                .join(' ');
            whyThisResult.add(phrases);
          }
          if (childCount == 0) {
            whyThisResult.add(
              '${tenGodGroupPhrase(terms, childCategory)}가 원국에 나타나지 않아, ${analysis.childRiskPattern}.',
            );
          }
        case 'daewoon(PHASE4 실계산)':
          whyThisResult.add(
            '${analysis.childBlessingDaewoonLabel} 시기가 대운에서 확인돼요.',
          );
      }
    }

    // ── ③ 나에게 나타나는 특징(characteristics) — 자녀궁 상태(A07 고유
    // 근거)/childRearingApproach/자녀궁 신살을 "실제 생활 모습"으로
    // 풀어낸다 ──
    final characteristics = <String>[
      '자녀궁(시지) 상태는 ${analysis.childPalaceCondition}.',
      _bondRealLife(bondName),
      '자녀와의 관계·육아에 임할 때는 ${analysis.childRearingApproach}.',
      if (foundChildRiskSinsal.isNotEmpty)
        '자녀궁에 ${foundChildRiskSinsal.join(', ')} 기운이 있어, 자녀 관련 사안에서 평소보다 신중함이 필요한 편이에요.',
    ].where((s) => s.trim().isNotEmpty).toList();
    final cappedCharacteristics =
        characteristics.length > rules.maxCharacteristicParagraphs
        ? characteristics.sublist(0, rules.maxCharacteristicParagraphs)
        : characteristics;

    // ── ④ 좋은 흐름(favorableFlows) ──
    final favorableFlows = List<String>.from(analysis.favorableConditions);
    if (favorableFlows.length < rules.minFavorableItems) {
      favorableFlows.add('$patternName 구조 자체를 안정적으로 살릴 수 있는 육아 환경');
    }
    final cappedFavorable = favorableFlows.length > rules.maxFavorableItems
        ? favorableFlows.sublist(0, rules.maxFavorableItems)
        : favorableFlows;

    // ── ⑤ 주의할 흐름(cautionFlows) ──
    final cautionFlows = List<String>.from(analysis.cautionConditions);
    if (analysis.childRiskPattern != '두드러진 자녀운 리스크 신호는 확인되지 않음' &&
        !cautionFlows.contains(analysis.childRiskPattern)) {
      cautionFlows.add(analysis.childRiskPattern);
    }
    if (cautionFlows.length < rules.minCautionItems) {
      cautionFlows.add('$bondName 상태에서 자녀궁 관계를 소홀히 하는 것');
    }
    final cappedCaution = cautionFlows.length > rules.maxCautionItems
        ? cautionFlows.sublist(0, rules.maxCautionItems)
        : cautionFlows;

    // ── ⑥ 실전 가이드(practicalGuidance, 신규 필드) ──
    final practicalGuidance = <String>[
      '${analysis.childRearingApproach.split('편이').first.trim()} 편으로 자녀와의 관계를 이끌어 보세요.',
      if (yongsinElement.isNotEmpty)
        '${yongsinPhrase(terms, yongsinElement)}이 강해지는 시기에 자녀와 관련된 중요한 결정을 해보세요.',
      if (foundChildRiskSinsal.isNotEmpty)
        '자녀궁의 ${foundChildRiskSinsal.join(', ')} 신호에 따라 자녀 관련 사안에서 여유와 대비를 함께 가져가 보세요.',
      if (analysis.childPalaceCondition.startsWith('자녀궁 불안') ||
          analysis.childPalaceCondition.startsWith('자녀궁 혼재'))
        '자녀궁 관계가 흔들리기 쉬운 만큼, 사소한 갈등을 쌓아두지 않고 대화로 자주 풀어가는 습관을 들이면 좋아요.',
      if (analysis.childBlessingDaewoonLabel.isNotEmpty)
        '${analysis.childBlessingDaewoonLabel}이 오기 전까지는 $patternName 구조에 맞는 마음의 준비를 해두는 것이 좋아요.',
    ].where((s) => s.trim().isNotEmpty).toList();

    // ── ⑦ 시기(timingSection) — PHASE4 실계산 대운만 사용(§18) ──
    List<String>? timingSection;
    if (analysis.childBlessingDaewoonLabel.isNotEmpty) {
      timingSection = [
        '${analysis.childBlessingDaewoonLabel} 시기에 자녀 관련 인연·경사가 가장 활발해질 수 있어요.',
      ];
      final currentDaewoonEvidence = analysis.supportingEvidence
          .where((e) => e.sourceField == 'currentDaewoon(PHASE4 실계산)')
          .toList();
      if (currentDaewoonEvidence.isNotEmpty) {
        timingSection.add(currentDaewoonEvidence.first.judgment);
      }
    }

    // ── ⑧ 최종 정리(finalSummary) ──
    final finalSummaryAll = <String>[
      '정리하면, 이 사주는 $patternName 구조 속에서 $bondName 방식일 때 가장 자연스러운 자녀 인연을 만들 수 있어요.',
      if (cappedFavorable.isNotEmpty) '특히 ${cappedFavorable.first}은 강점으로 작용해요.',
      if (cappedCaution.isNotEmpty) '다만 ${cappedCaution.first}은 계속 주의가 필요해요.',
      if (analysis.childBlessingDaewoonLabel.isNotEmpty)
        '${analysis.childBlessingDaewoonLabel}이 이 사주의 자녀운에서 특히 중요한 시기가 될 수 있어요.',
      if (analysis.confidence == AnalysisConfidence.low)
        '다만 신강신약·용신 근거가 뚜렷하지 않아, 이 판단은 참고 정도로 받아들여 주세요.',
    ];
    final finalSummary = finalSummaryAll.length > rules.maxSummarySentences
        ? finalSummaryAll.sublist(0, rules.maxSummarySentences)
        : finalSummaryAll;

    return FortuneNarrative(
      categoryId: analysis.categoryId,
      categoryName: analysis.categoryName,
      coreResult: coreResult,
      whyThisResult: whyThisResult,
      characteristics: cappedCharacteristics,
      favorableFlows: cappedFavorable,
      cautionFlows: cappedCaution,
      practicalGuidance: practicalGuidance,
      timingSection: timingSection,
      finalSummary: finalSummary,
    );
  }

  /// childBondStrength 이름별 "실제 생활에서 나타나는 모습" 부연 문장
  /// (childBondStrength 자체 설명과 겹치지 않는 별도 관점 — §5 개인화
  /// 강화).
  String _bondRealLife(String bondName) {
    if (bondName.startsWith('신강용육')) {
      return '육아나 자녀 교육에서 먼저 방향을 잡아주는 역할을 편안하게 받아들이는 편이에요.';
    } else if (bondName.startsWith('신강경육')) {
      return '혼자서도 육아를 잘 감당하는 편이라, 자녀 인연을 스스로 적극적으로 만들어가야 관계가 깊어지는 편이에요.';
    } else if (bondName.startsWith('다자신약')) {
      return '자녀와 관련된 기회는 많은데, 그걸 다 감당하려다 오히려 지치기 쉬운 편이에요.';
    } else if (bondName.startsWith('신약보육')) {
      return '혼자보다는 배우자·주변과 함께일 때 훨씬 안정감을 느끼고, 자녀와의 관계도 더 편안해지는 편이에요.';
    }
    return '상황에 맞춰 유연하게 자녀와의 관계 온도를 조절할 수 있는 편이에요.';
  }
}
