import 'package:flutter_app/features/home/domain/jeontong_eighty_calculator.dart';
import 'package:flutter_app/features/home/domain/jeontong_eighty_matrix.dart';
import 'package:flutter_app/features/home/domain/jeontong_eighty_report_builder.dart';
import 'package:flutter_app/features/home/domain/jeontong_narrative_interpreter.dart';
import 'package:flutter_app/features/home/domain/saju_fortune_rules.dart';
import 'package:flutter_app/features/home/domain/saju_interpreter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('probe A07', () async {
    SajuRules.resetForTest();
    SajuFortuneRules.resetForTest();
    await SajuRules.preload();
    await SajuFortuneRules.preload();
    final built = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
      kst: DateTime(1990, 5, 12, 10, 30),
      gender: 'male',
      isLunar: false,
      referenceDate: DateTime.utc(2026, 8, 13),
    );
    final interp = SajuInterpreter.fullInterpretation(built.saju);
    final rules = SajuFortuneRules.cachedOrNull!;
    final ctx = JeontongCalcContext(
      saju: built.saju,
      interp: interp,
      rules: rules,
      referenceDate: DateTime.utc(2026, 8, 13),
      profile: built.profile,
    );
    final entry = JeontongEightyMatrix.all.firstWhere((e) => e.id == 'A07');
    final data = runJeontongCategory('A07', ctx).data;
    // ignore: avoid_print
    print('=== A07 data ===');
    // ignore: avoid_print
    print(data);
    final paragraphs = JeontongNarrativeInterpreter.paragraphs(
      interp,
      entry,
      name: '박주상',
      data: data,
    );
    // ignore: avoid_print
    print('=== paragraphs count: ${paragraphs.length} ===');
    for (var i = 0; i < paragraphs.length; i++) {
      // ignore: avoid_print
      print('--- paragraph[$i] ---');
      // ignore: avoid_print
      print(paragraphs[i]);
    }
  });
}
