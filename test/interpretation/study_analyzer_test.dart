/// [정통사주 69종 개인화 해석 엔진 — 9단계] A09 StudyAnalyzer 검증.
///
/// A03~A08과 동일한 패턴 — §2(결정론) + §5/§6(개인화)를 3명 seed +
/// 30명 샘플로 확인하고, A01/A03~A09가 같은 SajuProfile을 받고도 서로
/// 다른 관점의 결과를 낸다는 §9를 함께 확인한다. A09 고유 근거인
/// munchangPositionCondition(문창귀인이 걸린 자리)도 함께 검증한다.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/home/domain/interpretation/analyzers/life_overall_analyzer.dart';
import 'package:flutter_app/features/home/domain/interpretation/analyzers/wealth_analyzer.dart';
import 'package:flutter_app/features/home/domain/interpretation/analyzers/career_analyzer.dart';
import 'package:flutter_app/features/home/domain/interpretation/analyzers/health_analyzer.dart';
import 'package:flutter_app/features/home/domain/interpretation/analyzers/love_analyzer.dart';
import 'package:flutter_app/features/home/domain/interpretation/analyzers/children_analyzer.dart';
import 'package:flutter_app/features/home/domain/interpretation/analyzers/parents_siblings_analyzer.dart';
import 'package:flutter_app/features/home/domain/interpretation/analyzers/study_analyzer.dart';
import 'package:flutter_app/features/home/domain/jeontong_eighty_report_builder.dart';
import '../fixtures/jeontong_inputs.dart';
import '../fixtures/jeontong_sample_30.dart';

void main() {
  final analyzer = const StudyAnalyzer();
  final parentsSiblingsAnalyzer = const ParentsSiblingsAnalyzer();
  final childrenAnalyzer = const ChildrenAnalyzer();
  final loveAnalyzer = const LoveAnalyzer();
  final healthAnalyzer = const HealthAnalyzer();
  final careerAnalyzer = const CareerAnalyzer();
  final wealthAnalyzer = const WealthAnalyzer();
  final lifeAnalyzer = const LifeOverallAnalyzer();
  final refDate = DateTime.utc(2026, 8, 13);

  test('서로 다른 3명의 A09 결과가 실제로 달라진다', () {
    final results = <String, String>{};
    for (final input in kJeontongTestInputs) {
      final kst = input.birthDateTimeUtc.toUtc().add(const Duration(hours: 9));
      final built = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
        kst: kst,
        gender: input.gender,
        isLunar: input.isLunar,
        referenceDate: refDate,
      );
      final analysis = analyzer.analyze(built.profile, referenceDate: refDate);
      results[input.userId] = analysis.toJson().toString();
      // ignore: avoid_print
      print('--- ${input.userId} ---');
      // ignore: avoid_print
      print('${analysis.studyPattern} / ${analysis.studyBondStrength}');
      // ignore: avoid_print
      print('munchang=${analysis.munchangPositionCondition}');
      // ignore: avoid_print
      print('risk=${analysis.studyRiskPattern}');
      // ignore: avoid_print
      print('approach=${analysis.studyApproach}');
      // ignore: avoid_print
      print('peak_daewoon=${analysis.studyPeakDaewoonLabel}');
    }
    expect(results.values.toSet().length, greaterThan(1));
  });

  test('동일 입력은 항상 동일 결과(결정론)', () {
    final input = kJeontongTestInputs[0];
    final kst = input.birthDateTimeUtc.toUtc().add(const Duration(hours: 9));
    final r1 = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
      kst: kst,
      gender: input.gender,
      isLunar: input.isLunar,
      referenceDate: refDate,
    );
    final r2 = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
      kst: kst,
      gender: input.gender,
      isLunar: input.isLunar,
      referenceDate: refDate,
    );
    final a1 = analyzer
        .analyze(r1.profile, referenceDate: refDate)
        .toJson()
        .toString();
    final a2 = analyzer
        .analyze(r2.profile, referenceDate: refDate)
        .toJson()
        .toString();
    expect(a1, equals(a2));
  });

  test('동일 입력 10회 반복해도 완전 동일(§2 강화 결정론)', () {
    final input = kJeontongTestInputs[1];
    final kst = input.birthDateTimeUtc.toUtc().add(const Duration(hours: 9));
    final jsons = <String>{};
    for (var i = 0; i < 10; i++) {
      final built = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
        kst: kst,
        gender: input.gender,
        isLunar: input.isLunar,
        referenceDate: refDate,
      );
      jsons.add(
        analyzer
            .analyze(built.profile, referenceDate: refDate)
            .toJson()
            .toString(),
      );
    }
    expect(jsons.length, equals(1), reason: '10회 반복 결과가 모두 동일해야 함');
  });

  test('같은 SajuProfile이라도 A01/A03~A09는 서로 다른 관점의 결과를 낸다(§9)', () {
    final input = kJeontongTestInputs[0];
    final kst = input.birthDateTimeUtc.toUtc().add(const Duration(hours: 9));
    final built = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
      kst: kst,
      gender: input.gender,
      isLunar: input.isLunar,
      referenceDate: refDate,
    );
    final a01 = lifeAnalyzer.analyze(built.profile, referenceDate: refDate);
    final a03 = wealthAnalyzer.analyze(built.profile, referenceDate: refDate);
    final a04 = careerAnalyzer.analyze(built.profile, referenceDate: refDate);
    final a05 = healthAnalyzer.analyze(built.profile, referenceDate: refDate);
    final a06 = loveAnalyzer.analyze(built.profile, referenceDate: refDate);
    final a07 = childrenAnalyzer.analyze(built.profile, referenceDate: refDate);
    final a08 = parentsSiblingsAnalyzer.analyze(
      built.profile,
      referenceDate: refDate,
    );
    final a09 = analyzer.analyze(built.profile, referenceDate: refDate);
    expect(a01.categoryId, isNot(equals(a09.categoryId)));
    expect(a03.categoryId, isNot(equals(a09.categoryId)));
    expect(a04.categoryId, isNot(equals(a09.categoryId)));
    expect(a05.categoryId, isNot(equals(a09.categoryId)));
    expect(a06.categoryId, isNot(equals(a09.categoryId)));
    expect(a07.categoryId, isNot(equals(a09.categoryId)));
    expect(a08.categoryId, isNot(equals(a09.categoryId)));
    expect(a09.studyPattern, isNotEmpty);
    expect(a09.studyBondStrength, isNotEmpty);
    expect(a09.munchangPositionCondition, isNotEmpty);
    expect(a09.studyRiskPattern, isNotEmpty);
    expect(a09.studyApproach, isNotEmpty);
  });

  test(
    '30명 샘플의 A09 studyPattern/studyBondStrength/munchangPositionCondition이 계산값에 따라 달라진다',
    () {
      final studyPatternSet = <String>{};
      final studyBondStrengthSet = <String>{};
      final munchangSet = <String>{};
      final fullJsonSet = <String>{};

      for (final input in kJeontongSample30) {
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
        final analysis = analyzer.analyze(
          built.profile,
          referenceDate: refDate,
        );
        studyPatternSet.add(analysis.studyPattern);
        studyBondStrengthSet.add(analysis.studyBondStrength);
        munchangSet.add(analysis.munchangPositionCondition);
        fullJsonSet.add(analysis.toJson().toString());
      }

      expect(fullJsonSet.length, greaterThan(1));
      expect(
        studyPatternSet.length,
        greaterThan(1),
        reason: 'studyPattern이 30명 전원 동일하면 개인화 실패',
      );
      expect(
        studyBondStrengthSet.length,
        greaterThan(1),
        reason: 'studyBondStrength가 30명 전원 동일하면 개인화 실패',
      );
      expect(
        munchangSet.length,
        greaterThan(1),
        reason: 'munchangPositionCondition이 30명 전원 동일하면 개인화 실패',
      );

      // ignore: avoid_print
      print('studyPattern 종류=$studyPatternSet');
      // ignore: avoid_print
      print('studyBondStrength 종류=$studyBondStrengthSet');
      // ignore: avoid_print
      print('munchangPositionCondition 종류=$munchangSet');
    },
  );
}
