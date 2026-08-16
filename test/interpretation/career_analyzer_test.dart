/// [정통사주 69종 개인화 해석 엔진 — 4단계] A04 CareerAnalyzer 검증.
///
/// A03(wealth_analyzer_test.dart)과 동일한 패턴 — §16(결정론) + §17(개인화)
/// 를 3명 seed + 30명 샘플로 확인하고, A01/A03/A04가 같은 SajuProfile을
/// 받고도 서로 다른 관점의 결과를 낸다는 §9를 함께 확인한다.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/home/domain/interpretation/analyzers/life_overall_analyzer.dart';
import 'package:flutter_app/features/home/domain/interpretation/analyzers/wealth_analyzer.dart';
import 'package:flutter_app/features/home/domain/interpretation/analyzers/career_analyzer.dart';
import 'package:flutter_app/features/home/domain/jeontong_eighty_report_builder.dart';
import '../fixtures/jeontong_inputs.dart';
import '../fixtures/jeontong_sample_30.dart';

void main() {
  final analyzer = const CareerAnalyzer();
  final wealthAnalyzer = const WealthAnalyzer();
  final lifeAnalyzer = const LifeOverallAnalyzer();
  final refDate = DateTime.utc(2026, 8, 13);

  test('서로 다른 3명의 A04 결과가 실제로 달라진다', () {
    final results = <String, String>{};
    for (final input in kJeontongTestInputs) {
      final kst = input.birthDateTimeUtc.toUtc().add(const Duration(hours: 9));
      final built = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
        kst: kst, gender: input.gender, isLunar: input.isLunar, referenceDate: refDate,
      );
      final analysis = analyzer.analyze(built.profile, referenceDate: refDate);
      results[input.userId] = analysis.toJson().toString();
      // ignore: avoid_print
      print('--- ${input.userId} ---');
      // ignore: avoid_print
      print('${analysis.careerPattern} / ${analysis.careerStrength} / ${analysis.workStyle}');
      // ignore: avoid_print
      print('risk=${analysis.careerRiskPattern}');
      // ignore: avoid_print
      print('peak=${analysis.careerPeakDaewoonLabel}');
    }
    expect(results.values.toSet().length, greaterThan(1));
  });

  test('동일 입력은 항상 동일 결과(결정론)', () {
    final input = kJeontongTestInputs[0];
    final kst = input.birthDateTimeUtc.toUtc().add(const Duration(hours: 9));
    final r1 = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
      kst: kst, gender: input.gender, isLunar: input.isLunar, referenceDate: refDate,
    );
    final r2 = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
      kst: kst, gender: input.gender, isLunar: input.isLunar, referenceDate: refDate,
    );
    final a1 = analyzer.analyze(r1.profile, referenceDate: refDate).toJson().toString();
    final a2 = analyzer.analyze(r2.profile, referenceDate: refDate).toJson().toString();
    expect(a1, equals(a2));
  });

  test('동일 입력 10회 반복해도 완전 동일(§2 강화 결정론)', () {
    final input = kJeontongTestInputs[1];
    final kst = input.birthDateTimeUtc.toUtc().add(const Duration(hours: 9));
    final jsons = <String>{};
    for (var i = 0; i < 10; i++) {
      final built = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
        kst: kst, gender: input.gender, isLunar: input.isLunar, referenceDate: refDate,
      );
      jsons.add(analyzer.analyze(built.profile, referenceDate: refDate).toJson().toString());
    }
    expect(jsons.length, equals(1), reason: '10회 반복 결과가 모두 동일해야 함');
  });

  test('같은 SajuProfile이라도 A01/A03/A04는 서로 다른 관점의 결과를 낸다(§9)', () {
    final input = kJeontongTestInputs[0];
    final kst = input.birthDateTimeUtc.toUtc().add(const Duration(hours: 9));
    final built = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
      kst: kst, gender: input.gender, isLunar: input.isLunar, referenceDate: refDate,
    );
    final a01 = lifeAnalyzer.analyze(built.profile, referenceDate: refDate);
    final a03 = wealthAnalyzer.analyze(built.profile, referenceDate: refDate);
    final a04 = analyzer.analyze(built.profile, referenceDate: refDate);
    expect(a01.categoryId, isNot(equals(a04.categoryId)));
    expect(a03.categoryId, isNot(equals(a04.categoryId)));
    expect(a04.careerPattern, isNotEmpty);
    expect(a04.suitableFields, isNotEmpty);
  });

  test('30명 샘플의 A04 careerPattern/careerStrength가 계산값에 따라 달라진다', () {
    final patternSet = <String>{};
    final strengthSet = <String>{};
    final fullJsonSet = <String>{};

    for (final input in kJeontongSample30) {
      final kst = input.birthDateTimeUtc.toUtc().add(const Duration(hours: 9));
      final built = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
        kst: kst, gender: input.gender, isLunar: input.isLunar, referenceDate: refDate,
      );
      final analysis = analyzer.analyze(built.profile, referenceDate: refDate);
      patternSet.add(analysis.careerPattern);
      strengthSet.add(analysis.careerStrength);
      fullJsonSet.add(analysis.toJson().toString());
    }

    expect(fullJsonSet.length, greaterThan(1));
    expect(patternSet.length, greaterThan(1),
        reason: 'careerPattern이 30명 전원 동일하면 개인화 실패');
    expect(strengthSet.length, greaterThan(1),
        reason: 'careerStrength가 30명 전원 동일하면 개인화 실패');

    // ignore: avoid_print
    print('careerPattern 종류=$patternSet');
    // ignore: avoid_print
    print('careerStrength 종류=$strengthSet');
  });
}
