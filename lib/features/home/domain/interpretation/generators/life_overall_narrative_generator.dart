/// [정통사주 69종 개인화 해석 엔진 — A01 독립 파이프라인] 평생 총운
/// Narrative Generator.
///
/// [A04(CareerNarrativeGenerator)와 동일한 구조로 통일 — 분기점 A 승인]
/// 이 클래스는 어떤 판단도 새로 하지 않는다. [LifeOverallAnalyzer]가 이미
/// 끝낸 판단([LifeOverallAnalysis]의 dominantTenGodCategory/lifeTheme/
/// coreNatureDescription/notableSinsal/dominantElements/deficientElements/
/// strengthVerdict/yongsinElement/gisinElement/strengths/weaknesses 및
/// coreEvidence)을 입력으로 받아, 그 근거들을 term_translation_layer의
/// 4단계 변환을 참고해 사람이 읽는 한국어 문장으로 "표현"만 한다.
///
/// [절대 원칙 — §9 금지 문구] "사주 뿌리부터", "오행의 흐름을 보면",
/// "여기에 더해", "사주는 정해진 운명" 같은, 어떤 카테고리에도 붙일 수 있는
/// 범용 문구는 사용하지 않는다. 모든 문장은 [LifeOverallAnalysis]의 실제
/// 필드값(dominantTenGodCategory, 일간, 오행 과다/부족, 신살 등)이 문장
/// 안에 구체적으로 드러나야 한다.
///
/// [A01 특이사항] A01은 "평생" 관점이라 세운/월운/대운을 다루지 않는다
/// (analyzer의 §10 excludedData). 따라서 이 Generator가 만드는
/// [FortuneNarrative.timingSection]은 항상 null이다 — 이것은 버그가 아니라
/// §18 "가짜 시기 금지" 원칙의 정상 동작이다.
///
/// [2026-08-2x 확장 — "정통사주 결과 해석 방식 최종 수정 지시"] 명리학
/// 전문용어(십신 5대 그룹/신강신약/용신·기신/신살)는 삭제하지 않고
/// 그대로 유지하되, 이 Narrative 안에서 처음 등장할 때만
/// term_translation_layer.dart의 [TermTracker]/tenGodGroupPhrase/
/// strengthPhrase/yongsinPhrase/gisinPhrase/sinsalPhrase 헬퍼로
/// "용어(쉬운 의미)"를 함께 풀어 쓰고, 같은 용어가 다시 등장하면
/// 축약형만 사용한다(§7 용어 반복 금지). 계산/개인화 로직 자체는 전혀
/// 바뀌지 않는다 — [LifeOverallAnalysis]가 이미 내린 판단을 "어떻게
/// 설명하는가"만 바뀌다.
library;

import '../../manseryeok/saju_profile.dart';
import '../analysis_evidence.dart';
import '../analyzers/life_overall_analysis.dart';
import '../fortune_narrative.dart';
import '../interpretation_rules.dart';
import '../narrative_generator.dart';
import '../term_translation_layer.dart';

/// 이 파일이 사용하는 십신 5대 그룹명 집합(dominantTenGodCategory가
/// '균형'이 아니면 반드시 이 중 하나) — [tenGodGroupPhrase] 호출
/// 대상 여부를 판단하기 위한 방어적 상수.
const Set<String> _tenGodGroupNames = {'비겁', '식상', '재성', '관살', '인성'};

class LifeOverallNarrativeGenerator
    implements NarrativeGenerator<LifeOverallAnalysis> {
  const LifeOverallNarrativeGenerator();

  @override
  FortuneNarrative generate(
    SajuProfile profile,
    LifeOverallAnalysis analysis, {
    InterpretationRules rules = InterpretationRules.standard,
  }) {
    final ctx = analysis.interpretationContext;
    final dominantCategory = analysis.dominantTenGodCategory;
    final categoryCount = ctx['categoryCount'] ?? '';
    final dominantCount = ctx['dominantCount'] ?? '0';
    final strengthVerdict = analysis.strengthVerdict;
    final yongsinElement = analysis.yongsinElement;
    final gisinElement = analysis.gisinElement;
    final dayGanKr = profile.dayPillar.stemKr;
    final dayGanHanja = profile.dayPillar.stemHanja;
    // [신규] 이 Narrative 생성 과정 전체에서 공유하는 용어 추적기(§7).
    final terms = TermTracker();
    // dominantCategory가 십신 5대 그룹(비겁/식상/재성/관살/인성) 중 하나이므로
    // 문장 안에서 이 값을 사용할 때는 항상 tenGodGroupPhrase를 거친다.
    String dominantCategoryPhrase() =>
        _tenGodGroupNames.contains(dominantCategory)
        ? tenGodGroupPhrase(terms, dominantCategory)
        : dominantCategory;

    // ── ① 핵심 결과(coreResult) ──
    final coreResultAll = <String>[
      '$dayGanKr($dayGanHanja) 일간의 이 사주는 ${analysis.lifeTheme}.',
      if (dominantCategory != '균형')
        '특히 ${dominantCategoryPhrase()} 기운이 원국·지장간 전체에서 $dominantCount회로 가장 많이 반복돼요.',
    ];
    final coreResult = coreResultAll
        .take(rules.maxCoreResultSentences)
        .toList();

    // ── ② 왜 이런 결과가 나왔는가(whyThisResult) — coreEvidence를
    // sourceField 기준으로 하나씩 자연어로 풀어낸다(§7 근거 추적성).
    // [명리학 용어 서술 방식 개선] 십신 5대 그룹/신강신약/용신·기신/신살
    // 용어는 각각 tenGodGroupPhrase/strengthPhrase/yongsinPhrase/
    // gisinPhrase/sinsalPhrase로 감싸, 이 Narrative 안에서 처음 등장할
    // 때만 "용어(쉬운 의미)"로 풀어 쓰고 재등장 시 축약형만 쓴다(§7/§8) ──
    final whyThisResult = <String>[];
    for (final e in analysis.coreEvidence) {
      switch (e.sourceField) {
        case 'dayPillar.stemHanja':
          whyThisResult.add(
            '일간이 $dayGanKr($dayGanHanja)이라서, ${analysis.coreNatureDescription}는 기질을 타고났어요.',
          );
        case 'tenGods + hiddenStems(십신 7위치+지장간)':
          whyThisResult.add(
            '원국과 지장간을 종합하면 $categoryCount 분포가 나타나고, '
            '그중 ${dominantCategoryPhrase()} 기운이 가장 많이 반복돼요.',
          );
        case 'strength.verdict/score':
          whyThisResult.add(
            '${strengthPhrase(terms, strengthVerdict)}으로 판정돼요.',
          );
        case 'yongsin.yongsin/gisin':
          if (yongsinElement.isNotEmpty) {
            whyThisResult.add(
              '${yongsinPhrase(terms, yongsinElement)}, ${gisinPhrase(terms, gisinElement)}로 판정되어, '
              '$yongsinElement 기운이 살아날 때 삶이 편해지고 $gisinElement 기운이 강해질 때 힘들어져요.',
            );
          }
        case 'fiveElements.dominant/deficient':
          if (analysis.dominantElements.isNotEmpty ||
              analysis.deficientElements.isNotEmpty) {
            whyThisResult.add(
              analysis.dominantElements.isNotEmpty &&
                      analysis.deficientElements.isNotEmpty
                  ? '오행을 보면 ${analysis.dominantElements.join(', ')} 기운은 넘치고 '
                        '${analysis.deficientElements.join(', ')} 기운은 부족한 편중 구조예요.'
                  : analysis.dominantElements.isNotEmpty
                  ? '오행을 보면 ${analysis.dominantElements.join(', ')} 기운이 두드러지게 강한 구조예요.'
                  : '오행을 보면 ${analysis.deficientElements.join(', ')} 기운이 원국에 없는 구조예요.',
            );
          }
        case 'sinsal':
          if (analysis.notableSinsal.isNotEmpty) {
            final phrases = analysis.notableSinsal
                .map((s) => sinsalPhrase(terms, s))
                .join(' ');
            whyThisResult.add('원국에 $phrases 이 기운이 평생에 걸쳐 특이하게 작용해요.');
          }
      }
    }

    // ── ③ 나에게 나타나는 특징(characteristics) — strengths/weaknesses를
    // "실제 생활 모습"으로 풀어낸다 ──
    final characteristics = <String>[
      for (final s in analysis.strengths)
        '${dominantCategoryPhrase()} 기운과 관련해, $s.',
      if (analysis.dominantElements.length >= 2)
        '${analysis.dominantElements.join(', ')} 기운이 겹쳐 있어, 특정 방향으로 힘이 몰리는 편이에요.',
    ].where((s) => s.trim().isNotEmpty).toList();
    final cappedCharacteristics =
        characteristics.length > rules.maxCharacteristicParagraphs
        ? characteristics.sublist(0, rules.maxCharacteristicParagraphs)
        : characteristics;

    // ── ④ 좋은 흐름(favorableFlows) ──
    final favorableFlows = List<String>.from(analysis.favorableConditions);
    if (favorableFlows.length < rules.minFavorableItems) {
      favorableFlows.add('$dominantCategory 기운의 본래 색깔을 그대로 드러낼 수 있는 환경');
    }
    final cappedFavorable = favorableFlows.length > rules.maxFavorableItems
        ? favorableFlows.sublist(0, rules.maxFavorableItems)
        : favorableFlows;

    // ── ⑤ 주의할 흐름(cautionFlows) ──
    final cautionFlows = List<String>.from(analysis.cautionConditions);
    for (final w in analysis.weaknesses) {
      if (cautionFlows.length >= rules.maxCautionItems) break;
      if (!cautionFlows.contains(w)) cautionFlows.add(w);
    }
    if (cautionFlows.length < rules.minCautionItems) {
      cautionFlows.add('$strengthVerdict 상태에서 스스로를 지나치게 몰아붙이는 것');
    }
    final cappedCaution = cautionFlows.length > rules.maxCautionItems
        ? cautionFlows.sublist(0, rules.maxCautionItems)
        : cautionFlows;

    // ── ⑥ 실전 가이드(practicalGuidance, 신규 필드) — A01은 "평생 관점"의
    // 생활 태도 제안으로 채운다 ──
    final practicalGuidance = <String>[
      if (yongsinElement.isNotEmpty)
        '${yongsinPhrase(terms, yongsinElement)}가 강해지는 환경(직업·관계·취미 등)을 의식적으로 가까이해 보세요.',
      if (gisinElement.isNotEmpty)
        '${gisinPhrase(terms, gisinElement)}가 지나치게 강해지는 상황은 미리 알아채고 거리를 두는 것이 좋아요.',
      if (dominantCategory != '균형')
        '${dominantCategoryPhrase()} 기운을 살릴 수 있는 역할이나 활동을 적극적으로 찾아보세요.',
      if (analysis.notableSinsal.isNotEmpty)
        '${analysis.notableSinsal.join(', ')} 기운이 발현되는 순간을 놓치지 않고 활용해 보세요.',
    ].where((s) => s.trim().isNotEmpty).toList();

    // ── ⑦ 시기(timingSection) — A01은 세운/월운/대운을 다루지 않으므로
    // 항상 null(§10 excludedData, §18 가짜 시기 금지) ──
    const List<String>? timingSection = null;

    // ── ⑧ 최종 정리(finalSummary) ──
    final finalSummaryAll = <String>[
      '정리하면, 이 사주는 ${analysis.lifeTheme}.',
      if (cappedFavorable.isNotEmpty) '특히 ${cappedFavorable.first}은 강점으로 작용해요.',
      if (cappedCaution.isNotEmpty) '다만 ${cappedCaution.first}은 계속 주의가 필요해요.',
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
}
