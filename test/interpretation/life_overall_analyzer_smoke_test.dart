import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/home/domain/interpretation/analyzers/life_overall_analyzer.dart';
import 'package:flutter_app/features/home/domain/jeontong_eighty_report_builder.dart';
import '../fixtures/jeontong_inputs.dart';

void main() {
  final analyzer = const LifeOverallAnalyzer();
  final refDate = DateTime.utc(2026, 8, 13);

  test('서로 다른 3명의 A01 결과가 실제로 달라진다(§24 검증)', () {
    final results = <String, dynamic>{};
    for (final input in kJeontongTestInputs) {
      final kst = input.birthDateTimeUtc.toUtc().add(const Duration(hours: 9));
      final r = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
        kst: kst,
        gender: input.gender,
        isLunar: input.isLunar,
        referenceDate: refDate,
      );
      final analysis = analyzer.analyze(r.profile, referenceDate: refDate);
      results[input.userId] = analysis.toJson();
      // ignore: avoid_print
      print('--- ${input.userId} ---');
      // ignore: avoid_print
      print(analysis.lifeTheme);
      // ignore: avoid_print
      print(
        'dominant=${analysis.dominantTenGodCategory} strength=${analysis.strengthVerdict} '
        'yongsin=${analysis.yongsinElement} gisin=${analysis.gisinElement} '
        'sinsal=${analysis.notableSinsal}',
      );
    }

    final themes = results.values.map((r) => r['lifeTheme']).toSet();
    expect(
      themes.length,
      greaterThan(1),
      reason: '서로 다른 사주인데 lifeTheme이 동일하면 개인화 실패',
    );

    final a = results[kJeontongTestInputs[0].userId];
    final b = results[kJeontongTestInputs[1].userId];
    expect(a, isNot(equals(b)));
  });

  test('동일 입력은 항상 동일 결과(결정론 §16)', () {
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
    final a1 = analyzer.analyze(r1.profile, referenceDate: refDate).toJson();
    final a2 = analyzer.analyze(r2.profile, referenceDate: refDate).toJson();
    expect(a1.toString(), equals(a2.toString()));
  });
}
