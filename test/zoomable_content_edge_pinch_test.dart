// [확대 회귀 방지 테스트 #2 — 실제 기기 신고와 동일한 조건]
//
// 실기기 신고: "확대가 안 되고 / 확대가 바로 원래대로 돌아간다"
//
// 실제 사용자는 콘텐츠(이미지·도식)의 정확한 픽셀 위에 두 손가락을
// 올리지 않는다. 손가락 하나는 콘텐츠 밖 여백에 찍히는 경우가 흔하다.
// 그때 InteractiveViewer가 "콘텐츠 크기만큼"만 차지하고 있으면 두 번째
// 손가락이 InteractiveViewer에 전달되지 않아 핀치가 성립하지 않는다.
//
// 이 테스트는 일부러 한 손가락을 콘텐츠 밖에 찍어서 확대가 되는지 본다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/core/widgets/zoomable_content.dart';

void main() {
  Future<TransformationController> openFullScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ZoomableContent(
              heroTag: 'hero-small',
              // 일부러 아주 작은 콘텐츠 — 실제 도식/작은 카드와 동일한 조건
              child: const SizedBox(
                width: 100,
                height: 100,
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
    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    return viewer.transformationController!;
  }

  testWidgets('손가락 하나가 콘텐츠 밖 여백에 찍혀도 핀치 확대가 된다', (tester) async {
    final controller = await openFullScreen(tester);

    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    final center = Offset(screen.width / 2, screen.height / 2);

    // 두 손가락이 콘텐츠(100x100) 밖, 화면 안쪽에 찍히도록 크게 벌려서 시작
    final g1 = await tester.startGesture(center - const Offset(130, 0));
    final g2 = await tester.startGesture(center + const Offset(130, 0));
    await tester.pump();

    for (var i = 0; i < 8; i++) {
      await g1.moveBy(const Offset(-14, 0));
      await g2.moveBy(const Offset(14, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }

    final during = controller.value.getMaxScaleOnAxis();
    expect(
      during,
      greaterThan(1.2),
      reason:
          '손가락이 콘텐츠 밖에서 시작해도 확대돼야 한다. '
          '실패 = InteractiveViewer가 화면 전체를 덮고 있지 않아 '
          '두 번째 손가락을 받지 못한 것. 배율=$during',
    );

    await g1.up();
    await tester.pump(const Duration(milliseconds: 50));
    await g2.up();
    await tester.pumpAndSettle();

    expect(find.byType(InteractiveViewer), findsOneWidget, reason: '핀치 후 화면이 닫히면 안 된다');
    expect(
      controller.value.getMaxScaleOnAxis(),
      closeTo(during, 0.001),
      reason: '손을 뗀 뒤에도 배율이 유지돼야 한다',
    );
  });

  testWidgets('전체화면 뷰에서 여백 아무 곳을 탭해도 화면이 닫히지 않는다', (tester) async {
    await openFullScreen(tester);

    // 화면 여백을 탭해본다 (우상단 X 닫기 버튼 영역은 제외 — 그건 닫히는 게 정상)
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    for (final p in <Offset>[
      const Offset(10, 10),
      Offset(10, screen.height / 2),
      Offset(10, screen.height - 10),
      Offset(screen.width - 10, screen.height - 10),
      Offset(screen.width / 2, 40),
      Offset(screen.width / 2, screen.height / 2),
    ]) {
      await tester.tapAt(p);
      await tester.pumpAndSettle();
      expect(
        find.byType(InteractiveViewer),
        findsOneWidget,
        reason: '여백 탭($p)으로 확대 화면이 닫혔다 — 핀치 후 잔여 탭에도 닫힌다',
      );
    }
  });
}
