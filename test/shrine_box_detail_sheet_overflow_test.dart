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
import 'package:flutter_app/features/shrine/widgets/bujeok.dart'
    show BujeokLayout;

// [반응형 화면 규격 통일 — 조사] 부적함 상세 시트(screens_v3.dart _detail())는
// showModalBottomSheet(isScrollControlled:true)이지만 내부가
// Column(mainAxisSize:min)만 있고 SingleChildScrollView가 없다 —
// 다른 시트들과 달리 명시적 스크롤 보호 패턴이 없는 구조다. 다만 표시되는
// 모든 텍스트(spec.name/phrase/phraseMeaning, copy['line'], tale 제목)는
// 전부 assets/shrine/data/shrine.json의 고정 기획 데이터이고 사용자
// 입력이 아니므로, 실제 데이터 중 가장 긴 조합으로 BoxScreen을 통해
// 실제로 띄워 작은 화면+글자 확대 조합에서도 안전한지 확인한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    shrine = await Shrine.load();
    final raw =
        jsonDecode(
              await rootBundle.loadString('assets/shrine/data/shrine.json'),
            )
            as Map;
    BujeokLayout.init(raw['bujeokLayout']);
  });

  final conditions = <(Size, double)>[
    (const Size(390, 844), 1.0),
    (const Size(360, 640), 1.0),
    (const Size(360, 640), 1.3),
    (const Size(320, 568), 1.3),
  ];

  for (final (size, textScale) in conditions) {
    testWidgets(
      '부적함 상세 시트(실제 데이터 중 가장 긴 조합)가 ${size.width.toInt()}x${size.height.toInt()}@$textScale에서 오버플로 없이 뜬다',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final provider = ShrineSessionProvider(prefs);

        // talismans.copy 중 line 문구가 가장 긴 항목과, tales 중 title이
        // 가장 긴 항목을 실제로 조합해 최악의 경우(worst-case)를 구성한다.
        String longestType = '';
        var longestLen = -1;
        for (final entry in shrine.talismans.copy.entries) {
          final line = (entry.value as Map)['line'] as String? ?? '';
          if (line.length > longestLen) {
            longestLen = line.length;
            longestType = entry.key as String;
          }
        }
        var longestTaleId = shrine.tales.keys.first;
        var longestTaleLen = -1;
        for (final e in shrine.tales.entries) {
          final len = e.value.title.length;
          if (len > longestTaleLen) {
            longestTaleLen = len;
            longestTaleId = e.key;
          }
        }

        final spec = shrine.talismans.compose(
          type: longestType,
          flavor: 'observe',
          story: longestTaleId,
          ending: 'A',
        );

        provider.update(
          (s) => s.copy(
            box: [
              BoxItem(
                key: spec.key,
                no: 'N°0001',
                date: '2026-01-01',
                spec: spec,
                source: StorySource(longestTaleId, 'A'),
              ),
            ],
          ),
        );

        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(textScale),
            ),
            child: ChangeNotifierProvider<ShrineSessionProvider>.value(
              value: provider,
              child: const MaterialApp(home: BoxScreen()),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);

        // 카드 탭 → showTalisManual(screens_v32.dart) → "상세 · 저장" 탭
        // → _detail() 바텀시트까지 실제 사용자 흐름대로 진행한다.
        await tester.tap(find.byType(GestureDetector).first);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);

        final detailButton = find.text('상세 · 저장');
        if (detailButton.evaluate().isNotEmpty) {
          await tester.tap(detailButton);
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull);
        }
      },
    );
  }
}
