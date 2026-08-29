/// [정통사주 69종 개인화 해석 엔진 — A05 독립 파이프라인] 평생 건강운
/// Narrative Generator.
///
/// [A01/A03/A04와 동일한 구조로 신규 구현] 이 클래스는 어떤 판단도 새로
/// 하지 않는다. [HealthAnalyzer]가 이미 끝낸 판단([HealthAnalysis]의
/// healthConstitutionPattern/healthVitality/vulnerableOrgans/
/// healthRiskPattern/recommendedCare/healthCautionDaewoonLabel 및
/// coreEvidence/supportingEvidence)을 입력으로 받아, 그 근거들을
/// term_translation_layer의 4단계 변환을 참고해 사람이 읽는 한국어 문장으로
/// "표현"만 한다.
///
/// [절대 원칙 — §9 금지 문구] "사주 뿌리부터", "오행의 흐름을 보면",
/// "여기에 더해", "사주는 정해진 운명" 같은, 어떤 카테고리에도 붙일 수 있는
/// 범용 문구는 사용하지 않는다. 모든 문장은 [HealthAnalysis]의 실제 필드값
/// (healthConstitutionPattern 이름, 과다/부족 오행, 취약 장기, 신살, 대운
/// 라벨 등)이 문장 안에 구체적으로 드러나야 한다 — 같은
/// healthConstitutionPattern이라도 interpretationContext 수치가 다르면
/// 문장의 구체적 근거 설명이 달라진다.
///
/// [명리학 용어 서술 방식 — A01/A03/A04와 동일 원칙 처음부터 적용]
/// 신강신약/용신·기신/건강 관련 신살(양인살·백호대살·육해살·겁살) 같은
/// 명리학 전문용어는 삭제하지 않고 그대로 유지하되, 이 Narrative 안에서
/// 처음 등장할 때만 term_translation_layer.dart의 [TermTracker]/
/// strengthPhrase/yongsinPhrase/gisinPhrase/sinsalPhrase 헬퍼로
/// "용어(쉬운 의미)"를 함께 풀어 쓰고, 같은 용어가 다시 등장하면 축약형만
/// 사용한다(§7 용어 반복 금지). 계산/개인화 로직 자체는 전혀 바뀌지 않는다.
///
/// [건강 카테고리 특이사항] 이 Narrative는 의학적 진단이 아니라 전통
/// 명리학 관점의 체질 경향 참고 정보임을 finalSummary에서 항상 명시한다
/// (`DisclaimerTag.medical` 고지와 별개로, 문장 자체에도 오해를 막기 위한
/// 안내를 남긴다 — 기존 g_group_modules.dart/jeontong_narrative_interpreter
/// .dart의 건강 카테고리 표현 원칙과 동일).
library;

import '../../manseryeok/saju_profile.dart';
import '../analysis_evidence.dart';
import '../analyzers/health_analysis.dart';
import '../fortune_narrative.dart';
import '../interpretation_rules.dart';
import '../narrative_generator.dart';
import '../term_translation_layer.dart';

class HealthNarrativeGenerator implements NarrativeGenerator<HealthAnalysis> {
  const HealthNarrativeGenerator();

  /// 'A — B' 형식으로 저장된 healthConstitutionPattern/healthVitality
  /// 문자열을 (이름, 설명)으로 분리한다. ' — '가 없으면 전체를 이름으로
  /// 취급한다(방어적 처리, career/wealth Generator와 동일 유틸).
  (String name, String desc) _split(String labeled) {
    final idx = labeled.indexOf(' — ');
    if (idx == -1) return (labeled, '');
    return (labeled.substring(0, idx), labeled.substring(idx + 3));
  }

  @override
  FortuneNarrative generate(
    SajuProfile profile,
    HealthAnalysis analysis, {
    InterpretationRules rules = InterpretationRules.standard,
  }) {
    final ctx = analysis.interpretationContext;
    final (patternName, patternDesc) = _split(
      analysis.healthConstitutionPattern,
    );
    final (vitalityName, vitalityDesc) = _split(analysis.healthVitality);

    final dominantElements = (ctx['dominantElements'] ?? '')
        .split(',')
        .where((s) => s.trim().isNotEmpty)
        .toList();
    final deficientElements = (ctx['deficientElements'] ?? '')
        .split(',')
        .where((s) => s.trim().isNotEmpty)
        .toList();
    final strengthVerdict = ctx['strengthVerdict'] ?? '';
    final yongsinElement = ctx['yongsinElement'] ?? '';
    final gisinElement = ctx['gisinElement'] ?? '';
    final gisinCount = int.tryParse(ctx['gisinCount'] ?? '0') ?? 0;
    final foundHealthSinsal = (ctx['foundHealthSinsal'] ?? '')
        .split(',')
        .where((s) => s.trim().isNotEmpty)
        .toList();
    final dayGanKr = profile.dayPillar.stemKr;
    final dayGanHanja = profile.dayPillar.stemHanja;
    // [신규] 이 Narrative 생성 과정 전체에서 공유하는 용어 추적기(§7).
    final terms = TermTracker();

    // ── ① 핵심 결과(coreResult) ──
    final coreResultAll = <String>[
      '$dayGanKr($dayGanHanja) 일간의 이 사주는 $patternName 체질을 갖고 있어요. $patternDesc.',
      if (vitalityDesc.isNotEmpty) '여기에 $vitalityName 상태가 더해져, $vitalityDesc.',
    ];
    final coreResult = coreResultAll
        .take(rules.maxCoreResultSentences)
        .toList();

    // ── ② 왜 이런 결과가 나왔는가(whyThisResult) — coreEvidence를
    // sourceField 기준으로 하나씩 자연어로 풀어낸다(§7 근거 추적성).
    // [명리학 용어 서술 방식 개선] 신강신약/신살/기신 용어는 각각
    // strengthPhrase/sinsalPhrase/gisinPhrase로 감싸, 이 Narrative 안에서
    // 처음 등장할 때만 "용어(쉬운 의미)" 형태로 풀어 쓰고 재등장 시
    // 축약형만 쓴다(§7/§8) ──
    final whyThisResult = <String>[];
    for (final e in analysis.coreEvidence) {
      switch (e.sourceField) {
        case 'fiveElements.dominant/deficient/isImbalanced':
          whyThisResult.add(
            '원국 8글자를 보면 과다한 기운은 '
            '${dominantElements.isEmpty ? '따로 없고' : '${dominantElements.join(', ')}이고'}, '
            '부족한 기운은 ${deficientElements.isEmpty ? '따로 없어요' : '${deficientElements.join(', ')}예요'}.',
          );
        case 'dominantElements.length/deficientElements.length 조합':
          whyThisResult.add('이 과다·부족 오행의 조합을 종합하면 $patternName 구조로 판정돼요.');
        case 'strength.verdict + fiveElements.isImbalanced':
          whyThisResult.add(
            '${strengthPhrase(terms, strengthVerdict)}으로 판정되는데, '
            '오행 편중 여부와 함께 봤을 때 $vitalityName 상태로 나타나요.',
          );
        case 'dominant/deficient → organ 고정표(five_elements_rules.json)':
          if (analysis.vulnerableOrgans.isNotEmpty) {
            whyThisResult.add(
              '과다·부족 오행을 장기 계통에 대응해 보면, 체질상 특히 '
              '${analysis.vulnerableOrgans.join(', ')} 계통을 눈여겨봐야 해요.',
            );
          }
        case '건강신살 + 기신오행강도 + 오행편중 조합':
          if (foundHealthSinsal.isNotEmpty) {
            final phrases = foundHealthSinsal
                .map((s) => sinsalPhrase(terms, s))
                .join(' ');
            whyThisResult.add(phrases);
          }
          if (gisinElement.isNotEmpty && gisinCount >= 2) {
            whyThisResult.add(
              '${gisinPhrase(terms, gisinElement)}이 원국에 $gisinCount개나 있어, '
              '관련 계통에 부담이 쌓이기 쉬운 편이에요.',
            );
          }
        case '부족오행(우선) 또는 일간오행 → food_good 고정표(five_elements_rules.json)':
          if (analysis.recommendedCare.isNotEmpty) {
            whyThisResult.add(
              '이를 보완하기 위해 ${analysis.recommendedCare.join(', ')} 등을 챙기면 도움이 돼요.',
            );
          }
      }
    }

    // ── ③ 나에게 나타나는 특징(characteristics) — healthVitality/
    // vulnerableOrgans/foundHealthSinsal을 "실제 생활 모습"으로 풀어낸다 ──
    final characteristics = <String>[
      _vitalityRealLife(vitalityName),
      if (analysis.vulnerableOrgans.isNotEmpty)
        '${analysis.vulnerableOrgans.take(3).join(', ')} 계통에 신경 쓰면 컨디션 관리가 한층 편해지는 편이에요.',
      if (dominantElements.length >= 2)
        '${dominantElements.join(', ')} 기운이 겹쳐 있어, 특정 계통에 부담이 쏠리기 쉬운 편이에요.',
      if (foundHealthSinsal.isNotEmpty)
        '${foundHealthSinsal.join(', ')} 기운이 있어, 평소보다 사고·수술·만성질환 예방에 더 신경 쓰는 편이 좋아요.',
    ].where((s) => s.trim().isNotEmpty).toList();
    final cappedCharacteristics =
        characteristics.length > rules.maxCharacteristicParagraphs
        ? characteristics.sublist(0, rules.maxCharacteristicParagraphs)
        : characteristics;

    // ── ④ 좋은 흐름(favorableFlows) ──
    final favorableFlows = List<String>.from(analysis.favorableConditions);
    if (favorableFlows.length < rules.minFavorableItems) {
      favorableFlows.add('$patternName 체질 자체를 안정적으로 유지할 수 있는 생활 습관');
    }
    final cappedFavorable = favorableFlows.length > rules.maxFavorableItems
        ? favorableFlows.sublist(0, rules.maxFavorableItems)
        : favorableFlows;

    // ── ⑤ 주의할 흐름(cautionFlows) ──
    final cautionFlows = List<String>.from(analysis.cautionConditions);
    if (analysis.healthRiskPattern != '두드러진 건강상 리스크 신호는 확인되지 않음' &&
        !cautionFlows.contains(analysis.healthRiskPattern)) {
      cautionFlows.add(analysis.healthRiskPattern);
    }
    if (cautionFlows.length < rules.minCautionItems) {
      cautionFlows.add('$vitalityName 상태에서 무리하게 컨디션을 소진하는 것');
    }
    final cappedCaution = cautionFlows.length > rules.maxCautionItems
        ? cautionFlows.sublist(0, rules.maxCautionItems)
        : cautionFlows;

    // ── ⑥ 실전 가이드(practicalGuidance, 신규 필드) — 보양법/용신·기신도
    // 여기서 "활용/주의 방법" 관점으로 언급한다 ──
    final practicalGuidance = <String>[
      if (analysis.recommendedCare.isNotEmpty)
        '${analysis.recommendedCare.take(3).join(', ')} 등을 식단에 챙겨보세요.',
      if (yongsinElement.isNotEmpty)
        '${yongsinPhrase(terms, yongsinElement)}가 살아나는 환경·습관을 의식적으로 가까이해 보세요.',
      if (gisinElement.isNotEmpty)
        '${gisinPhrase(terms, gisinElement)}가 지나치게 강해지는 시기·환경은 미리 알아채고 컨디션 관리를 더 신경 써보세요.',
      if (foundHealthSinsal.isNotEmpty)
        '${foundHealthSinsal.join(', ')} 신호에 따른 정기 건강검진과 사고 예방 습관을 챙기면 좋아요.',
      if (analysis.healthCautionDaewoonLabel.isNotEmpty)
        '${analysis.healthCautionDaewoonLabel}이 오기 전까지 기초 체력과 면역력을 다져두는 것이 좋아요.',
    ].where((s) => s.trim().isNotEmpty).toList();

    // ── ⑦ 시기(timingSection) — PHASE4 실계산 대운만 사용(§18) ──
    List<String>? timingSection;
    if (analysis.healthCautionDaewoonLabel.isNotEmpty) {
      timingSection = [
        '${analysis.healthCautionDaewoonLabel} 시기에 건강 관리에 특히 유의할 필요가 있어요.',
      ];
      final currentDaewoonEvidence = analysis.supportingEvidence
          .where((e) => e.sourceField == 'currentDaewoon(PHASE4 실계산)')
          .toList();
      if (currentDaewoonEvidence.isNotEmpty) {
        timingSection.add(currentDaewoonEvidence.first.judgment);
      }
    }

    // ── ⑧ 최종 정리(finalSummary) — 건강 카테고리는 항상 "의학적 진단이
    // 아니다"라는 안내를 포함한다(§ 건강 카테고리 표현 원칙) ──
    final finalSummaryAll = <String>[
      '정리하면, 이 사주는 $patternName 체질 속에서 $vitalityName 상태를 타고났어요.',
      if (cappedFavorable.isNotEmpty) '특히 ${cappedFavorable.first}은 강점으로 작용해요.',
      if (cappedCaution.isNotEmpty) '다만 ${cappedCaution.first}은 계속 주의가 필요해요.',
      if (analysis.healthCautionDaewoonLabel.isNotEmpty)
        '${analysis.healthCautionDaewoonLabel}이 이 사주의 건강 관리에서 특히 중요한 시기가 될 수 있어요.',
      '이 내용은 의학적 진단이 아니라, 사주 명리학 관점에서 풀어낸 체질 경향 참고 정보예요.',
      if (analysis.confidence == AnalysisConfidence.low)
        '다만 오행·신강신약 근거가 뚜렷하지 않아, 이 판단은 참고 정도로 받아들여 주세요.',
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

  /// healthVitality 이름별 "실제 생활에서 나타나는 모습" 부연 문장
  /// (healthVitality 자체 설명과 겹치지 않는 별도 관점 — §5 개인화 강화).
  String _vitalityRealLife(String vitalityName) {
    if (vitalityName.startsWith('신강균형')) {
      return '체력 소모가 큰 일정도 비교적 잘 견디고, 회복도 빠른 편이에요.';
    } else if (vitalityName.startsWith('신강편중')) {
      return '평소엔 힘이 넘치지만, 한쪽으로 몰아서 쓰다 보면 그 계통에만 유난히 무리가 가는 편이에요.';
    } else if (vitalityName.startsWith('신약편중')) {
      return '체력을 아껴 써야 하는 데다 특정 계통이 함께 약해서, 꾸준한 관리가 특히 중요한 편이에요.';
    } else if (vitalityName.startsWith('신약보양')) {
      return '무리해서 밀어붙이기보다, 충분히 쉬고 채워줄 때 컨디션이 훨씬 안정되는 편이에요.';
    }
    return '큰 치우침 없이, 생활 습관에 따라 컨디션이 유연하게 오르내리는 편이에요.';
  }
}
