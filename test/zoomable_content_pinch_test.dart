// [확대 회귀 방지 테스트]
//
// 실기기에서 "핀치 확대가 아예 안 된다"는 신고가 두 번 반복됐다.
// 원인은 코드 리뷰로는 보이지 않았다 — InteractiveViewer를 GestureDetector
// (onScale*)로 감싸면 Flutter 제스처 아레나에서 바깥 위젯이 이겨서
// 핀치 이벤트가 InteractiveViewer까지 도달하지 못한다. 이 테스트는
// 실제 두 손가락 제스처를 주입해 확대가 "실제로 걸리는지"를 검증한다.
//
// 이 파일은 통과해야만 APK를 만들 수 있다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/core/widgets/zoomable_content.dart';

void main() {
  /// 전체화면 뷰를 연 뒤 두 손가락 핀치를 주입하고,
  /// 손을 뗀 "이후에도" 확대 배율이 유지되는지 확인한다.
  testWidgets('핀치 확대가 실제로 걸리고, 손을 뗀 뒤에도 배율이 유지된다', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ZoomableContent(
              heroTag: 'test-hero',
              child: const SizedBox(
                width: 120,
                height: 120,
                child: ColoredBox(color: Colors.amber),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1) 썸네일 탭 → 전체화면 뷰 진입
    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();

    final viewerFinder = find.byType(InteractiveViewer);
    expect(viewerFinder, findsOneWidget, reason: '전체화면에 InteractiveViewer가 있어야 한다');

    final viewer = tester.widget<InteractiveViewer>(viewerFinder);
    final controller = viewer.transformationController;
    expect(controller, isNotNull, reason: 'TransformationController가 연결돼야 배율을 검증할 수 있다');
    expect(
      controller!.value.getMaxScaleOnAxis(),
      closeTo(1.0, 0.001),
      reason: '진입 직후에는 배율 1.0',
    );

    // 2) 두 손가락 핀치아웃(벌리기) 주입
    final center = tester.getCenter(viewerFinder);
    final g1 = await tester.startGesture(center - const Offset(40, 0));
    final g2 = await tester.startGesture(center + const Offset(40, 0));
    await tester.pump();

    // 여러 단계로 벌린다(실제 핀치처럼)
    for (var i = 0; i < 8; i++) {
      await g1.moveBy(const Offset(-12, 0));
      await g2.moveBy(const Offset(12, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }

    final scaleDuringGesture = controller.value.getMaxScaleOnAxis();
    expect(
      scaleDuringGesture,
      greaterThan(1.2),
      reason:
          '핀치 중 배율이 커져야 한다. '
          '이게 실패하면 = 핀치 이벤트가 InteractiveViewer에 도달하지 못한 것 '
          '(제스처 아레나에서 다른 위젯이 가로챈 것). 배율=$scaleDuringGesture',
    );

    // 3) 손가락을 하나씩 뗀다 (원래 버그가 발생하던 정확한 상황)
    await g1.up();
    await tester.pump(const Duration(milliseconds: 50));
    await g2.up();
    await tester.pumpAndSettle();

    // 4) 손을 뗀 뒤에도 배율이 그대로여야 한다 + 화면이 닫히지 않아야 한다
    expect(
      find.byType(InteractiveViewer),
      findsOneWidget,
      reason: '핀치 후 손을 떼도 전체화면이 닫히면 안 된다',
    );
    final scaleAfterRelease = controller.value.getMaxScaleOnAxis();
    expect(
      scaleAfterRelease,
      closeTo(scaleDuringGesture, 0.001),
      reason:
          '손을 뗀 뒤 배율이 원래대로 돌아가면 안 된다. '
          '핀치중=$scaleDuringGesture / 뗀후=$scaleAfterRelease',
    );
    expect(
      scaleAfterRelease,
      greaterThan(1.2),
      reason: '손을 뗀 뒤에도 확대 상태가 유지돼야 한다',
    );
  });

  testWidgets('확대된 상태에서만 "원래대로" 버튼이 나타나고, 누르면 배율이 1.0으로 돌아간다', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ZoomableContent(
              heroTag: 'test-hero-2',
              child: const SizedBox(
                width: 120,
                height: 120,
                child: ColoredBox(color: Colors.amber),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();

    // 확대 전에는 버튼이 없어야 한다
    expect(find.text('원래대로'), findsNothing, reason: '확대 전에는 리셋 버튼이 뜨면 안 된다');

    final viewerFinder = find.byType(InteractiveViewer);
    final controller = tester
        .widget<InteractiveViewer>(viewerFinder)
        .transformationController!;

    final center = tester.getCenter(viewerFinder);
    final g1 = await tester.startGesture(center - const Offset(40, 0));
    final g2 = await tester.startGesture(center + const Offset(40, 0));
    await tester.pump();
    for (var i = 0; i < 8; i++) {
      await g1.moveBy(const Offset(-12, 0));
      await g2.moveBy(const Offset(12, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g1.up();
    await g2.up();
    await tester.pumpAndSettle();

    expect(controller.value.getMaxScaleOnAxis(), greaterThan(1.2));
    expect(find.text('원래대로'), findsOneWidget, reason: '확대 후에는 리셋 버튼이 보여야 한다');

    // 명시적 조작으로만 리셋된다
    await tester.tap(find.text('원래대로'));
    await tester.pumpAndSettle();
    expect(
      controller.value.getMaxScaleOnAxis(),
      closeTo(1.0, 0.001),
      reason: '리셋 버튼을 누르면 배율 1.0으로 돌아가야 한다',
    );
  });
}
