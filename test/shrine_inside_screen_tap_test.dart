// shrine_inside_screen_tap_test.dart — 회귀 테스트: 신당 내부(堂內) 화면
// "화면 어디든 눌러 다가가기" 전체화면 탭 → talk 전환 버그 방지.
//
// 과거 버그: background 2번째 레이어(비네트 RadialGradient DecoratedBox)가
// IgnorePointer 없이 Positioned.fill로 전체 화면을 덮고 있었다.
// BoxDecoration.hitTest()는 shape가 rectangle이고 borderRadius가 없으면
// 항상 true를 반환하므로(Flutter box_decoration.dart), Stack의 히트테스트
// (역순 순회, 첫 히트에서 중단 — RenderBoxContainerDefaultsMixin
// .defaultHitTestChildren)가 이 레이어에서 멈춰버려 그 아래 배경
// GestureDetector(실제 onTap)까지 탭 이벤트가 전달되지 않았다.
// 수정: 해당 DecoratedBox를 IgnorePointer로 감싼다(shrine_inside_screen.dart).
// 이 테스트는 화면의 서로 다른 지점을 탭해 talk 화면으로 정상 전환되는지
// 검증해 재발을 방지한다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/features/shrine/application/shrine_session_provider.dart';
import 'package:flutter_app/features/shrine/presentation/screens/shrine_inside_screen.dart';
import 'package:flutter_app/features/shrine/presentation/screens/shrine_talk_screen.dart';

void main() {
  testWidgets('shrine inside screen: tap anywhere navigates to talk screen', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ShrineSessionProvider(),
        child: const MaterialApp(home: ShrineInsideScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 상단 영역(탭 유도 아이콘/텍스트 바깥) 탭 — 실제 사용자 시나리오 재현
    await tester.tapAt(const Offset(400, 150));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200)); // 1.1s 크로스페이드 완료 대기

    expect(find.byType(ShrineTalkScreen), findsOneWidget);
  });

  testWidgets('shrine inside screen: tap near bottom text area also navigates', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ShrineSessionProvider(),
        child: const MaterialApp(home: ShrineInsideScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tapAt(const Offset(400, 50));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.byType(ShrineTalkScreen), findsOneWidget);
  });
}
