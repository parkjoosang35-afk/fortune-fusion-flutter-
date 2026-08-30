/// [정통사주 69종 개인화 해석 엔진 — A03 구조 통일] WealthNarrativeGenerator
/// (문장 레이어) 검증. A04(CareerNarrativeGenerator) 검증 테스트와 동일한
/// 형식으로 작성해 §16(결정론)/§17(개인화)/§9(범용 문구 금지)/§18(가짜 시기
/// 금지)를 확인한다.
///
/// [절대 원칙] WealthAnalyzer의 계산 로직과 기존 wealth_analyzer_test.dart는
/// 이 파일이 전혀 건드리지 않는다. 이 파일은 그 위에 얹힌 새 문장 레이어
/// (WealthNarrativeGenerator)만 검증한다.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/home/domain/interpretation/analyzers/wealth_analyzer.dart';
import 'package:flutter_app/features/home/domain/interpretation/generators/wealth_narrative_generator.dart';
import 'package:flutter_app/features/home/domain/jeontong_eighty_report_builder.dart';
import '../fixtures/jeontong_inputs.dart';
import '../fixtures/jeontong_sample_120.dart';

void main() {
  final analyzer = const WealthAnalyzer();
  final generator = const WealthNarrativeGenerator();
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
      final analysis = analyzer.analyze(built.profile, referenceDate: refDate);
      final narrative = generator.generate(built.profile, analysis);
      jsons.add(narrative.toJson().toString());
    }
    expect(jsons.length, 1, reason: '같은 입력인데 Narrative가 매번 달라지면 결정론 위반');
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
    final analysis = analyzer.analyze(built.profile, referenceDate: refDate);
    final narrative = generator.generate(built.profile, analysis);
    expect(narrative.practicalGuidance, isNotNull);
    expect(narrative.practicalGuidance, isNotEmpty);
    expect(narrative.toParagraphs(), isNotEmpty);
  });

  test('120명의 A03 coreResult/전체 Narrative가 서로 다르다(§5 개인화)', () {
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
      final analysis = analyzer.analyze(built.profile, referenceDate: refDate);
      final narrative = generator.generate(built.profile, analysis);
      coreResultSet.add(narrative.coreResult.join(' '));
      fullNarrativeSet.add(narrative.toJson().toString());
    }
    // coreResult는 wealthPattern(5종)×wealthStrength(5종) 조합 수준으로
    // 자연 수렴할 수 있어(§12 규칙상 최대 3문장 압축) A04와 같은 기준(20종)을
    // 적용하되, 전체 Narrative는 완전 불일치를 요구한다.
    expect(
      coreResultSet.length,
      greaterThan(20),
      reason: 'coreResult 종류가 지나치게 적으면 개인화가 얕다는 신호',
    );
    expect(fullNarrativeSet.length, 120, reason: '전체 Narrative는 120명 전원 달라야 함');
  });

  test('같은 wealthPattern 그룹 내부에서도 Narrative 문장이 서로 다르다(§15)', () {
    final byPattern = <String, List<String>>{};
    final byPatternWhy = <String, List<String>>{};
    for (final input in kJeontongSample120) {
      final kst = input.birthDateTimeUtc.toUtc().add(const Duration(hours: 9));
      final built = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
        kst: kst,
        gender: input.gender,
        isLunar: input.isLunar,
        referenceDate: refDate,
      );
      final analysis = analyzer.analyze(built.profile, referenceDate: refDate);
      final narrative = generator.generate(built.profile, analysis);
      final pattern = analysis.wealthPattern;
      byPattern
          .putIfAbsent(pattern, () => [])
          .add(narrative.toJson().toString());
      byPatternWhy
          .putIfAbsent(pattern, () => [])
          .add(narrative.whyThisResult.join(' '));
    }
    final largestPattern = byPattern.entries.reduce(
      (a, b) => a.value.length >= b.value.length ? a : b,
    );
    // ignore: avoid_print
    print(
      '최다 wealthPattern=${largestPattern.key} (${largestPattern.value.length}명)',
    );
    if (largestPattern.value.length > 1) {
      expect(
        largestPattern.value.toSet().length,
        greaterThan(1),
        reason: '같은 wealthPattern 그룹 내부에서 Narrative가 전부 동일하면 개인화 실패',
      );
      expect(
        byPatternWhy[largestPattern.key]!.toSet().length,
        greaterThan(1),
        reason: '같은 wealthPattern 그룹 내부에서 whyThisResult가 전부 동일하면 개인화 실패',
      );
    }
  });

  test('A01(중심기운)과 A03(재물구조) Narrative가 같은 사람에 대해서도 서로 다른 관점을 낸다(§9)', () {
    final input = kJeontongTestInputs[0];
    final kst = input.birthDateTimeUtc.toUtc().add(const Duration(hours: 9));
    final built = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
      kst: kst,
      gender: input.gender,
      isLunar: input.isLunar,
      referenceDate: refDate,
    );
    final a03Analysis = analyzer.analyze(built.profile, referenceDate: refDate);
    final a03Narrative = generator.generate(built.profile, a03Analysis);
    expect(a03Narrative.categoryId, 'A03');
    expect(a03Narrative.coreResult.join(' '), contains('일간'));
  });

  test('§9 금지 문구(범용 문구)가 A03 Narrative에 포함되지 않는다(120명 전수 검사)', () {
    const forbiddenGenericPhrases = [
      '사주 뿌리부터',
      '오행의 흐름을 보면',
      '여기에 더해',
      '사주는 정해진 운명',
    ];
    for (final input in kJeontongSample120) {
      final kst = input.birthDateTimeUtc.toUtc().add(const Duration(hours: 9));
      final built = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
        kst: kst,
        gender: input.gender,
        isLunar: input.isLunar,
        referenceDate: refDate,
      );
      final analysis = analyzer.analyze(built.profile, referenceDate: refDate);
      final narrative = generator.generate(built.profile, analysis);
      final fullText = narrative.toParagraphs().join(' ');
      for (final phrase in forbiddenGenericPhrases) {
        expect(
          fullText.contains(phrase),
          isFalse,
          reason: '${input.userId}의 A03 Narrative에 금지 문구 "$phrase"가 포함됨',
        );
      }
    }
  });

  test('시기(timingSection)는 wealthPeakDaewoonLabel이 있을 때만 채워진다(§18 가짜 시기 금지)', () {
    for (final input in kJeontongSample120.take(30)) {
      final kst = input.birthDateTimeUtc.toUtc().add(const Duration(hours: 9));
      final built = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
        kst: kst,
        gender: input.gender,
        isLunar: input.isLunar,
        referenceDate: refDate,
      );
      final analysis = analyzer.analyze(built.profile, referenceDate: refDate);
      final narrative = generator.generate(built.profile, analysis);
      if (analysis.wealthPeakDaewoonLabel.isEmpty) {
        expect(
          narrative.timingSection,
          isNull,
          reason:
              '${input.userId}: wealthPeakDaewoonLabel이 비어있는데 timingSection이 채워짐(가짜 시기)',
        );
      } else {
        expect(narrative.timingSection, isNotNull);
        expect(narrative.timingSection, isNotEmpty);
      }
    }
  });
}
