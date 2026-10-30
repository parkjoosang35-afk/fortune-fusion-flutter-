// [신통방통 앱 반응형 화면 규격 통일] 부적 설명서(showTalisManual /
// _TalisManual) 안전 확인 테스트.
//
// 이 시트는 이미 ConstrainedBox(maxHeight: 화면높이*.88) +
// SingleChildScrollView + Column(mainAxisSize: min) 패턴과, Row 안
// 설명 텍스트를 Expanded로 감싸는 패턴을 모두 올바르게 쓰고 있어
// 구조적으로 안전해 보였다. 실제 좁은 화면·글자 확대·3개 탭(what/use/
// end) 전환 조합에서도 오버플로가 없는지 실측으로 확인한다.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/features/shrine/data/models.dart';
import 'package:flutter_app/features/shrine/screens/screens_v32.dart' show showTalisManual;
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

  final conditions = <(Size, double)>[
    (const Size(390, 844), 1.0),
    (const Size(360, 640), 1.0),
    (const Size(320, 568), 1.0),
    (const Size(320, 568), 1.3),
  ];

  for (final (size, textScale) in conditions) {
    testWidgets('부적 설명서(showTalisManual) 3개 탭이 ${size.width.toInt()}x${size.height.toInt()}@$textScale 에서 오버플로 없이 표시된다', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final provider = ShrineSessionProvider(prefs);
      final spec = shrine.talismans.compose(type: 'fate', flavor: 'observe', story: 'room', ending: 'A');
      final item = BoxItem(key: spec.key, no: 'N°0001', date: '2026-01-01', spec: spec, source: const StorySource('room', 'A'));
      provider.update((s) => s.copy(box: [item]));

      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
          child: ChangeNotifierProvider<ShrineSessionProvider>.value(
            value: provider,
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => showTalisManual(context, spec: spec, item: item, actions: [
                      ('名', '이름 표시', () {}),
                      ('詳', '상세 · 저장', () {}),
                    ]),
                    child: const Text('열기'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // 3개 탭을 모두 전환해 가며 검증 — '어떤 부적'(what)이 기본.
      for (final tabLabel in ['간직하는 법', '삼갈 것 · 보내는 법', '어떤 부적']) {
        final tabFinder = find.text(tabLabel);
        if (tabFinder.evaluate().isNotEmpty) {
          await tester.tap(tabFinder);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      }
    });
  }
}
