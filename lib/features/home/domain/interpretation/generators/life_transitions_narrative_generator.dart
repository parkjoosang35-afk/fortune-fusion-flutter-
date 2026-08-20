/// [정통사주 69종 개인화 해석 엔진 — A10 독립 파이프라인] 인생 5대
/// 전환점 Narrative Generator.
///
/// [A01/A03~A09와 동일한 구조로 신규 구현] 이 클래스는 어떤 판단도 새로
/// 하지 않는다. [LifeTransitionsAnalyzer]가 이미 끝낸 판단
/// ([LifeTransitionsAnalysis]의 transitionPattern/transitionBondStrength/
/// turningPointsCondition/transitionRiskPattern/transitionApproach/
/// keyTurningPointLabel 및 coreEvidence/supportingEvidence)을 입력으로
/// 받아, 그 근거들을 term_translation_layer의 4단계 변환을 참고해 사람이
/// 읽는 한국어 문장으로 "표현"만 한다.
///
/// [절대 원칙 — §9 금지 문구] "사주 뿌리부터", "오행의 흐름을 보면",
/// "여기에 더해", "사주는 정해진 운명" 같은, 어떤 카테고리에도 붙일 수 있는
/// 범용 문구는 사용하지 않는다. 모든 문장은 [LifeTransitionsAnalysis]의
/// 실제 필드값(transitionPattern 이름, 대전환 개수, 전환점별 라벨, 일간,
/// 핵심 전환점 대운 라벨 등)이 문장 안에 구체적으로 드러나야 한다 — 같은
/// transitionPattern이라도 interpretationContext 수치가 다르면 문장의
/// 구체적 근거 설명이 달라진다.
///
/// [명리학 용어 서술 방식 — A01/A03~A09와 동일 원칙 처음부터 적용]
/// 십신 5대 그룹 용어, 신강신약, 용신/기신 같은 명리학 전문용어는 삭제하지
/// 않고 그대로 유지하되, 이 Narrative 안에서 처음 등장할 때만
/// term_translation_layer.dart의 [TermTracker]/tenGodGroupPhrase/
/// strengthPhrase/yongsinPhrase/gisinPhrase 헬퍼로 "용어(쉬운 의미)"를
/// 함께 풀어 쓰고, 같은 용어가 다시 등장하면 축약형만 사용한다(§7 용어
/// 반복 금지). 계산/개인화 로직 자체는 전혀 바뀌지 않는다 —
/// [LifeTransitionsAnalysis]가 이미 내린 판단을 "어떻게 설명하는가"만
/// 바뀐다.
///
/// [A10 고유 특징] turningPointsCondition(대운 앞 5개 각각의 대전환/
/// 소전환/순환형 + 호전/주의/중립 판정을 순서대로 나열한 문자열)은 다른
/// 카테고리가 쓰지 않는 A10만의 근거이므로, characteristics 단계에서
/// 반드시 별도 문장으로 풀어낸다.
library;

import '../../manseryeok/saju_profile.dart';
import '../analysis_evidence.dart';
import '../analyzers/life_transitions_analysis.dart';
import '../fortune_narrative.dart';
import '../interpretation_rules.dart';
import '../narrative_generator.dart';
import '../term_translation_layer.dart';

class LifeTransitionsNarrativeGenerator
    implements NarrativeGenerator<LifeTransitionsAnalysis> {
  const LifeTransitionsNarrativeGenerator();

  /// 'A — B' 형식으로 저장된 transitionPattern/transitionBondStrength
  /// 문자열을 (이름, 설명)으로 분리한다. ' — '가 없으면 전체를 이름으로
  /// 취급한다(방어적 처리, health/career/wealth/love/children/
  /// parents_siblings/study Generator와 동일 유틸).
  (String name, String desc) _split(String labeled) {
    final idx = labeled.indexOf(' — ');
    if (idx == -1) return (labeled, '');
    return (labeled.substring(0, idx), labeled.substring(idx + 3));
  }

  @override
  FortuneNarrative generate(
    SajuProfile profile,
    LifeTransitionsAnalysis analysis, {
    InterpretationRules rules = InterpretationRules.standard,
  }) {
    final ctx = analysis.interpretationContext;
    final (patternName, patternDesc) = _split(analysis.transitionPattern);
    final (bondName, bondDesc) = _split(analysis.transitionBondStrength);

    final bigTransitionCount = int.tryParse(ctx['bigTransitionCount'] ?? '0') ?? 0;
    final strengthVerdict = ctx['strengthVerdict'] ?? '';
    final yongsinElement = ctx['yongsinElement'] ?? '';
    final gisinElement = ctx['gisinElement'] ?? '';
    final yongsinTransitionCount = int.tryParse(ctx['yongsinTransitionCount'] ?? '0') ?? 0;
    final gisinTransitionCount = int.tryParse(ctx['gisinTransitionCount'] ?? '0') ?? 0;
    final dayGanKr = profile.dayPillar.stemKr;
    final dayGanHanja = profile.dayPillar.stemHanja;
    // [신규] 이 Narrative 생성 과정 전체에서 공유하는 용어 추적기(§7).
    final terms = TermTracker();

    // ── ① 핵심 결과(coreResult) ──
    final coreResultAll = <String>[
      '$dayGanKr($dayGanHanja) 일간의 이 사주는 $patternName 구조를 갖고 있어요. $patternDesc.',
      if (bondDesc.isNotEmpty) '여기에 $bondName 상태가 더해져, $bondDesc.',
    ];
    final coreResult = coreResultAll.take(rules.maxCoreResultSentences).toList();

    // ── ② 왜 이런 결과가 나왔는가(whyThisResult) — coreEvidence를
    // sourceField 기준으로 하나씩 자연어로 풀어낸다(§7 근거 추적성).
    // [명리학 용어 서술 방식 개선] 신강신약 판정어와 용신/기신은 각각
    // strengthPhrase/yongsinPhrase/gisinPhrase로 감싸, 이 Narrative
    // 안에서 처음 등장할 때만 "용어(쉬운 의미)" 형태로 풀어 쓰고 재등장
    // 시 축약형만 쓴다(§7/§8) ──
    final whyThisResult = <String>[];
    for (final e in analysis.coreEvidence) {
      switch (e.sourceField) {
        case 'daewoon(PHASE4 실계산, 앞 5개)':
          whyThisResult.add(
            '평생 대운 목록 앞 5개를 이전 대운과 하나씩 비교해 보면, 대전환이 $bigTransitionCount개 확인돼요.',
          );
        case 'bigTransitionCount(대전환 개수)':
          whyThisResult.add(
            '대전환 개수를 기준으로 판단했을 때, 이 사주는 $patternName 구조 쪽으로 기울어요.',
          );
        case 'strength.verdict + bigTransitionCount':
          whyThisResult.add(
            '${strengthPhrase(terms, strengthVerdict)}으로 판정되는데, '
            '이 힘이 대전환 $bigTransitionCount개를 받아들이는 방식을 결정해요.',
          );
        case '대운 전환점별 십신범주 변화 + 용신/기신 대조(PHASE4 실계산)':
          whyThisResult.add(
            '전환점을 하나씩 살펴보면 ${analysis.turningPointsCondition}.',
          );
        case '기신 대조 전환점 + bigTransitionCount 조합':
          whyThisResult.add(
            '${gisinElement.isNotEmpty ? gisinPhrase(terms, gisinElement) : '기신'}과 맞닿은 전환점이 $gisinTransitionCount개 확인돼, ${analysis.transitionRiskPattern}.',
          );
        case 'daewoon(PHASE4 실계산) — 호전+대전환 우선 채택':
          whyThisResult.add(
            '${yongsinElement.isNotEmpty ? yongsinPhrase(terms, yongsinElement) : '용신'}과 맞닿은 전환점 중에서는 ${analysis.keyTurningPointLabel} 시기가 가장 주목할 만해요.',
          );
      }
    }

    // ── ③ 나에게 나타나는 특징(characteristics) — 전환점별 상세(A10
    // 고유 근거)/transitionApproach를 "실제 생활 모습"으로 풀어낸다 ──
    final characteristics = <String>[
      '전환점별 상세를 순서대로 보면 ${analysis.turningPointsCondition}.',
      _bondRealLife(bondName),
      '전환기를 대할 때는 ${analysis.transitionApproach}.',
      if (yongsinTransitionCount > 0)
        '$yongsinTransitionCount개의 전환점이 ${yongsinElement.isNotEmpty ? yongsinPhrase(terms, yongsinElement) : '용신'}과 맞닿아 있어, 그 시기마다 새로운 국면이 오히려 순조롭게 풀릴 가능성이 있어요.',
    ].where((s) => s.trim().isNotEmpty).toList();
    final cappedCharacteristics = characteristics.length > rules.maxCharacteristicParagraphs
        ? characteristics.sublist(0, rules.maxCharacteristicParagraphs)
        : characteristics;

    // ── ④ 좋은 흐름(favorableFlows) ──
    final favorableFlows = List<String>.from(analysis.favorableConditions);
    if (favorableFlows.length < rules.minFavorableItems) {
      favorableFlows.add('$patternName 구조 자체를 안정적으로 살릴 수 있는 준비 기간');
    }
    final cappedFavorable = favorableFlows.length > rules.maxFavorableItems
        ? favorableFlows.sublist(0, rules.maxFavorableItems)
        : favorableFlows;

    // ── ⑤ 주의할 흐름(cautionFlows) ──
    final cautionFlows = List<String>.from(analysis.cautionConditions);
    if (analysis.transitionRiskPattern != '두드러진 전환점 리스크 신호는 확인되지 않음' &&
        !cautionFlows.contains(analysis.transitionRiskPattern)) {
      cautionFlows.add(analysis.transitionRiskPattern);
    }
    if (cautionFlows.length < rules.minCautionItems) {
      cautionFlows.add('$bondName 상태에서 전환기 준비를 소홀히 하는 것');
    }
    final cappedCaution = cautionFlows.length > rules.maxCautionItems
        ? cautionFlows.sublist(0, rules.maxCautionItems)
        : cautionFlows;

    // ── ⑥ 실전 가이드(practicalGuidance, 신규 필드) ──
    final practicalGuidance = <String>[
      '${analysis.transitionApproach.split('편').first.trim()} 방식으로 전환기를 준비해보세요.',
      if (gisinTransitionCount > 0)
        '${gisinElement.isNotEmpty ? gisinPhrase(terms, gisinElement) : '기신'}과 맞닿은 전환점이 다가올 때는 중요한 결정을 서두르지 말고 여유를 두고 판단해보세요.',
      if (analysis.keyTurningPointLabel.isNotEmpty)
        '${analysis.keyTurningPointLabel} 시기를 앞두고는 새로운 도전을 미리 계획해두는 것이 좋아요.',
      if (bigTransitionCount == 0)
        '큰 전환점이 두드러지지 않는 만큼, 지금의 흐름을 꾸준히 이어가는 편이 오히려 좋은 성과로 이어질 수 있어요.',
    ].where((s) => s.trim().isNotEmpty).toList();

    // ── ⑦ 시기(timingSection) — PHASE4 실계산 대운만 사용(§18) ──
    List<String>? timingSection;
    if (analysis.keyTurningPointLabel.isNotEmpty) {
      timingSection = ['${analysis.keyTurningPointLabel} 시기가 이 사주의 인생 전환점 중 가장 주목할 시기예요.'];
      final currentDaewoonEvidence = analysis.supportingEvidence
          .where((e) => e.sourceField == 'currentDaewoon(PHASE4 실계산)')
          .toList();
      if (currentDaewoonEvidence.isNotEmpty) {
        timingSection.add(currentDaewoonEvidence.first.judgment);
      }
    }

    // ── ⑧ 최종 정리(finalSummary) ──
    final finalSummaryAll = <String>[
      '정리하면, 이 사주는 $patternName 구조 속에서 $bondName 방식일 때 전환기를 가장 자연스럽게 지나갈 수 있어요.',
      if (cappedFavorable.isNotEmpty) '특히 ${cappedFavorable.first}은 강점으로 작용해요.',
      if (cappedCaution.isNotEmpty) '다만 ${cappedCaution.first}은 계속 주의가 필요해요.',
      if (analysis.keyTurningPointLabel.isNotEmpty)
        '${analysis.keyTurningPointLabel}이 이 사주의 인생 전환점 중 특히 중요한 시기가 될 수 있어요.',
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

  /// transitionBondStrength 이름별 "실제 생활에서 나타나는 모습" 부연
  /// 문장(transitionBondStrength 자체 설명과 겹치지 않는 별도 관점 —
  /// §5 개인화 강화).
  String _bondRealLife(String bondName) {
    if (bondName.startsWith('신강주도')) {
      return '전환기가 다가오면 오히려 먼저 움직여 새로운 길을 개척하는 편이에요.';
    } else if (bondName.startsWith('신강안정')) {
      return '평소에는 묵묵히 힘을 쌓아두고, 전환기가 오면 그 힘으로 자연스럽게 다음 단계로 넘어가는 편이에요.';
    } else if (bondName.startsWith('신약격동')) {
      return '전환기가 몰아칠 때 주변 사람들의 도움이 있으면 훨씬 수월하게 넘어갈 수 있는 편이에요.';
    } else if (bondName.startsWith('신약적응')) {
      return '변화의 속도를 서두르지 않고 하나씩 익혀가며 자리를 잡아가는 편이에요.';
    }
    return '상황에 맞춰 전환기를 대하는 태도를 유연하게 조절할 수 있는 편이에요.';
  }
}
