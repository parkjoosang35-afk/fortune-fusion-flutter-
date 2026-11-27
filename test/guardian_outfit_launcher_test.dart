import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/wishroom/features/compose/compose_screen.dart';

/// [수호자 문구 클릭 — 사용자 지시 2026-10-14]
/// 문구가 "함께할 수호자 및 자유의상 입어요"로 보이고, 탭하면 다른 화면으로
/// 넘어갔다가 돌아온 뒤 onTap의 비동기 뒷부분(복귀 갱신 지점)이 실행되는지 검증.
void main() {
  testWidgets('문구가 함께할 수호자 및 자유의상 입어요로 보이고 탭하면 콜백이 실행된다', (tester) async {
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

  testWidgets('탭 → 다른 화면 이동 → 복귀 시 onTap의 비동기 뒷부분이 실행된다', (tester) async {
    var pushed = false;
    var returned = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (hostContext) => Scaffold(
            body: Center(
              child: WrGuardianOutfitLauncher(
                onTap: () async {
                  pushed = true;
                  final result = await Navigator.of(hostContext).push<bool>(
                    MaterialPageRoute<bool>(
                      builder: (routeContext) => Scaffold(
                        body: TextButton(
                          onPressed: () => Navigator.pop(routeContext, true),
                          child: const Text('복귀'),
                        ),
                      ),
                    ),
                  );
                  if (result == true) returned = true;
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('함께할 수호자 및 자유의상 입어요'));
    await tester.pumpAndSettle();
    expect(pushed, isTrue);
    await tester.tap(find.text('복귀'));
    await tester.pumpAndSettle();
    expect(returned, isTrue);
    expect(find.text('함께할 수호자 및 자유의상 입어요'), findsOneWidget);
    expect(tester.takeException(), null);
  });
}
