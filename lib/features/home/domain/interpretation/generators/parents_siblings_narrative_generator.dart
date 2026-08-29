/// [정통사주 69종 개인화 해석 엔진 — A08 독립 파이프라인] 평생
/// 부모·형제운 Narrative Generator.
///
/// [A01/A03~A07과 동일한 구조로 신규 구현] 이 클래스는 어떤 판단도 새로
/// 하지 않는다. [ParentsSiblingsAnalyzer]가 이미 끝낸 판단
/// ([ParentsSiblingsAnalysis]의 parentPattern/parentBondStrength/
/// siblingPattern/siblingBondStrength/familyPalaceCondition/
/// familyRiskPattern/familyRelationApproach/familyBlessingDaewoonLabel 및
/// coreEvidence/supportingEvidence)을 입력으로 받아, 그 근거들을
/// term_translation_layer의 4단계 변환을 참고해 사람이 읽는 한국어 문장으로
/// "표현"만 한다.
///
/// [절대 원칙 — §9 금지 문구] "사주 뿌리부터", "오행의 흐름을 보면",
/// "여기에 더해", "사주는 정해진 운명" 같은, 어떤 카테고리에도 붙일 수 있는
/// 범용 문구는 사용하지 않는다. 모든 문장은 [ParentsSiblingsAnalysis]의
/// 실제 필드값(parentPattern/siblingPattern 이름, 인성/비겁 개수, 일간,
/// 부모형제궁 관계, 대운 라벨 등)이 문장 안에 구체적으로 드러나야 한다 —
/// 같은 pattern이라도 interpretationContext 수치가 다르면 문장의 구체적
/// 근거 설명이 달라진다.
///
/// [명리학 용어 서술 방식 — A01/A03~A07과 동일 원칙 처음부터 적용] 인성·
/// 비겁 5대 그룹 용어, 신강신약, 부모형제궁 관련 신살(공망·겁살·재살) 같은
/// 명리학 전문용어는 삭제하지 않고 그대로 유지하되, 이 Narrative 안에서
/// 처음 등장할 때만 term_translation_layer.dart의 [TermTracker]/
/// tenGodGroupPhrase/strengthPhrase/sinsalPhrase/yongsinPhrase 헬퍼로
/// "용어(쉬운 의미)"를 함께 풀어 쓰고, 같은 용어가 다시 등장하면 축약형만
/// 사용한다(§7 용어 반복 금지). 계산/개인화 로직 자체는 전혀 바뀌지 않는다
/// — [ParentsSiblingsAnalysis]가 이미 내린 판단을 "어떻게 설명하는가"만
/// 바뀐다.
///
/// [A08 고유 특징 — 이중 축 서술] A06/A07은 단일 pattern+bondStrength
/// 조합으로 coreResult 두 문장을 만들었지만, A08은 부모(인성)/형제(비겁)
/// 두 축을 모두 드러내야 하므로 coreResult부터 두 축을 함께 서술한다.
/// familyPalaceCondition(부모형제궁=월지가 관여된 합충형파해/원진 관계)은
/// 다른 카테고리가 쓰지 않는 A08만의 근거이므로, characteristics 단계에서
/// 반드시 별도 문장으로 풀어낸다.
library;

import '../../manseryeok/saju_profile.dart';
import '../analysis_evidence.dart';
import '../analyzers/parents_siblings_analysis.dart';
import '../fortune_narrative.dart';
import '../interpretation_rules.dart';
import '../narrative_generator.dart';
import '../term_translation_layer.dart';

class ParentsSiblingsNarrativeGenerator
    implements NarrativeGenerator<ParentsSiblingsAnalysis> {
  const ParentsSiblingsNarrativeGenerator();

  /// 'A — B' 형식으로 저장된 pattern/bondStrength 문자열을 (이름, 설명)으로
  /// 분리한다. ' — '가 없으면 전체를 이름으로 취급한다(방어적 처리,
  /// health/career/wealth/love/children Generator와 동일 유틸).
  (String name, String desc) _split(String labeled) {
    final idx = labeled.indexOf(' — ');
    if (idx == -1) return (labeled, '');
    return (labeled.substring(0, idx), labeled.substring(idx + 3));
  }

  @override
  FortuneNarrative generate(
    SajuProfile profile,
    ParentsSiblingsAnalysis analysis, {
    InterpretationRules rules = InterpretationRules.standard,
  }) {
    final ctx = analysis.interpretationContext;
    final (parentName, parentDesc) = _split(analysis.parentPattern);
    final (siblingName, siblingDesc) = _split(analysis.siblingPattern);
    final (parentBondName, parentBondDesc) = _split(
      analysis.parentBondStrength,
    );
    final (siblingBondName, siblingBondDesc) = _split(
      analysis.siblingBondStrength,
    );

    final parentCount = int.tryParse(ctx['parentCount'] ?? '0') ?? 0;
    final siblingCount = int.tryParse(ctx['siblingCount'] ?? '0') ?? 0;
    final strengthVerdict = ctx['strengthVerdict'] ?? '';
    final yongsinElement = ctx['yongsinElement'] ?? '';
    final foundFamilyRiskSinsal = (ctx['foundFamilyRiskSinsal'] ?? '')
        .split(',')
        .where((s) => s.trim().isNotEmpty)
        .toList();
    final dayGanKr = profile.dayPillar.stemKr;
    final dayGanHanja = profile.dayPillar.stemHanja;
    // [신규] 이 Narrative 생성 과정 전체에서 공유하는 용어 추적기(§7).
    final terms = TermTracker();

    // ── ① 핵심 결과(coreResult) — [A08 고유] 부모(인성)/형제(비겁) 두
    // 축을 함께 서술 ──
    final coreResultAll = <String>[
      '$dayGanKr($dayGanHanja) 일간의 이 사주는 부모 인연에서는 $parentName, 형제 인연에서는 $siblingName 구조를 갖고 있어요.',
      if (parentDesc.isNotEmpty) '$parentDesc.',
      if (siblingDesc.isNotEmpty) '$siblingDesc.',
    ];
    final coreResult = coreResultAll
        .take(rules.maxCoreResultSentences)
        .toList();

    // ── ② 왜 이런 결과가 나왔는가(whyThisResult) — coreEvidence를
    // sourceField 기준으로 하나씩 자연어로 풀어낸다(§7 근거 추적성).
    // [명리학 용어 서술 방식 개선] 인성·비겁 그룹 용어와 신강신약 판정어,
    // 부모형제궁 신살은 각각 tenGodGroupPhrase/strengthPhrase/
    // sinsalPhrase로 감싸, 이 Narrative 안에서 처음 등장할 때만
    // "용어(쉬운 의미)" 형태로 풀어 쓰고 재등장 시 축약형만 쓴다(§7/§8) ──
    final whyThisResult = <String>[];
    for (final e in analysis.coreEvidence) {
      switch (e.sourceField) {
        case 'tenGods+hiddenStems(5대범주 집계)':
          whyThisResult.add(
            '원국과 지장간을 함께 보면 부모를 상징하는 '
            '${tenGodGroupPhrase(terms, '인성')} $parentCount개, '
            '형제를 상징하는 ${tenGodGroupPhrase(terms, '비겁')} $siblingCount개가 나타나요.',
          );
        case 'parentCount(인성 개수)':
          whyThisResult.add(
            '${tenGodGroupPhrase(terms, '인성')} 개수만을 기준으로 판단했을 때, 이 사주의 부모 인연은 $parentName 쪽으로 기울어요.',
          );
        case 'siblingCount(비겁 개수)':
          whyThisResult.add(
            '${tenGodGroupPhrase(terms, '비겁')} 개수만을 기준으로 판단했을 때, 이 사주의 형제 인연은 $siblingName 쪽으로 기울어요.',
          );
        case 'strength.verdict + 인성 개수':
          whyThisResult.add(
            '${strengthPhrase(terms, strengthVerdict)}으로 판정되는데, '
            '이 힘이 ${tenGodGroupPhrase(terms, '인성')} $parentCount개를 받아들이는 방식을 결정해요.',
          );
        case 'strength.verdict + 비겁 개수':
          whyThisResult.add(
            '${strengthPhrase(terms, strengthVerdict)}은 ${tenGodGroupPhrase(terms, '비겁')} $siblingCount개를 활용하는 방식에도 함께 작용해요.',
          );
        case 'relationships(월지 관여 합충형파해/원진, PHASE2 실계산)':
          whyThisResult.add(
            '부모형제궁(월지)의 관계를 보면 ${analysis.familyPalaceCondition}.',
          );
        case '신살(부모형제궁 공망/겁살/재살) + 인성·비겁 부재 조합':
          if (foundFamilyRiskSinsal.isNotEmpty) {
            final phrases = foundFamilyRiskSinsal
                .map((s) => sinsalPhrase(terms, s))
                .join(' ');
            whyThisResult.add(phrases);
          }
          if (parentCount == 0 || siblingCount == 0) {
            whyThisResult.add(
              '${parentCount == 0 ? tenGodGroupPhrase(terms, '인성') : tenGodGroupPhrase(terms, '비겁')}가 '
              '원국에 나타나지 않는 부분이 있어, ${analysis.familyRiskPattern}.',
            );
          }
        case 'daewoon(PHASE4 실계산)':
          whyThisResult.add(
            '${analysis.familyBlessingDaewoonLabel} 시기가 대운에서 확인돼요.',
          );
      }
    }

    // ── ③ 나에게 나타나는 특징(characteristics) — 부모형제궁 상태(A08
    // 고유 근거)/부모·형제 각각의 실제 생활 모습/familyRelationApproach/
    // 부모형제궁 신살을 "실제 생활 모습"으로 풀어낸다 ──
    final characteristics = <String>[
      '부모형제궁(월지) 상태는 ${analysis.familyPalaceCondition}.',
      _parentBondRealLife(parentBondName),
      _siblingBondRealLife(siblingBondName),
      '부모·형제와의 관계에 임할 때는 ${analysis.familyRelationApproach}.',
      if (foundFamilyRiskSinsal.isNotEmpty)
        '부모형제궁에 ${foundFamilyRiskSinsal.join(', ')} 기운이 있어, 부모·형제 관련 사안에서 평소보다 신중함이 필요한 편이에요.',
    ].where((s) => s.trim().isNotEmpty).toList();
    final cappedCharacteristics =
        characteristics.length > rules.maxCharacteristicParagraphs
        ? characteristics.sublist(0, rules.maxCharacteristicParagraphs)
        : characteristics;

    // ── ④ 좋은 흐름(favorableFlows) ──
    final favorableFlows = List<String>.from(analysis.favorableConditions);
    if (favorableFlows.length < rules.minFavorableItems) {
      favorableFlows.add(
        '$parentName·$siblingName 구조 자체를 안정적으로 살릴 수 있는 가족 관계 환경',
      );
    }
    final cappedFavorable = favorableFlows.length > rules.maxFavorableItems
        ? favorableFlows.sublist(0, rules.maxFavorableItems)
        : favorableFlows;

    // ── ⑤ 주의할 흐름(cautionFlows) ──
    final cautionFlows = List<String>.from(analysis.cautionConditions);
    if (analysis.familyRiskPattern != '두드러진 부모·형제운 리스크 신호는 확인되지 않음' &&
        !cautionFlows.contains(analysis.familyRiskPattern)) {
      cautionFlows.add(analysis.familyRiskPattern);
    }
    if (cautionFlows.length < rules.minCautionItems) {
      cautionFlows.add(
        '$parentBondName·$siblingBondName 상태에서 부모형제궁 관계를 소홀히 하는 것',
      );
    }
    final cappedCaution = cautionFlows.length > rules.maxCautionItems
        ? cautionFlows.sublist(0, rules.maxCautionItems)
        : cautionFlows;

    // ── ⑥ 실전 가이드(practicalGuidance, 신규 필드) ──
    final practicalGuidance = <String>[
      '${analysis.familyRelationApproach.split(',').first.trim()}는 태도로 부모님을 대해 보세요.',
      if (yongsinElement.isNotEmpty)
        '${yongsinPhrase(terms, yongsinElement)}이 강해지는 시기에 부모·형제와 관련된 중요한 결정을 해보세요.',
      if (foundFamilyRiskSinsal.isNotEmpty)
        '부모형제궁의 ${foundFamilyRiskSinsal.join(', ')} 신호에 따라 관련 사안에서 여유와 대비를 함께 가져가 보세요.',
      if (analysis.familyPalaceCondition.startsWith('부모형제궁 불안') ||
          analysis.familyPalaceCondition.startsWith('부모형제궁 혼재'))
        '부모형제궁 관계가 흔들리기 쉬운 만큼, 사소한 갈등을 쌓아두지 않고 대화로 자주 풀어가는 습관을 들이면 좋아요.',
      if (analysis.familyBlessingDaewoonLabel.isNotEmpty)
        '${analysis.familyBlessingDaewoonLabel}이 오기 전까지는 $parentName·$siblingName 구조에 맞는 마음의 준비를 해두는 것이 좋아요.',
    ].where((s) => s.trim().isNotEmpty).toList();

    // ── ⑦ 시기(timingSection) — PHASE4 실계산 대운만 사용(§18) ──
    List<String>? timingSection;
    if (analysis.familyBlessingDaewoonLabel.isNotEmpty) {
      timingSection = [
        '${analysis.familyBlessingDaewoonLabel} 시기에 부모·형제 관련 인연·도움이 가장 활발해질 수 있어요.',
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
      '정리하면, 이 사주는 부모 인연에서는 $parentName, 형제 인연에서는 $siblingName 구조 속에서 '
          '$parentBondName·$siblingBondName 방식일 때 가장 자연스러운 가족 관계를 만들 수 있어요.',
      if (cappedFavorable.isNotEmpty) '특히 ${cappedFavorable.first}은 강점으로 작용해요.',
      if (cappedCaution.isNotEmpty) '다만 ${cappedCaution.first}은 계속 주의가 필요해요.',
      if (analysis.familyBlessingDaewoonLabel.isNotEmpty)
        '${analysis.familyBlessingDaewoonLabel}이 이 사주의 부모·형제운에서 특히 중요한 시기가 될 수 있어요.',
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

  /// parentBondStrength 이름별 "실제 생활에서 나타나는 모습" 부연 문장
  /// (parentBondStrength 자체 설명과 겹치지 않는 별도 관점 — §5 개인화
  /// 강화).
  String _parentBondRealLife(String parentBondName) {
    if (parentBondName.startsWith('신강중첩인')) {
      return '부모님의 지원이나 배경을 자연스럽게 활용하면서도 자기 색깔을 잃지 않는 편이에요.';
    } else if (parentBondName.startsWith('신강자립')) {
      return '부모님과 가깝긴 해도, 중요한 결정은 스스로 내리고 책임지는 편이에요.';
    } else if (parentBondName.startsWith('신약의인')) {
      return '부모님이나 윗사람의 조언을 들을 때 마음이 한결 편안해지고 방향을 잡기 쉬워지는 편이에요.';
    } else if (parentBondName.startsWith('신약무의')) {
      return '부모님의 도움을 기대하기보다 스스로 하나씩 쌓아 올리는 과정에서 더 단단해지는 편이에요.';
    }
    return '상황에 맞춰 부모님과의 심리적 거리를 유연하게 조절할 수 있는 편이에요.';
  }

  /// siblingBondStrength 이름별 "실제 생활에서 나타나는 모습" 부연 문장.
  String _siblingBondRealLife(String siblingBondName) {
    if (siblingBondName.startsWith('신강경쟁비')) {
      return '형제·동료와 경쟁하는 상황에서도 오히려 자극을 받아 더 좋은 결과를 내는 편이에요.';
    } else if (siblingBondName.startsWith('신강독립비')) {
      return '형제·동료의 도움 없이도 혼자서 잘 헤쳐나가는 힘이 있는 편이에요.';
    } else if (siblingBondName.startsWith('신약조력비')) {
      return '형제·동료와 함께 일하거나 의지할 때 부족한 부분이 채워지고 훨씬 수월해지는 편이에요.';
    } else if (siblingBondName.startsWith('신약고립비')) {
      return '혼자 다 감당하려다 지치기 쉬운 편이라, 주변에 도움을 요청하는 연습이 필요할 수 있어요.';
    }
    return '상황에 맞춰 형제·동료와의 협력 정도를 유연하게 조절할 수 있는 편이에요.';
  }
}
