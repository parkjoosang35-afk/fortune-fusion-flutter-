// [신통방통 앱 반응형 화면 규격 통일] 신당 LifePanel(수명 카드) + 보내기
// 확인 다이얼로그 안전 확인 테스트.
//
// LifePanel은 Row(Expanded) 구조를 이미 올바르게 쓰고 있어(이름/설명
// Column이 Expanded로 감싸져 있음) 구조적으로 안전해 보였으나, 실제
// 좁은 화면·글자 확대 조합에서도 오버플로가 없는지 실측으로 확인한다.
// _send()의 AlertDialog(보내 드리겠습니까?)도 함께 검증.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/features/shrine/engine/shrine_engine.dart';
import 'package:flutter_app/features/shrine/state/shrine_session_provider.dart';
import 'package:flutter_app/features/shrine/widgets/life_panel.dart';

const _spec = TalismanSpec(
  key: 'test-key',
  type: 'money',
  flavor: 'calm',
  sig: 'sig-1',
  name: '재물운 부적',
  head: 'head',
  base: 'base',
  paper: 'paper',
  phrase: 'phrase',
  phraseMeaning: 'phrase meaning',
  motif: 'motif',
  border: 'border',
  seal: 'seal',
  designId: 'design-1',
);

void main() {
  final conditions = <(Size, double)>[
    (const Size(390, 844), 1.0),
    (const Size(360, 640), 1.0),
    (const Size(320, 568), 1.0),
    (const Size(320, 568), 1.3),
  ];

  for (final (size, textScale) in conditions) {
    testWidgets('LifePanel + 보내기 확인 다이얼로그가 ${size.width.toInt()}x${size.height.toInt()}@$textScale 에서 오버플로 없이 표시된다', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final provider = ShrineSessionProvider(prefs);
      // '소멸(gone)' 상태로 두면 '보내기' 버튼까지 함께 노출되어 더 넓은 범위를 검증한다.
      final item = BoxItem(
        key: _spec.key,
        no: 'N°0001',
        date: '2026-01-01',
        spec: _spec,
        source: const StorySource('room', 'A'),
        tendDays: const [],
      );
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
              home: Scaffold(body: SingleChildScrollView(child: LifePanel(item: item))),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);

      // '火 보내 드리기' 버튼이 있으면 탭해 확인 다이얼로그도 검증한다
      // (gone 상태가 아니면 버튼이 없을 수 있으므로 존재할 때만 수행).
      final sendBtn = find.textContaining('보내 드리기');
      if (sendBtn.evaluate().isNotEmpty) {
        await tester.tap(sendBtn.first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('보내 드리겠습니까?'), findsOneWidget);
        // 버튼이 항상 탭 가능해야 한다 — '그만두기'를 눌러 닫아본다.
        await tester.tap(find.text('그만두기'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }
}
