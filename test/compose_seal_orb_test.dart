import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/wishroom/features/compose/compose_screen.dart';

/// [소원빛깔 → 인장 교체 — 사용자 지시 2026-10-14]
/// 빛깔을 누르면 붉은 인장이 사라지고 그 빛깔 구슬(한자 각인)이 그 자리에
/// 들어간다. 기본 상태는 붉은 '願' 인장 유지.
void main() {
  testWidgets('기본 상태에서는 붉은 願 인장이 보인다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: WrSealOrOrb(picked: false))),
      ),
    );
    expect(find.text('願'), findsOneWidget);
    expect(tester.takeException(), null);
  });

  testWidgets('빛깔을 누른 뒤에는 인장이 사라지고 그 빛깔의 한자 구슬로 바뀐다', (tester) async {
    const kang = {'hanja': '康', 'color': '#4CAF6D', 'deep': '#2E7D4F'};
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: WrSealOrOrb(picked: true, color: kang)),
        ),
      ),
    );
    expect(find.text('康'), findsOneWidget);
    expect(find.text('願'), findsNothing);
    expect(tester.takeException(), null);
  });
}
