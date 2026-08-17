/// [정통사주 69종 개인화 해석 엔진 — A04 독립 파이프라인 검증]
/// CareerNarrativeGenerator(문장 생성 레이어) 검증.
///
/// career_analyzer_test.dart/career_pattern_differentiation_test.dart는
/// CareerAnalysis(계산 레이어)를 검증한다. 이 파일은 그 위에 새로 쌓인
/// CareerNarrativeGenerator(문장 레이어)가 실제로 "사람이 읽는 문장" 수준
/// 에서도 결정론·개인화·근거추적성·금지문구 회피를 만족하는지 검증한다.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/home/domain/interpretation/analyzers/career_analyzer.dart';
import 'package:flutter_app/features/home/domain/interpretation/analyzers/life_overall_analyzer.dart';
import 'package:flutter_app/features/home/domain/interpretation/generators/career_narrative_generator.dart';
import 'package:flutter_app/features/home/domain/jeontong_eighty_report_builder.dart';
import '../fixtures/jeontong_inputs.dart';
import '../fixtures/jeontong_sample_120.dart';

/// §9 절대 금지: 어떤 카테고리에도 붙일 수 있는 범용 문구.
const List<String> _forbiddenGenericPhrases = [
  '사주 뿌리부터',
  '오행의 흐름을 보면',
  '여기에 더해',
  '사주는 정해진 운명',
];

void main() {
  final careerAnalyzer = const CareerAnalyzer();
  final lifeAnalyzer = const LifeOverallAnalyzer();
  final careerGen = const CareerNarrativeGenerator();
  final refDate = DateTime.utc(2026, 8, 13);

  test('동일 입력은 항상 동일 Narrative(결정론)', () {
    final input = kJeontongTestInputs[0];
    final kst = input.birthDateTimeUtc.toUtc().add(const Duration(hours: 9));
    final jsons = <String>{};
    for (var i = 0; i < 5; i++) {
      final built = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
        kst: kst, gender: input.gender, isLunar: input.isLunar, referenceDate: refDate,
      );
      final analysis = careerAnalyzer.analyze(built.profile, referenceDate: refDate);
      final narrative = careerGen.generate(built.profile, analysis);
      jsons.add(narrative.toJson().toString());
    }
    expect(jsons.length, equals(1), reason: '5회 반복 Narrative 결과가 완전히 동일해야 함');
  });

  test('practicalGuidance(신규 필드)가 항상 채워진다', () {
    final input = kJeontongTestInputs[0];
    final kst = input.birthDateTimeUtc.toUtc().add(const Duration(hours: 9));
    final built = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
      kst: kst, gender: input.gender, isLunar: input.isLunar, referenceDate: refDate,
    );
    final analysis = careerAnalyzer.analyze(built.profile, referenceDate: refDate);
    final narrative = careerGen.generate(built.profile, analysis);
    expect(narrative.practicalGuidance, isNotNull);
    expect(narrative.practicalGuidance, isNotEmpty);
    expect(narrative.toParagraphs(), isNotEmpty);
  });

  test('120명의 A04 coreResult/전체 Narrative가 서로 다르다(§5 개인화)', () {
    final coreResultSet = <String>{};
    final fullNarrativeSet = <String>{};

    for (final input in kJeontongSample120) {
      final kst = input.birthDateTimeUtc.toUtc().add(const Duration(hours: 9));
      final built = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
        kst: kst, gender: input.gender, isLunar: input.isLunar, referenceDate: refDate,
      );
      final analysis = careerAnalyzer.analyze(built.profile, referenceDate: refDate);
      final narrative = careerGen.generate(built.profile, analysis);
      coreResultSet.add(narrative.coreResult.join(' '));
      fullNarrativeSet.add(narrative.toJson().toString());
    }

    // ignore: avoid_print
    print('120명 coreResult 종류 수=${coreResultSet.length}/120');
    // ignore: avoid_print
    print('120명 전체 Narrative 종류 수=${fullNarrativeSet.length}/120');

    expect(fullNarrativeSet.length, equals(120),
        reason: '전체 Narrative가 완전히 동일한 두 사람이 있으면 §5 위반');
    // coreResult는 §12 규칙상 1~3문장으로 압축된 "핵심 결론"만 담아
    // careerPattern(7종)×careerStrength(5종) 조합 수준(최대 35종)으로
    // 수렴하는 것이 자연스럽다. "완전히 똑같은 문장 하나로 뭉치는" 실패
    // 상태(예: 1~5종)만 방지하면 되고, 전체 개인화 여부는 위
    // fullNarrativeSet(120/120)이 이미 보증한다.
    expect(coreResultSet.length, greaterThan(20),
        reason: 'coreResult가 소수 패턴(예: 5종 이하)으로 뭉치면 "카테고리마다 결과가 비슷하다" 문제 재발');
  });

  test('같은 careerPattern 그룹 내부에서도 Narrative 문장이 서로 다르다(§15)', () {
    final byPattern = <String, List<String>>{};
    final narrativeByUser = <String, String>{};
    final coreResultByUser = <String, String>{};
    final whyByUser = <String, String>{};

    for (final input in kJeontongSample120) {
      final kst = input.birthDateTimeUtc.toUtc().add(const Duration(hours: 9));
      final built = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
        kst: kst, gender: input.gender, isLunar: input.isLunar, referenceDate: refDate,
      );
      final analysis = careerAnalyzer.analyze(built.profile, referenceDate: refDate);
      final narrative = careerGen.generate(built.profile, analysis);
      byPattern.putIfAbsent(analysis.careerPattern, () => []).add(input.userId);
      narrativeByUser[input.userId] = narrative.toJson().toString();
      coreResultByUser[input.userId] = narrative.coreResult.join(' ');
      whyByUser[input.userId] = narrative.whyThisResult.join(' ');
    }

    final largest = byPattern.entries.reduce(
      (a, b) => a.value.length >= b.value.length ? a : b,
    );
    final groupUsers = largest.value;
    // ignore: avoid_print
    print('검증 대상 careerPattern 그룹: "${largest.key}" (${groupUsers.length}명)');
    expect(groupUsers.length, greaterThanOrEqualTo(3));

    final narrativeStrings = groupUsers.map((u) => narrativeByUser[u]!).toSet();
    final whyStrings = groupUsers.map((u) => whyByUser[u]!).toSet();

    // ignore: avoid_print
    print('그룹 내부 Narrative 종류 수=${narrativeStrings.length}/${groupUsers.length}');
    // ignore: avoid_print
    print('그룹 내부 whyThisResult 종류 수=${whyStrings.length}/${groupUsers.length}');

    expect(narrativeStrings.length, greaterThan(1),
        reason: '같은 careerPattern이라도 Narrative 전체가 전원 동일하면 §15 위반');
    expect(whyStrings.length, greaterThan(1),
        reason: '같은 careerPattern 그룹 내부에서 근거 설명(whyThisResult)이 전원 동일하면 안 됨');
  });

  test('A01(계산레벨)과 A04 Narrative가 같은 사람에 대해서도 서로 다른 관점의 결과를 낸다(§9)', () {
    // [주의] LifeOverallNarrativeGenerator는 A01/A03 구조 통일 단계(별도
    // STEP)에서 구현 예정이므로, 이 테스트는 아직 존재하지 않는 그
    // 생성기를 참조하지 않고 A01의 계산 레벨(LifeOverallAnalysis)과
    // A04의 최종 Narrative를 비교해 "카테고리 관점 자체가 다르다"는
    // §9의 핵심(범주ID/판단 내용 불일치)만 우선 확인한다.
    final input = kJeontongTestInputs[0];
    final kst = input.birthDateTimeUtc.toUtc().add(const Duration(hours: 9));
    final built = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
      kst: kst, gender: input.gender, isLunar: input.isLunar, referenceDate: refDate,
    );
    final a01Analysis = lifeAnalyzer.analyze(built.profile, referenceDate: refDate);
    final a04Analysis = careerAnalyzer.analyze(built.profile, referenceDate: refDate);
    final a04Narrative = careerGen.generate(built.profile, a04Analysis);

    expect(a01Analysis.categoryId, isNot(equals(a04Narrative.categoryId)));
    expect(a01Analysis.toJson().toString(), isNot(equals(a04Narrative.toJson().toString())));
    expect(a04Analysis.categoryName, equals('평생 직업·명예운'));
  });

  test('§9 금지 문구(범용 문구)가 A04 Narrative에 포함되지 않는다(120명 전수 검사)', () {
    for (final input in kJeontongSample120) {
      final kst = input.birthDateTimeUtc.toUtc().add(const Duration(hours: 9));
      final built = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
        kst: kst, gender: input.gender, isLunar: input.isLunar, referenceDate: refDate,
      );
      final analysis = careerAnalyzer.analyze(built.profile, referenceDate: refDate);
      final narrative = careerGen.generate(built.profile, analysis);
      final fullText = narrative.toParagraphs().join(' ');
      for (final phrase in _forbiddenGenericPhrases) {
        expect(fullText.contains(phrase), isFalse,
            reason: '${input.userId}의 A04 결과에 금지 문구 "$phrase"가 포함됨');
      }
    }
  });

  test('시기(timingSection)는 careerPeakDaewoonLabel이 있을 때만 채워진다(§18 가짜 시기 금지)', () {
    for (final input in kJeontongSample120.take(30)) {
      final kst = input.birthDateTimeUtc.toUtc().add(const Duration(hours: 9));
      final built = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
        kst: kst, gender: input.gender, isLunar: input.isLunar, referenceDate: refDate,
      );
      final analysis = careerAnalyzer.analyze(built.profile, referenceDate: refDate);
      final narrative = careerGen.generate(built.profile, analysis);
      if (analysis.careerPeakDaewoonLabel.isEmpty) {
        expect(narrative.timingSection, isNull,
            reason: '${input.userId}: careerPeakDaewoonLabel이 없는데 timingSection이 생성됨(가짜 시기 위험)');
      } else {
        expect(narrative.timingSection, isNotNull);
        expect(narrative.timingSection, isNotEmpty);
      }
    }
  });
}
