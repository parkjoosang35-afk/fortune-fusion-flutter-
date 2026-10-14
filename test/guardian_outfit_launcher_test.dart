import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/wishroom/features/compose/compose_screen.dart';

/// [수호자 문구 클릭 — 사용자 지시 2026-10-14]
/// 문구가 "함께할 수호자 및 자유의상 입어요"로 바뀌고, 탭하면
/// 캐릭터 화면으로 넘어가는 콜백이 실행되는지 검증한다.
void main() {
  testWidgets('문구가 함께할 수호자 및 자유의상 입어요로 보이고 탭하면 캐릭터로 넘어간다', (tester) async {
    var moved = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: WrGuardianOutfitLauncher(onTap: () => moved = true),
          ),
        ),
      ),
    );
    expect(find.text('함께할 수호자 및 자유의상 입어요'), findsOneWidget);
    await tester.tap(find.text('함께할 수호자 및 자유의상 입어요'));
    expect(moved, isTrue);
    expect(tester.takeException(), null);
  });
}
