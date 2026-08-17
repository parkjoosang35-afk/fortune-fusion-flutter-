/// [정통사주 69종 개인화 해석 엔진 — A03 독립 파이프라인] 평생 재물운
/// Narrative Generator.
///
/// [A04(CareerNarrativeGenerator)와 동일한 구조로 통일 — 분기점 A 승인]
/// 이 클래스는 어떤 판단도 새로 하지 않는다. [WealthAnalyzer]가 이미 끝낸
/// 판단([WealthAnalysis]의 wealthPattern/wealthStrength/incomePattern/
/// riskPattern/assetManagementStyle/wealthPeakDaewoonLabel 및
/// coreEvidence/supportingEvidence)을 입력으로 받아, 그 근거들을
/// term_translation_layer의 4단계 변환을 참고해 사람이 읽는 한국어 문장으로
/// "표현"만 한다.
///
/// [절대 원칙 — §9 금지 문구] "사주 뿌리부터", "오행의 흐름을 보면",
/// "여기에 더해", "사주는 정해진 운명" 같은, 어떤 카테고리에도 붙일 수 있는
/// 범용 문구는 사용하지 않는다. 모든 문장은 [WealthAnalysis]의 실제
/// 필드값(wealthPattern 이름, 재성/관살/인성 개수, 일간, 대운 라벨 등)이
/// 문장 안에 구체적으로 드러나야 한다 — 같은 wealthPattern이라도
/// interpretationContext 수치가 다르면 문장의 구체적 근거 설명이 달라진다.
library;

import '../../manseryeok/saju_profile.dart';
import '../analysis_evidence.dart';
import '../analyzers/wealth_analysis.dart';
import '../fortune_narrative.dart';
import '../interpretation_rules.dart';
import '../narrative_generator.dart';
import '../term_translation_layer.dart';

class WealthNarrativeGenerator implements NarrativeGenerator<WealthAnalysis> {
  const WealthNarrativeGenerator();

  @override
  FortuneNarrative generate(
    SajuProfile profile,
    WealthAnalysis analysis, {
    InterpretationRules rules = InterpretationRules.standard,
  }) {
    final ctx = analysis.interpretationContext;
    final wealthCount = ctx['wealthCount'] ?? '0';
    final officerCount = ctx['officerCount'] ?? '0';
    final printerCount = ctx['printerCount'] ?? '0';
    final jeongjaeCount = int.tryParse(ctx['jeongjaeCount'] ?? '0') ?? 0;
    final pyeonjaeCount = int.tryParse(ctx['pyeonjaeCount'] ?? '0') ?? 0;
    final gyeopjaeCount = int.tryParse(ctx['gyeopjaeCount'] ?? '0') ?? 0;
    final strengthVerdict = ctx['strengthVerdict'] ?? '';
    final dayGanKr = profile.dayPillar.stemKr;
    final dayGanHanja = profile.dayPillar.stemHanja;

    // ── ① 핵심 결과(coreResult) ──
    final coreResultAll = <String>[
      '$dayGanKr($dayGanHanja) 일간의 이 사주는 ${analysis.wealthPattern}.',
      '여기에 ${analysis.wealthStrength}.',
    ];
    final coreResult = coreResultAll.take(rules.maxCoreResultSentences).toList();

    // ── ② 왜 이런 결과가 나왔는가(whyThisResult) — coreEvidence를
    // sourceField 기준으로 하나씩 자연어로 풀어낸다(§7 근거 추적성) ──
    final whyThisResult = <String>[];
    for (final e in analysis.coreEvidence) {
      switch (e.sourceField) {
        case 'tenGods+hiddenStems(5대범주 집계)':
          whyThisResult.add(
            '원국과 지장간을 함께 보면 재성 $wealthCount개, 관살 $officerCount개, '
            '인성 $printerCount개가 나타나요.',
          );
        case 'wealthCount/officerCount/printerCount 조합':
          whyThisResult.add(
            '재성·관살·인성 개수의 조합을 기준으로 판단했을 때, '
            '이 사주는 ${analysis.wealthPattern.split(' — ').first} 쪽으로 기울어요.',
          );
        case 'strength.verdict + 재성 개수':
          final strengthPlain = strengthMeanings[strengthVerdict]?.plainKorean ?? '';
          whyThisResult.add(
            '신강신약으로는 $strengthVerdict으로 판정되는데, $strengthPlain '
            '이 힘이 재성 $wealthCount개를 감당하는 정도를 결정해요.',
          );
        case '정재/편재 occurrence 개수':
          whyThisResult.add(
            '정재 $jeongjaeCount개와 편재 $pyeonjaeCount개 중 어느 쪽이 우세한지에 따라 '
            '고정 수입인지 유동 수입인지가 갈리는데, ${analysis.incomePattern}.',
          );
        case '겁재 개수 + yongsin.gisin vs 재성오행':
          whyThisResult.add('겁재 $gyeopjaeCount개와 기신 여부를 함께 보면, ${analysis.riskPattern}.');
      }
    }
    if (jeongjaeCount > 0 || pyeonjaeCount > 0) {
      final wealthFlavor = jeongjaeCount > pyeonjaeCount
          ? (tenGodMeaningOf('정재')?.practicalMeaningFor('wealth') ?? '')
          : pyeonjaeCount > jeongjaeCount
          ? (tenGodMeaningOf('편재')?.practicalMeaningFor('wealth') ?? '')
          : '';
      if (wealthFlavor.isNotEmpty) {
        whyThisResult.add(
          '정재 $jeongjaeCount개, 편재 $pyeonjaeCount개 중 '
          '${jeongjaeCount > pyeonjaeCount ? '정재' : '편재'} 쪽이 우세해서, $wealthFlavor',
        );
      }
    }

    // ── ③ 나에게 나타나는 특징(characteristics) — assetManagementStyle/
    // incomePattern/wealthStrength를 "실제 생활 모습"으로 풀어낸다 ──
    final characteristics = <String>[
      '자산 운용 스타일은 ${analysis.assetManagementStyle}.',
      _strengthRealLife(analysis.wealthStrength),
      if (gyeopjaeCount >= 2) '겁재가 $gyeopjaeCount개로 많아, 동업이나 공동 투자에서 특히 신중함이 필요한 편이에요.',
    ].where((s) => s.trim().isNotEmpty).toList();
    final cappedCharacteristics = characteristics.length > rules.maxCharacteristicParagraphs
        ? characteristics.sublist(0, rules.maxCharacteristicParagraphs)
        : characteristics;

    // ── ④ 좋은 흐름(favorableFlows) ──
    final favorableFlows = List<String>.from(analysis.favorableConditions);
    if (favorableFlows.length < rules.minFavorableItems) {
      favorableFlows.add('${analysis.wealthPattern.split(' — ').first} 구조 자체를 살릴 수 있는 환경');
    }
    final cappedFavorable = favorableFlows.length > rules.maxFavorableItems
        ? favorableFlows.sublist(0, rules.maxFavorableItems)
        : favorableFlows;

    // ── ⑤ 주의할 흐름(cautionFlows) ──
    final cautionFlows = List<String>.from(analysis.cautionConditions);
    if (analysis.riskPattern != '두드러진 재물 리스크 신호는 확인되지 않음' &&
        !cautionFlows.contains(analysis.riskPattern)) {
      cautionFlows.add(analysis.riskPattern);
    }
    if (cautionFlows.length < rules.minCautionItems) {
      cautionFlows.add('$strengthVerdict 상태에서 무리하게 자산을 확장하는 것');
    }
    final cappedCaution = cautionFlows.length > rules.maxCautionItems
        ? cautionFlows.sublist(0, rules.maxCautionItems)
        : cautionFlows;

    // ── ⑥ 실전 가이드(practicalGuidance, 신규 필드) ──
    final practicalGuidance = <String>[
      '${analysis.assetManagementStyle.split('—').first.trim()} 방식으로 자산을 배분해 보세요.',
      if (analysis.riskPattern != '두드러진 재물 리스크 신호는 확인되지 않음')
        '${analysis.riskPattern.split(' / ').first}에 대비해, 큰 지출·투자 전에 한 번 더 확인하는 습관을 들이면 좋아요.',
      if (analysis.wealthPeakDaewoonLabel.isNotEmpty)
        '${analysis.wealthPeakDaewoonLabel}이 오기 전까지는 ${analysis.incomePattern.split(' — ').first} 성향에 맞춰 기반을 다져두는 것이 좋아요.',
    ].where((s) => s.trim().isNotEmpty).toList();

    // ── ⑦ 시기(timingSection) — PHASE4 실계산 대운만 사용(§18) ──
    List<String>? timingSection;
    if (analysis.wealthPeakDaewoonLabel.isNotEmpty) {
      timingSection = ['${analysis.wealthPeakDaewoonLabel} 시기에 재물운이 가장 활발해질 수 있어요.'];
      final currentDaewoonEvidence = analysis.supportingEvidence
          .where((e) => e.sourceField == 'currentDaewoon(PHASE4 실계산)')
          .toList();
      if (currentDaewoonEvidence.isNotEmpty) {
        timingSection.add(currentDaewoonEvidence.first.judgment);
      }
    }

    // ── ⑧ 최종 정리(finalSummary) ──
    final finalSummaryAll = <String>[
      '정리하면, 이 사주는 ${analysis.wealthPattern.split(' — ').first} 구조 속에서 '
          '${analysis.incomePattern.split(' — ').first} 수입 방식일 때 가장 자연스러운 흐름을 만들 수 있어요.',
      if (cappedFavorable.isNotEmpty) '특히 ${cappedFavorable.first}은 강점으로 작용해요.',
      if (cappedCaution.isNotEmpty) '다만 ${cappedCaution.first}은 계속 주의가 필요해요.',
      if (analysis.wealthPeakDaewoonLabel.isNotEmpty)
        '${analysis.wealthPeakDaewoonLabel}이 이 사주의 재물운에서 특히 중요한 시기가 될 수 있어요.',
      if (analysis.confidence == AnalysisConfidence.low)
        '다만 원국에 재성·관살 근거 글자가 뚜렷하지 않아, 이 판단은 참고 정도로 받아들여 주세요.',
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

  /// wealthStrength 이름별 "실제 생활에서 나타나는 모습" 부연 문장
  /// (wealthStrength 자체 설명과 겹치지 않는 별도 관점 — §5 개인화 강화).
  String _strengthRealLife(String wealthStrength) {
    if (wealthStrength.startsWith('재왕신강')) {
      return '돈이 들어오고 나가는 규모 자체가 커도 흔들리지 않고 관리하는 편이에요.';
    } else if (wealthStrength.startsWith('신강용재')) {
      return '아직 재물 활용 여지가 남아 있어, 새로운 수입원을 시도해볼 힘은 충분한 편이에요.';
    } else if (wealthStrength.startsWith('재다신약')) {
      return '기회는 자주 오는데, 그걸 다 소화하려다 오히려 지치기 쉬운 편이에요.';
    } else if (wealthStrength.startsWith('재약신약')) {
      return '큰 돈을 굴리기보다, 조금씩 꾸준히 모아가는 쪽이 마음도 편한 편이에요.';
    }
    return '상황에 맞춰 유연하게 자산 규모를 조절할 수 있는 편이에요.';
  }
}
