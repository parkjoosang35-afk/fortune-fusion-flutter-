import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/features/home/data/jeontong_profile_store.dart';
import 'package:flutter_app/features/home/domain/jeontong_input.dart';
import 'package:flutter_app/features/home/domain/jeontong_report_cache.dart';
import 'package:flutter_app/features/home/domain/saju_fortune_rules.dart';
import 'package:flutter_app/features/home/domain/saju_interpreter.dart';
import 'package:flutter_app/features/home/presentation/jeontong_eighty_result_screen.dart';

Future<void> _pumpUntilLoaded(WidgetTester tester) async {
  var guard = 0;
  while (find.byType(CircularProgressIndicator).evaluate().isNotEmpty &&
      guard < 30) {
    await tester.pump(const Duration(milliseconds: 50));
    guard++;
  }
}

void main() {
  testWidgets('probe A07 screen text order', (tester) async {
    SajuRules.resetForTest();
    SajuFortuneRules.resetForTest();
    await SajuRules.preload();
    await SajuFortuneRules.preload();
    jeontongReportCache.clear();
    SharedPreferences.setMockInitialValues({});
    jeontongProfileStore.clearForTest();
    await jeontongProfileStore.save(
      '1',
      JeontongInput(
        birthDateTimeLocal: DateTime(1990, 5, 12, 10, 30),
        gender: 'male',
        isLunar: false,
        name: '박주상',
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: JeontongEightyResultScreen(categoryId: 'A07'),
      ),
    );
    await _pumpUntilLoaded(tester);
    await tester.pumpAndSettle();

    final texts = find
        .byType(Text)
        .evaluate()
        .map((e) => (e.widget as Text).data ?? '')
        .where((s) => s.trim().isNotEmpty)
        .toList();
    for (var i = 0; i < texts.length; i++) {
      // ignore: avoid_print
      print('[$i] ${texts[i]}');
    }
  });
}
