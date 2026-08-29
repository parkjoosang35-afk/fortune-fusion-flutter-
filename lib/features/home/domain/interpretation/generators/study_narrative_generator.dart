/// [정통사주 69종 개인화 해석 엔진 — A09 독립 파이프라인] 평생
/// 학업·시험운 Narrative Generator.
///
/// [A01/A03~A08과 동일한 구조로 신규 구현] 이 클래스는 어떤 판단도 새로
/// 하지 않는다. [StudyAnalyzer]가 이미 끝낸 판단([StudyAnalysis]의
/// studyPattern/studyBondStrength/munchangPositionCondition/
/// studyRiskPattern/studyApproach/studyPeakDaewoonLabel 및 coreEvidence/
/// supportingEvidence)을 입력으로 받아, 그 근거들을
/// term_translation_layer의 4단계 변환을 참고해 사람이 읽는 한국어 문장으로
/// "표현"만 한다.
///
/// [절대 원칙 — §9 금지 문구] "사주 뿌리부터", "오행의 흐름을 보면",
/// "여기에 더해", "사주는 정해진 운명" 같은, 어떤 카테고리에도 붙일 수 있는
/// 범용 문구는 사용하지 않는다. 모든 문장은 [StudyAnalysis]의 실제 필드값
/// (studyPattern 이름, 인성 개수, 문창귀인 위치, 일간, 대운 라벨 등)이
/// 문장 안에 구체적으로 드러나야 한다 — 같은 studyPattern이라도
/// interpretationContext 수치가 다르면 문장의 구체적 근거 설명이 달라진다.
///
/// [명리학 용어 서술 방식 — A01/A03~A08과 동일 원칙 처음부터 적용]
/// 인성 5대 그룹 용어, 신강신약, 학업 관련 신살(문창귀인·역마·공망·겁살·
/// 재살) 같은 명리학 전문용어는 삭제하지 않고 그대로 유지하되, 이
/// Narrative 안에서 처음 등장할 때만 term_translation_layer.dart의
/// [TermTracker]/tenGodGroupPhrase/strengthPhrase/sinsalPhrase/
/// yongsinPhrase 헬퍼로 "용어(쉬운 의미)"를 함께 풀어 쓰고, 같은 용어가
/// 다시 등장하면 축약형만 사용한다(§7 용어 반복 금지). 계산/개인화 로직
/// 자체는 전혀 바뀌지 않는다 — [StudyAnalysis]가 이미 내린 판단을 "어떻게
/// 설명하는가"만 바뀐다.
///
/// [A09 고유 특징] munchangPositionCondition(문창귀인이 걸린 자리와 그
/// 자리가 상징하는 인생 시기)은 다른 카테고리가 쓰지 않는 A09만의
/// 근거이므로, characteristics 단계에서 반드시 별도 문장으로 풀어낸다.
library;

import '../../manseryeok/saju_profile.dart';
import '../analysis_evidence.dart';
import '../analyzers/study_analysis.dart';
import '../fortune_narrative.dart';
import '../interpretation_rules.dart';
import '../narrative_generator.dart';
import '../term_translation_layer.dart';

class StudyNarrativeGenerator implements NarrativeGenerator<StudyAnalysis> {
  const StudyNarrativeGenerator();

  /// 'A — B' 형식으로 저장된 studyPattern/studyBondStrength 문자열을
  /// (이름, 설명)으로 분리한다. ' — '가 없으면 전체를 이름으로 취급한다
  /// (방어적 처리, health/career/wealth/love/children/parents_siblings
  /// Generator와 동일 유틸).
  (String name, String desc) _split(String labeled) {
    final idx = labeled.indexOf(' — ');
    if (idx == -1) return (labeled, '');
    return (labeled.substring(0, idx), labeled.substring(idx + 3));
  }

  @override
  FortuneNarrative generate(
    SajuProfile profile,
    StudyAnalysis analysis, {
    InterpretationRules rules = InterpretationRules.standard,
  }) {
    final ctx = analysis.interpretationContext;
    final (patternName, patternDesc) = _split(analysis.studyPattern);
    final (bondName, bondDesc) = _split(analysis.studyBondStrength);

    final studyGodCount = int.tryParse(ctx['studyGodCount'] ?? '0') ?? 0;
    final hasMunchang = ctx['hasMunchang'] == 'true';
    final strengthVerdict = ctx['strengthVerdict'] ?? '';
    final yongsinElement = ctx['yongsinElement'] ?? '';
    final foundStudyRiskSinsal = (ctx['foundStudyRiskSinsal'] ?? '')
        .split(',')
        .where((s) => s.trim().isNotEmpty)
        .toList();
    final yeokmaPositions = (ctx['yeokmaPositions'] ?? '')
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
    // [명리학 용어 서술 방식 개선] 인성 그룹 용어와 신강신약 판정어,
    // 문창귀인은 각각 tenGodGroupPhrase/strengthPhrase/sinsalPhrase로
    // 감싸, 이 Narrative 안에서 처음 등장할 때만 "용어(쉬운 의미)" 형태로
    // 풀어 쓰고 재등장 시 축약형만 쓴다(§7/§8) ──
    final whyThisResult = <String>[];
    for (final e in analysis.coreEvidence) {
      switch (e.sourceField) {
        case 'tenGods+hiddenStems(5대범주 집계) + sinsal(문창귀인)':
          whyThisResult.add(
            '원국과 지장간을 함께 보면 학업을 상징하는 '
            '${tenGodGroupPhrase(terms, '인성')} $studyGodCount개가 나타나고, '
            '${hasMunchang ? sinsalPhrase(terms, '문창귀인') : '문창귀인은 나타나지 않아요'}.',
          );
        case 'studyGodCount(인성 개수) + hasMunchang(문창귀인 보유)':
          whyThisResult.add(
            '${tenGodGroupPhrase(terms, '인성')} 개수와 문창귀인 보유 여부를 조합해 판단했을 때, '
            '이 사주는 $patternName 쪽으로 기울어요.',
          );
        case 'strength.verdict + 인성 개수':
          whyThisResult.add(
            '${strengthPhrase(terms, strengthVerdict)}으로 판정되는데, '
            '이 힘이 ${tenGodGroupPhrase(terms, '인성')} $studyGodCount개를 받아들이는 방식을 결정해요.',
          );
        case 'sinsal(문창귀인 위치, PHASE2 실계산)':
          whyThisResult.add(
            '문창귀인의 위치를 보면 ${analysis.munchangPositionCondition}.',
          );
        case '신살(문창귀인 위치 공망/겁살/재살) + 인성·문창귀인 부재 조합':
          if (foundStudyRiskSinsal.isNotEmpty) {
            final phrases = foundStudyRiskSinsal
                .map((s) => sinsalPhrase(terms, s))
                .join(' ');
            whyThisResult.add(phrases);
          }
          if (studyGodCount == 0 && !hasMunchang) {
            whyThisResult.add(
              '${tenGodGroupPhrase(terms, '인성')}도 문창귀인도 원국에 나타나지 않는 부분이 있어, ${analysis.studyRiskPattern}.',
            );
          }
        case 'daewoon(PHASE4 실계산)':
          whyThisResult.add('${analysis.studyPeakDaewoonLabel} 시기가 대운에서 확인돼요.');
      }
    }

    // ── ③ 나에게 나타나는 특징(characteristics) — 문창귀인 위치(A09
    // 고유 근거)/studyApproach/역마·리스크 신살을 "실제 생활 모습"으로
    // 풀어낸다 ──
    final characteristics = <String>[
      '문창귀인 위치 상태는 ${analysis.munchangPositionCondition}.',
      _bondRealLife(bondName),
      '공부와 시험을 대할 때는 ${analysis.studyApproach}.',
      if (yeokmaPositions.isNotEmpty)
        '${sinsalPhrase(terms, '역마살')}도 함께 있어, 익숙한 환경보다 새로운 곳에서 배울 때 오히려 학업 성과가 더 좋을 수 있어요.',
      if (foundStudyRiskSinsal.isNotEmpty)
        '문창귀인 자리에 ${foundStudyRiskSinsal.join(', ')} 기운이 있어, 시험·발표 시기에 평소보다 신중함이 필요한 편이에요.',
    ].where((s) => s.trim().isNotEmpty).toList();
    final cappedCharacteristics =
        characteristics.length > rules.maxCharacteristicParagraphs
        ? characteristics.sublist(0, rules.maxCharacteristicParagraphs)
        : characteristics;

    // ── ④ 좋은 흐름(favorableFlows) ──
    final favorableFlows = List<String>.from(analysis.favorableConditions);
    if (favorableFlows.length < rules.minFavorableItems) {
      favorableFlows.add('$patternName 구조 자체를 안정적으로 살릴 수 있는 학습 환경');
    }
    final cappedFavorable = favorableFlows.length > rules.maxFavorableItems
        ? favorableFlows.sublist(0, rules.maxFavorableItems)
        : favorableFlows;

    // ── ⑤ 주의할 흐름(cautionFlows) ──
    final cautionFlows = List<String>.from(analysis.cautionConditions);
    if (analysis.studyRiskPattern != '두드러진 학업·시험운 리스크 신호는 확인되지 않음' &&
        !cautionFlows.contains(analysis.studyRiskPattern)) {
      cautionFlows.add(analysis.studyRiskPattern);
    }
    if (cautionFlows.length < rules.minCautionItems) {
      cautionFlows.add('$bondName 상태에서 학업 계획을 소홀히 세우는 것');
    }
    final cappedCaution = cautionFlows.length > rules.maxCautionItems
        ? cautionFlows.sublist(0, rules.maxCautionItems)
        : cautionFlows;

    // ── ⑥ 실전 가이드(practicalGuidance, 신규 필드) ──
    final practicalGuidance = <String>[
      '${analysis.studyApproach.split('편').first.trim()} 편으로 공부 계획을 세워보세요.',
      if (yongsinElement.isNotEmpty)
        '${yongsinPhrase(terms, yongsinElement)}이 강해지는 시기에 중요한 시험·자격증 도전을 계획해 보세요.',
      if (foundStudyRiskSinsal.isNotEmpty)
        '문창귀인 자리의 ${foundStudyRiskSinsal.join(', ')} 신호에 따라 시험 일정을 여유 있게 잡아보세요.',
      if (analysis.munchangPositionCondition.startsWith('문창귀인 미발동'))
        '결정적인 시험운보다 꾸준한 누적 학습이 성과로 이어지는 만큼, 장기 계획을 세워 흐트러지지 않게 이어가면 좋아요.',
      if (analysis.studyPeakDaewoonLabel.isNotEmpty)
        '${analysis.studyPeakDaewoonLabel}이 오기 전까지는 $patternName 구조에 맞는 학습 기초를 다져두는 것이 좋아요.',
    ].where((s) => s.trim().isNotEmpty).toList();

    // ── ⑦ 시기(timingSection) — PHASE4 실계산 대운만 사용(§18) ──
    List<String>? timingSection;
    if (analysis.studyPeakDaewoonLabel.isNotEmpty) {
      timingSection = [
        '${analysis.studyPeakDaewoonLabel} 시기에 학업·시험 성과가 가장 활발해질 수 있어요.',
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
      '정리하면, 이 사주는 $patternName 구조 속에서 $bondName 방식일 때 가장 자연스러운 학업 성과를 만들 수 있어요.',
      if (cappedFavorable.isNotEmpty) '특히 ${cappedFavorable.first}은 강점으로 작용해요.',
      if (cappedCaution.isNotEmpty) '다만 ${cappedCaution.first}은 계속 주의가 필요해요.',
      if (analysis.studyPeakDaewoonLabel.isNotEmpty)
        '${analysis.studyPeakDaewoonLabel}이 이 사주의 학업·시험운에서 특히 중요한 시기가 될 수 있어요.',
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

  /// studyBondStrength 이름별 "실제 생활에서 나타나는 모습" 부연 문장
  /// (studyBondStrength 자체 설명과 겹치지 않는 별도 관점 — §5 개인화
  /// 강화).
  String _bondRealLife(String bondName) {
    if (bondName.startsWith('신강왕인')) {
      return '한 번 목표를 정하면 끝까지 파고들어 성과를 만들어내는 편이에요.';
    } else if (bondName.startsWith('신강자학')) {
      return '학원이나 과외보다 스스로 자료를 찾아 계획을 세우는 쪽이 더 잘 맞는 편이에요.';
    } else if (bondName.startsWith('신약의학')) {
      return '좋은 선생님이나 스터디 그룹을 만났을 때 유독 성적이 오르는 편이에요.';
    } else if (bondName.startsWith('신약분산')) {
      return '긴 시간 한 과목만 붙잡고 있으면 오히려 지치기 쉬워, 여러 과목을 짧게 번갈아 공부하는 편이 잘 맞아요.';
    }
    return '상황에 맞춰 공부 강도와 방식을 유연하게 조절할 수 있는 편이에요.';
  }
}
