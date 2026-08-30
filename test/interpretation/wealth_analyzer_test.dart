/// [정통사주 69종 개인화 해석 엔진 — 3단계] A03 WealthAnalyzer 검증.
///
/// §16(결정론) + §17(개인화, 서로 다른 사주인데 같은 결과 금지)를 3명
/// seed + 30명 샘플로 함께 확인한다. 또한 A01과 A03이 "같은 SajuProfile"
/// 을 받고도 서로 다른 관점(중심 기운 vs 재물 구조)의 결과를 낸다는
/// §9(카테고리 관점 차이) 요구도 함께 확인한다.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/home/domain/interpretation/analyzers/life_overall_analyzer.dart';
import 'package:flutter_app/features/home/domain/interpretation/analyzers/wealth_analyzer.dart';
import 'package:flutter_app/features/home/domain/jeontong_eighty_report_builder.dart';
import '../fixtures/jeontong_inputs.dart';
import '../fixtures/jeontong_sample_30.dart';

void main() {
  final analyzer = const WealthAnalyzer();
  final lifeAnalyzer = const LifeOverallAnalyzer();
  final refDate = DateTime.utc(2026, 8, 13);

  test('서로 다른 3명의 A03 결과가 실제로 달라진다', () {
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
      print(
        '${analysis.wealthPattern} / ${analysis.wealthStrength} / ${analysis.incomePattern}',
      );
      // ignore: avoid_print
      print('risk=${analysis.riskPattern}');
      // ignore: avoid_print
      print('peak=${analysis.wealthPeakDaewoonLabel}');
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

  test('같은 SajuProfile이라도 A01(중심기운)과 A03(재물구조)는 다른 관점의 결과를 낸다(§9)', () {
    final input = kJeontongTestInputs[0];
    final kst = input.birthDateTimeUtc.toUtc().add(const Duration(hours: 9));
    final built = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
      kst: kst,
      gender: input.gender,
      isLunar: input.isLunar,
      referenceDate: refDate,
    );
    final a01 = lifeAnalyzer.analyze(built.profile, referenceDate: refDate);
    final a03 = analyzer.analyze(built.profile, referenceDate: refDate);
    // 같은 profile을 받았지만 카테고리ID/구조 자체가 다르고, 재물 카테고리는
    // 재물 고유 필드(wealthPattern 등)를 반드시 가져야 한다 — A01에는 없는 필드.
    expect(a01.categoryId, isNot(equals(a03.categoryId)));
    expect(a03.wealthPattern, isNotEmpty);
  });

  test('30명 샘플의 A03 wealthPattern/wealthStrength가 계산값에 따라 달라진다(§24 방식 확장)', () {
    final patternSet = <String>{};
    final strengthSet = <String>{};
    final fullJsonSet = <String>{};

    for (final input in kJeontongSample30) {
      final kst = input.birthDateTimeUtc.toUtc().add(const Duration(hours: 9));
      final built = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
        kst: kst,
        gender: input.gender,
        isLunar: input.isLunar,
        referenceDate: refDate,
      );
      final analysis = analyzer.analyze(built.profile, referenceDate: refDate);
      patternSet.add(analysis.wealthPattern);
      strengthSet.add(analysis.wealthStrength);
      fullJsonSet.add(analysis.toJson().toString());
    }

    expect(fullJsonSet.length, greaterThan(1));
    expect(
      patternSet.length,
      greaterThan(1),
      reason: 'wealthPattern이 30명 전원 동일하면 개인화 실패',
    );
    expect(
      strengthSet.length,
      greaterThan(1),
      reason: 'wealthStrength가 30명 전원 동일하면 개인화 실패',
    );

    // ignore: avoid_print
    print('wealthPattern 종류=$patternSet');
    // ignore: avoid_print
    print('wealthStrength 종류=$strengthSet');
  });
}
