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

  for (final size in [Size(390, 844), Size(360, 640), Size(320, 568)]) {
    testWidgets('typical data at $size', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final provider = ShrineSessionProvider(prefs);

      // 평범한(가장 흔한) 타입/이야기 조합 — 'fate' + 'room'.
      final spec = shrine.talismans.compose(type: 'fate', flavor: 'observe', story: 'room', ending: 'A');
      provider.update((s) => s.copy(box: [
        BoxItem(key: spec.key, no: 'N°0001', date: '2026-01-01', spec: spec, source: const StorySource('room', 'A')),
      ]));

      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final errors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) { errors.add(details); };

      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: size, textScaler: const TextScaler.linear(1.0)),
          child: ChangeNotifierProvider<ShrineSessionProvider>.value(
            value: provider,
            child: const MaterialApp(home: BoxScreen()),
          ),
        ),
      );
      await tester.pump();

      FlutterError.onError = originalOnError;
      print('=== $size ERROR COUNT: ${errors.length} ===');
      for (final e in errors) {
        print(e.toString().split('\n').take(4).join('\n'));
      }
    });
  }
}
