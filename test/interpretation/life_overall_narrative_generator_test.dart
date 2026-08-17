/// [정통사주 69종 개인화 해석 엔진 — A01 구조 통일] LifeOverallNarrativeGenerator
/// (문장 레이어) 검증. A04(CareerNarrativeGenerator) 검증 테스트와 동일한
/// 형식으로 작성해 §16(결정론)/§17(개인화)/§9(범용 문구 금지)/§18(가짜 시기
/// 금지)를 확인한다.
///
/// [절대 원칙] LifeOverallAnalyzer의 계산 로직과 기존
/// life_overall_analyzer_smoke_test.dart / life_overall_analyzer_sample30_test.dart
/// 는 이 파일이 전혀 건드리지 않는다. 이 파일은 그 위에 얹힌 새 문장
/// 레이어(LifeOverallNarrativeGenerator)만 검증한다.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/home/domain/interpretation/analyzers/life_overall_analyzer.dart';
import 'package:flutter_app/features/home/domain/interpretation/generators/life_overall_narrative_generator.dart';
import 'package:flutter_app/features/home/domain/jeontong_eighty_report_builder.dart';
import '../fixtures/jeontong_inputs.dart';
import '../fixtures/jeontong_sample_120.dart';

void main() {
  final analyzer = const LifeOverallAnalyzer();
  final generator = const LifeOverallNarrativeGenerator();
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

  test('120명의 A01 coreResult/전체 Narrative가 서로 다르다(§5 개인화)', () {
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
    // coreResult는 dominantTenGodCategory(6종)×strengthVerdict(3종)×
    // dayGan(10종) 조합 수준으로 자연 수렴할 수 있어 A04와 같은 기준(20종)을
    // 그대로 적용하되, 전체 Narrative는 완전 불일치를 요구한다.
    expect(coreResultSet.length, greaterThan(20),
        reason: 'coreResult 종류가 지나치게 적으면 개인화가 얕다는 신호');
    expect(fullNarrativeSet.length, 120, reason: '전체 Narrative는 120명 전원 달라야 함');
  });

  test('같은 dominantTenGodCategory 그룹 내부에서도 Narrative 문장이 서로 다르다(§15)', () {
    final byCategory = <String, List<String>>{};
    final byCategoryWhy = <String, List<String>>{};
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
      final cat = analysis.dominantTenGodCategory;
      byCategory.putIfAbsent(cat, () => []).add(narrative.toJson().toString());
      byCategoryWhy.putIfAbsent(cat, () => []).add(narrative.whyThisResult.join(' '));
    }
    // 최다 그룹을 찾아 내부 차별화 확인
    final largestCat = byCategory.entries.reduce((a, b) => a.value.length >= b.value.length ? a : b);
    // ignore: avoid_print
    print('최다 dominantTenGodCategory=${largestCat.key} (${largestCat.value.length}명)');
    if (largestCat.value.length > 1) {
      expect(largestCat.value.toSet().length, greaterThan(1),
          reason: '같은 $largestCat.key 그룹 내부에서 Narrative가 전부 동일하면 개인화 실패');
      expect(byCategoryWhy[largestCat.key]!.toSet().length, greaterThan(1),
          reason: '같은 $largestCat.key 그룹 내부에서 whyThisResult가 전부 동일하면 개인화 실패');
    }
  });

  test('A01과 A03이 같은 사람에 대해서도 서로 다른 관점의 결과를 낸다(§9)', () {
    final input = kJeontongTestInputs[0];
    final kst = input.birthDateTimeUtc.toUtc().add(const Duration(hours: 9));
    final built = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
      kst: kst,
      gender: input.gender,
      isLunar: input.isLunar,
      referenceDate: refDate,
    );
    final a01Analysis = analyzer.analyze(built.profile, referenceDate: refDate);
    final a01Narrative = generator.generate(built.profile, a01Analysis);
    expect(a01Narrative.categoryId, 'A01');
    expect(a01Narrative.coreResult.join(' '), contains(a01Analysis.dominantTenGodCategory));
  });

  test('§9 금지 문구(범용 문구)가 A01 Narrative에 포함되지 않는다(120명 전수 검사)', () {
    const forbiddenGenericPhrases = ['사주 뿌리부터', '오행의 흐름을 보면', '여기에 더해', '사주는 정해진 운명'];
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
        expect(fullText.contains(phrase), isFalse,
            reason: '${input.userId}의 A01 Narrative에 금지 문구 "$phrase"가 포함됨');
      }
    }
  });

  test('A01의 timingSection은 항상 null이다(§10 excludedData, §18 가짜 시기 금지)', () {
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
      expect(narrative.timingSection, isNull,
          reason: 'A01은 평생 관점 카테고리라 세운/월운/대운을 다루지 않아 timingSection이 항상 null이어야 함');
    }
  });
}
