import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/features/shrine/data/models.dart';
import 'package:flutter_app/features/shrine/screens/screens_v3.dart';
import 'package:flutter_app/features/shrine/shrine_module.dart' show shrine;
import 'package:flutter_app/features/shrine/state/shrine_session_provider.dart';
import 'package:flutter_app/features/shrine/widgets/bujeok.dart' show BujeokLayout;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    shrine = await Shrine.load();
    final raw = jsonDecode(await rootBundle.loadString('assets/shrine/data/shrine.json')) as Map;
    BujeokLayout.init(raw['bujeokLayout']);
  });

  testWidgets('debug', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final provider = ShrineSessionProvider(prefs);

    String longestType = '';
    var longestLen = -1;
    for (final entry in shrine.talismans.copy.entries) {
      final line = (entry.value as Map)['line'] as String? ?? '';
      if (line.length > longestLen) { longestLen = line.length; longestType = entry.key as String; }
    }
    var longestTaleId = shrine.tales.keys.first;
    var longestTaleLen = -1;
    for (final e in shrine.tales.entries) {
      final len = e.value.title.length;
      if (len > longestTaleLen) { longestTaleLen = len; longestTaleId = e.key; }
    }

    final spec = shrine.talismans.compose(type: longestType, flavor: 'observe', story: longestTaleId, ending: 'A');
    provider.update((s) => s.copy(box: [
      BoxItem(key: spec.key, no: 'N°0001', date: '2026-01-01', spec: spec, source: StorySource(longestTaleId, 'A')),
    ]));

    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final errors = <FlutterErrorDetails>[];
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) { errors.add(details); };

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(360, 640), textScaler: TextScaler.linear(1.0)),
        child: ChangeNotifierProvider<ShrineSessionProvider>.value(
          value: provider,
          child: const MaterialApp(home: BoxScreen()),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byType(GestureDetector).first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    final detailButton = find.text('상세 · 저장');
    if (detailButton.evaluate().isNotEmpty) {
      await tester.tap(detailButton);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
    }

    FlutterError.onError = originalOnError;
    for (final e in errors) {
      print('=== ERROR ===');
      print(e.toString());
    }
    print('ERROR COUNT: ${errors.length}');
  });
}
