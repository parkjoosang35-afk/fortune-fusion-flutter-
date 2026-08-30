/// [정통사주 69종 개인화 해석 엔진 — A05 독립 파이프라인 검증]
/// HealthNarrativeGenerator(문장 생성 레이어) 검증.
///
/// health_analyzer_test.dart/health_duplication_and_traceability_test.dart/
/// health_pattern_differentiation_test.dart는 HealthAnalysis(계산 레이어)를
/// 검증한다. 이 파일은 그 위에 새로 쌓인 HealthNarrativeGenerator(문장
/// 레이어)가 A01/A03/A04 검증 테스트와 동일한 형식으로 결정론·개인화·
/// 근거추적성·금지문구 회피·가짜 시기 금지를 만족하는지 검증한다.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/home/domain/interpretation/analyzers/health_analyzer.dart';
import 'package:flutter_app/features/home/domain/interpretation/analyzers/life_overall_analyzer.dart';
import 'package:flutter_app/features/home/domain/interpretation/generators/health_narrative_generator.dart';
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
  final healthAnalyzer = const HealthAnalyzer();
  final lifeAnalyzer = const LifeOverallAnalyzer();
  final healthGen = const HealthNarrativeGenerator();
  final refDate = DateTime.utc(2026, 8, 13);

  test('동일 입력은 항상 동일 Narrative(결정론)', () {
    final input = kJeontongTestInputs[0];
    final kst = input.birthDateTimeUtc.toUtc().add(const Duration(hours: 9));
    final jsons = <String>{};
    for (var i = 0; i < 5; i++) {
      final built = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
        kst: kst,
        gender: input.gender,
        isLunar: input.isLunar,
        referenceDate: refDate,
      );
      final analysis = healthAnalyzer.analyze(
        built.profile,
        referenceDate: refDate,
      );
      final narrative = healthGen.generate(built.profile, analysis);
      jsons.add(narrative.toJson().toString());
    }
    expect(jsons.length, equals(1), reason: '5회 반복 Narrative 결과가 완전히 동일해야 함');
  });

  test('practicalGuidance(신규 필드)가 항상 채워진다', () {
    final input = kJeontongTestInputs[0];
    final kst = input.birthDateTimeUtc.toUtc().add(const Duration(hours: 9));
    final built = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
      kst: kst,
      gender: input.gender,
      isLunar: input.isLunar,
      referenceDate: refDate,
    );
    final analysis = healthAnalyzer.analyze(
      built.profile,
      referenceDate: refDate,
    );
    final narrative = healthGen.generate(built.profile, analysis);
    expect(narrative.practicalGuidance, isNotNull);
    expect(narrative.practicalGuidance, isNotEmpty);
    expect(narrative.toParagraphs(), isNotEmpty);
  });

  test('120명의 A05 coreResult/전체 Narrative가 서로 다르다(§5 개인화)', () {
    final coreResultSet = <String>{};
    final fullNarrativeSet = <String>{};

    for (final input in kJeontongSample120) {
      final kst = input.birthDateTimeUtc.toUtc().add(const Duration(hours: 9));
      final built = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
        kst: kst,
        gender: input.gender,
        isLunar: input.isLunar,
        referenceDate: refDate,
      );
      final analysis = healthAnalyzer.analyze(
        built.profile,
        referenceDate: refDate,
      );
      final narrative = healthGen.generate(built.profile, analysis);
      coreResultSet.add(narrative.coreResult.join(' '));
      fullNarrativeSet.add(narrative.toJson().toString());
    }

    // ignore: avoid_print
    print('120명 coreResult 종류 수=${coreResultSet.length}/120');
    // ignore: avoid_print
    print('120명 전체 Narrative 종류 수=${fullNarrativeSet.length}/120');

    expect(
      fullNarrativeSet.length,
      equals(120),
      reason: '전체 Narrative가 완전히 동일한 두 사람이 있으면 §5 위반',
    );
    expect(
      coreResultSet.length,
      greaterThan(5),
      reason: 'coreResult가 지나치게 소수 패턴으로 뭉치면 "카테고리마다 결과가 비슷하다" 문제 재발',
    );
  });

  test('같은 healthConstitutionPattern 그룹 내부에서도 Narrative 문장이 서로 다르다(§15)', () {
    final byPattern = <String, List<String>>{};
    final narrativeByUser = <String, String>{};
    final whyByUser = <String, String>{};

    for (final input in kJeontongSample120) {
      final kst = input.birthDateTimeUtc.toUtc().add(const Duration(hours: 9));
      final built = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
        kst: kst,
        gender: input.gender,
        isLunar: input.isLunar,
        referenceDate: refDate,
      );
      final analysis = healthAnalyzer.analyze(
        built.profile,
        referenceDate: refDate,
      );
      final narrative = healthGen.generate(built.profile, analysis);
      byPattern
          .putIfAbsent(analysis.healthConstitutionPattern, () => [])
          .add(input.userId);
      narrativeByUser[input.userId] = narrative.toJson().toString();
      whyByUser[input.userId] = narrative.whyThisResult.join(' ');
    }

    final largest = byPattern.entries.reduce(
      (a, b) => a.value.length >= b.value.length ? a : b,
    );
    final groupUsers = largest.value;
    // ignore: avoid_print
    print(
      '검증 대상 healthConstitutionPattern 그룹: "${largest.key}" (${groupUsers.length}명)',
    );

    if (groupUsers.length >= 3) {
      final narrativeStrings = groupUsers
          .map((u) => narrativeByUser[u]!)
          .toSet();
      final whyStrings = groupUsers.map((u) => whyByUser[u]!).toSet();

      // ignore: avoid_print
      print(
        '그룹 내부 Narrative 종류 수=${narrativeStrings.length}/${groupUsers.length}',
      );
      // ignore: avoid_print
      print(
        '그룹 내부 whyThisResult 종류 수=${whyStrings.length}/${groupUsers.length}',
      );

      expect(
        narrativeStrings.length,
        greaterThan(1),
        reason: '같은 healthConstitutionPattern이라도 Narrative 전체가 전원 동일하면 §15 위반',
      );
      expect(
        whyStrings.length,
        greaterThan(1),
        reason:
            '같은 healthConstitutionPattern 그룹 내부에서 근거 설명(whyThisResult)이 전원 동일하면 안 됨',
      );
    }
  });

  test('A01(계산레벨)과 A05 Narrative가 같은 사람에 대해서도 서로 다른 관점의 결과를 낸다(§9)', () {
    final input = kJeontongTestInputs[0];
    final kst = input.birthDateTimeUtc.toUtc().add(const Duration(hours: 9));
    final built = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
      kst: kst,
      gender: input.gender,
      isLunar: input.isLunar,
      referenceDate: refDate,
    );
    final a01Analysis = lifeAnalyzer.analyze(
      built.profile,
      referenceDate: refDate,
    );
    final a05Analysis = healthAnalyzer.analyze(
      built.profile,
      referenceDate: refDate,
    );
    final a05Narrative = healthGen.generate(built.profile, a05Analysis);

    expect(a01Analysis.categoryId, isNot(equals(a05Narrative.categoryId)));
    expect(
      a01Analysis.toJson().toString(),
      isNot(equals(a05Narrative.toJson().toString())),
    );
    expect(a05Analysis.categoryName, equals('평생 건강운'));
  });

  test('§9 금지 문구(범용 문구)가 A05 Narrative에 포함되지 않는다(120명 전수 검사)', () {
    for (final input in kJeontongSample120) {
      final kst = input.birthDateTimeUtc.toUtc().add(const Duration(hours: 9));
      final built = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
        kst: kst,
        gender: input.gender,
        isLunar: input.isLunar,
        referenceDate: refDate,
      );
      final analysis = healthAnalyzer.analyze(
        built.profile,
        referenceDate: refDate,
      );
      final narrative = healthGen.generate(built.profile, analysis);
      final fullText = narrative.toParagraphs().join(' ');
      for (final phrase in _forbiddenGenericPhrases) {
        expect(
          fullText.contains(phrase),
          isFalse,
          reason: '${input.userId}의 A05 결과에 금지 문구 "$phrase"가 포함됨',
        );
      }
    }
  });

  test(
    '시기(timingSection)는 healthCautionDaewoonLabel이 있을 때만 채워진다(§18 가짜 시기 금지)',
    () {
      for (final input in kJeontongSample120.take(30)) {
        final kst = input.birthDateTimeUtc.toUtc().add(
          const Duration(hours: 9),
        );
        final built =
            JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
              kst: kst,
              gender: input.gender,
              isLunar: input.isLunar,
              referenceDate: refDate,
            );
        final analysis = healthAnalyzer.analyze(
          built.profile,
          referenceDate: refDate,
        );
        final narrative = healthGen.generate(built.profile, analysis);
        if (analysis.healthCautionDaewoonLabel.isEmpty) {
          expect(
            narrative.timingSection,
            isNull,
            reason:
                '${input.userId}: healthCautionDaewoonLabel이 없는데 timingSection이 생성됨(가짜 시기 위험)',
          );
        } else {
          expect(narrative.timingSection, isNotNull);
          expect(narrative.timingSection, isNotEmpty);
        }
      }
    },
  );

  test('§8 용어 서술: 신강/신약이 등장하면 첫 등장 시 한자+쉬운 의미가 함께 풀어 설명된다', () {
    var checked = 0;
    for (final input in kJeontongSample120.take(40)) {
      final kst = input.birthDateTimeUtc.toUtc().add(const Duration(hours: 9));
      final built = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
        kst: kst,
        gender: input.gender,
        isLunar: input.isLunar,
        referenceDate: refDate,
      );
      final analysis = healthAnalyzer.analyze(
        built.profile,
        referenceDate: refDate,
      );
      final narrative = healthGen.generate(built.profile, analysis);
      final fullText = narrative.toParagraphs().join(' ');
      final verdict = analysis.interpretationContext['strengthVerdict'] ?? '';
      if (verdict.isNotEmpty && fullText.contains(verdict)) {
        checked++;
        // 신강(身强)/신약(身弱)/중화(中和) 한자가 최소 1회 포함되어야 함
        final hasHanja =
            fullText.contains('身强') ||
            fullText.contains('身弱') ||
            fullText.contains('中和');
        expect(
          hasHanja,
          isTrue,
          reason: '${input.userId}: 신강신약 용어가 등장했는데 한자 병기가 없음',
        );
      }
    }
    expect(checked, greaterThan(0), reason: '신강신약 용어가 한 번도 등장하지 않으면 검증 대상이 없음');
  });
}
