/// [정통사주 69종 개인화 해석 엔진 — A04 독립 파이프라인] 평생 직업·명예운
/// Narrative Generator.
///
/// 사용자 최종 지시 §20/§21에 따라, 이 클래스는 어떤 판단도 새로 하지
/// 않는다. [CareerAnalyzer]가 이미 끝낸 판단([CareerAnalysis]의
/// careerPattern/careerStrength/workStyle/suitableFields/
/// careerRiskPattern/careerPeakDaewoonLabel 및 coreEvidence/
/// supportingEvidence)을 입력으로 받아, 그 근거들을 term_translation_layer
/// 의 4단계 변환을 참고해 사람이 읽는 한국어 문장으로 "표현"만 한다.
///
/// [절대 원칙 — §9 금지 문구] "사주 뿌리부터", "오행의 흐름을 보면",
/// "여기에 더해", "사주는 정해진 운명" 같은, 어떤 카테고리에도 붙일 수 있는
/// 범용 문구는 사용하지 않는다. 모든 문장은 [CareerAnalysis]의 실제 필드값
/// (careerPattern 이름, 관살/인성/식상 개수, 일간, 대운 라벨 등)이 문장
/// 안에 구체적으로 드러나야 한다 — 같은 careerPattern이라도
/// interpretationContext 수치가 다르면 문장의 구체적 근거 설명이 달라진다.
///
/// [2026-08-2x 확장 — "정통사주 결과 해석 방식 최종 수정 지시"] 명리학
/// 전문용어(관살/인성/식상/비겁/정관/편관/신강신약 등)는 삭제하지 않고
/// 그대로 유지하되, 이 Narrative 안에서 처음 등장할 때만
/// term_translation_layer.dart의 [TermTracker]/tenGodGroupPhrase/
/// tenGodPhrase/strengthPhrase 헬퍼로 "용어(쉬운 의미)"를 함께 풀어 쓰고,
/// 같은 용어가 다시 등장하면 축약형("관살의 힘" 등)만 사용한다(§7 용어
/// 반복 금지). 계산/개인화 로직 자체는 전혀 바뀌지 않는다 — [CareerAnalysis]
/// 가 이미 내린 판단을 "어떻게 설명하는가"만 바뀐다.
library;

import '../../manseryeok/saju_profile.dart';
import '../analysis_evidence.dart';
import '../analyzers/career_analysis.dart';
import '../fortune_narrative.dart';
import '../interpretation_rules.dart';
import '../narrative_generator.dart';
import '../term_translation_layer.dart';

class CareerNarrativeGenerator implements NarrativeGenerator<CareerAnalysis> {
  const CareerNarrativeGenerator();

  /// 'A — B' 형식으로 저장된 careerPattern/careerStrength/workStyle
  /// 문자열을 (이름, 설명)으로 분리한다. ' — '가 없으면 전체를 이름으로
  /// 취급한다(방어적 처리).
  (String name, String desc) _split(String labeled) {
    final idx = labeled.indexOf(' — ');
    if (idx == -1) return (labeled, '');
    return (labeled.substring(0, idx), labeled.substring(idx + 3));
  }

  @override
  FortuneNarrative generate(
    SajuProfile profile,
    CareerAnalysis analysis, {
    InterpretationRules rules = InterpretationRules.standard,
  }) {
    final ctx = analysis.interpretationContext;
    final (patternName, patternDesc) = _split(analysis.careerPattern);
    final (strengthName, strengthDesc) = _split(analysis.careerStrength);
    final (workStyleName, workStyleDesc) = _split(analysis.workStyle);

    final officerCount = ctx['officerCount'] ?? '0';
    final printerCount = ctx['printerCount'] ?? '0';
    final outputCount = ctx['outputCount'] ?? '0';
    final biCount = ctx['biCount'] ?? '0';
    final jeongGwanCount = int.tryParse(ctx['jeongGwanCount'] ?? '0') ?? 0;
    final pyeonGwanCount = int.tryParse(ctx['pyeonGwanCount'] ?? '0') ?? 0;
    final strengthVerdict = ctx['strengthVerdict'] ?? '';
    final yongsinElement = ctx['yongsinElement'] ?? '';
    final gisinElement = ctx['gisinElement'] ?? '';
    final dayGanKr = profile.dayPillar.stemKr;
    final dayGanHanja = profile.dayPillar.stemHanja;
    // [신규] 이 Narrative 안에서 "용어 첫 등장 추적"을 위한 tracker.
    // 같은 인스턴스를 whyThisResult/characteristics/practicalGuidance
    // 전체에 걸쳐 재사용해, 동일 용어가 두 번째 등장할 때부터는 축약형만
    // 쓰이도록 한다(§7 용어 반복 금지).
    final terms = TermTracker();

    // ── ① 핵심 결과(coreResult) ──
    final coreResultAll = <String>[
      '$dayGanKr($dayGanHanja) 일간의 이 사주는 $patternName 구조를 갖고 있어요. $patternDesc.',
      if (strengthDesc.isNotEmpty) '여기에 $strengthName의 그릇이 더해져, $strengthDesc.',
    ];
    final coreResult = coreResultAll.take(rules.maxCoreResultSentences).toList();

    // ── ② 왜 이런 결과가 나왔는가(whyThisResult) — coreEvidence를
    // sourceField 기준으로 하나씩 자연어로 풀어낸다(§7 근거 추적성).
    // [명리학 용어 서술 방식 개선] 관살/인성/식상/비겁 같은 5대 그룹
    // 용어와 신강신약 판정어는 [tenGodGroupPhrase]/[strengthPhrase]로
    // 감싸, 이 Narrative 안에서 처음 등장할 때만 "용어(쉬운 의미)" 형태로
    // 풀어 쓰고 재등장 시 축약형만 쓰도록 한다(§7/§8) ──
    final whyThisResult = <String>[];
    for (final e in analysis.coreEvidence) {
      switch (e.sourceField) {
        case 'tenGods+hiddenStems(5대범주 집계)':
          whyThisResult.add(
            '원국과 지장간을 함께 보면 ${tenGodGroupPhrase(terms, '관살')} $officerCount개, '
            '${tenGodGroupPhrase(terms, '인성')} $printerCount개, '
            '${tenGodGroupPhrase(terms, '식상')} $outputCount개, '
            '${tenGodGroupPhrase(terms, '비겁')} $biCount개가 나타나요. '
            '이 숫자들이 $dayGanKr($dayGanHanja) 일간인 이 사주에서 직업 구조를 가르는 1차 근거예요.',
          );
        case 'officerCount/printerCount/outputCount/wealthCount 조합':
          whyThisResult.add(
            '이 조합을 기준으로 판단했을 때 ${tenGodGroupPhrase(terms, '관살')}·'
            '${tenGodGroupPhrase(terms, '인성')}·${tenGodGroupPhrase(terms, '식상')} 중 '
            '어느 쪽 힘이 더 센지가 직업 구조를 가르는 기준이 되고, '
            '이 사주는 그 기준에서 $patternName 쪽으로 기울어요.',
          );
        case 'strength.verdict + 관살 개수':
          whyThisResult.add(
            '${strengthPhrase(terms, strengthVerdict)}으로 판정되는데, '
            '이 힘이 ${tenGodGroupPhrase(terms, '관살')} $officerCount개를 감당하는 정도를 결정해요.',
          );
        case '인성/식상/관살 조합':
          whyThisResult.add(
            '${tenGodGroupPhrase(terms, '인성')} $printerCount개와 '
            '${tenGodGroupPhrase(terms, '식상')} $outputCount개 중 어느 쪽이 우세한지에 따라 '
            '조직에 기대는 방식인지 스스로 만들어가는 방식인지가 갈리는데, $workStyleDesc.',
          );
        case 'dayPillar.stemHanja → career_fit 고정표':
          if (analysis.suitableFields.isNotEmpty) {
            whyThisResult.add(
              '일간이 $dayGanKr($dayGanHanja)이라, 전통적으로 '
              '${analysis.suitableFields.join(', ')} 계열의 기질과 잘 맞는다고 봐요.',
            );
          }
      }
    }
    if (jeongGwanCount > 0 || pyeonGwanCount > 0) {
      final dominantGwan = jeongGwanCount > pyeonGwanCount ? '정관' : '편관';
      final officerFlavor = tenGodMeaningOf(dominantGwan)?.practicalMeaningFor('career') ?? '';
      if (officerFlavor.isNotEmpty) {
        whyThisResult.add(
          '${tenGodPhrase(terms, '정관')} $jeongGwanCount개, ${tenGodPhrase(terms, '편관')} $pyeonGwanCount개 중 '
          '$dominantGwan 쪽이 우세해서, $officerFlavor.',
        );
      }
    }

    // ── ③ 나에게 나타나는 특징(characteristics) — workStyle/suitableFields/
    // careerStrength/관살 우세 여부를 "실제 생활 모습"으로 풀어낸다 ──
    final characteristics = <String>[
      '$workStyleName — $workStyleDesc.',
      if (analysis.suitableFields.isNotEmpty)
        '구체적으로는 ${analysis.suitableFields.take(3).join(', ')} 같은 분야에서 '
            '이 성향이 강점으로 드러나기 쉬워요.',
      _strengthRealLife(strengthName, int.tryParse(officerCount) ?? 0),
      if (jeongGwanCount > 0 && pyeonGwanCount == 0)
        '정관 위주라 정해진 규정과 절차가 뚜렷한 곳에서 오히려 인정받는 편이에요.'
      else if (pyeonGwanCount > 0 && jeongGwanCount == 0)
        '편관 위주라 위기 상황이나 경쟁이 치열한 자리에서 존재감이 두드러지는 편이에요.'
      else if (jeongGwanCount > 0 && pyeonGwanCount > 0)
        '정관과 편관이 섞여 있어, 안정된 조직 생활과 도전적인 역할 사이를 오갈 수 있어요.',
    ].where((s) => s.trim().isNotEmpty).toList();
    final cappedCharacteristics = characteristics.length > rules.maxCharacteristicParagraphs
        ? characteristics.sublist(0, rules.maxCharacteristicParagraphs)
        : characteristics;

    // ── ④ 좋은 흐름(favorableFlows) ──
    final favorableFlows = List<String>.from(analysis.favorableConditions);
    if (favorableFlows.length < rules.minFavorableItems) {
      favorableFlows.add('$patternName 구조 자체를 살릴 수 있는 환경에 놓일 때');
    }
    final cappedFavorable = favorableFlows.length > rules.maxFavorableItems
        ? favorableFlows.sublist(0, rules.maxFavorableItems)
        : favorableFlows;

    // ── ⑤ 주의할 흐름(cautionFlows) ──
    final cautionFlows = List<String>.from(analysis.cautionConditions);
    if (analysis.careerRiskPattern != '두드러진 직업상 리스크 신호는 확인되지 않음' &&
        !cautionFlows.contains(analysis.careerRiskPattern)) {
      cautionFlows.add(analysis.careerRiskPattern);
    }
    if (cautionFlows.length < rules.minCautionItems) {
      cautionFlows.add('$strengthName 상태에서 무리하게 역할을 확장하는 것');
    }
    final cappedCaution = cautionFlows.length > rules.maxCautionItems
        ? cautionFlows.sublist(0, rules.maxCautionItems)
        : cautionFlows;

    // ── ⑥ 실전 가이드(practicalGuidance, 신규 필드) — 용신/기신도 여기서
    // "활용/주의 방법" 관점으로 언급한다 ──
    final practicalGuidance = <String>[
      if (analysis.suitableFields.isNotEmpty)
        '${analysis.suitableFields.take(2).join('·')} 쪽 채용 공고나 프로젝트를 '
            '우선적으로 살펴보는 것이 유리해요.',
      _strengthGuidance(strengthName),
      if (yongsinElement.isNotEmpty)
        '${yongsinPhrase(terms, yongsinElement)}가 활발한 조직·역할을 우선적으로 고려해 보세요.',
      if (gisinElement.isNotEmpty)
        '${gisinPhrase(terms, gisinElement)}가 지나치게 강해지는 업무 환경은 미리 파악해 거리를 두는 것이 좋아요.',
      if (analysis.careerRiskPattern != '두드러진 직업상 리스크 신호는 확인되지 않음')
        '${analysis.careerRiskPattern.split(' / ').first}에 대비해, 중요한 결정 전에 '
            '한 번 더 확인하는 습관을 들이면 좋아요.',
      if (analysis.careerPeakDaewoonLabel.isNotEmpty)
        '${analysis.careerPeakDaewoonLabel}이 오기 전까지는 $workStyleName 방식으로 실력을 '
            '쌓아두는 것이 좋아요.',
    ].where((s) => s.trim().isNotEmpty).toList();

    // ── ⑦ 시기(timingSection) — PHASE4 실계산 대운만 사용(§18) ──
    List<String>? timingSection;
    if (analysis.careerPeakDaewoonLabel.isNotEmpty) {
      timingSection = [
        '${analysis.careerPeakDaewoonLabel} 시기에 직업·명예운이 가장 두드러질 수 있어요.',
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
      '정리하면, 이 사주는 $patternName 구조 속에서 $workStyleName으로 일할 때 '
          '가장 자연스러운 성과를 낼 수 있어요.',
      if (cappedFavorable.isNotEmpty) '특히 ${cappedFavorable.first}은 강점으로 작용해요.',
      if (cappedCaution.isNotEmpty) '다만 ${cappedCaution.first}은 계속 주의가 필요해요.',
      if (analysis.careerPeakDaewoonLabel.isNotEmpty)
        '${analysis.careerPeakDaewoonLabel}이 이 사주의 직업운에서 특히 중요한 시기가 될 수 있어요.',
      if (analysis.confidence == AnalysisConfidence.low)
        '다만 원국에 관살·인성 근거 글자가 뚜렷하지 않아, 이 판단은 참고 정도로 받아들여 주세요.',
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

  /// careerStrength 이름별 "실제 생활에서 나타나는 모습" 부연 문장
  /// (careerStrength 자체 설명과 겹치지 않는 별도 관점 — §5 개인화 강화).
  String _strengthRealLife(String strengthName, int officerCount) {
    if (strengthName.startsWith('신강용관')) {
      return '많은 업무나 사람 관리를 맡아도 쉽게 지치지 않고, 오히려 책임질수록 힘이 나는 편이에요.';
    } else if (strengthName.startsWith('신강경관')) {
      return '위에서 시키는 일보다 스스로 방향을 정할 때 훨씬 능률이 올라가는 편이에요.';
    } else if (strengthName.startsWith('관다신약')) {
      return '맡은 일이 늘어날수록 체력과 컨디션 관리가 함께 중요해지는 편이에요.';
    } else if (strengthName.startsWith('신약보좌')) {
      return '혼자보다 좋은 상사·동료·조직을 만났을 때 실력이 훨씬 크게 드러나는 편이에요.';
    }
    return '상황에 맞춰 업무 강도를 유연하게 조절할 수 있는 편이에요.';
  }

  /// careerStrength 이름별 실전 가이드 한 줄(practicalGuidance 전용,
  /// _strengthRealLife와 다른 "행동 제안" 관점).
  String _strengthGuidance(String strengthName) {
    if (strengthName.startsWith('신강용관')) {
      return '책임 있는 자리나 승진 기회가 오면 피하기보다 적극적으로 맡아보는 것이 유리해요.';
    } else if (strengthName.startsWith('신강경관')) {
      return '지시받는 역할보다 스스로 기획하고 주도할 수 있는 자리를 찾아보는 것이 좋아요.';
    } else if (strengthName.startsWith('관다신약')) {
      return '업무량을 조절할 수 있는 환경인지 미리 확인하고, 휴식 계획도 함께 세워두는 것이 좋아요.';
    } else if (strengthName.startsWith('신약보좌')) {
      return '믿을 수 있는 상사나 동료가 있는 조직을 고르는 것이 혼자 애쓰는 것보다 나아요.';
    }
    return '지금 맡은 역할의 강도를 스스로 점검하며 완급을 조절하는 것이 좋아요.';
  }
}
