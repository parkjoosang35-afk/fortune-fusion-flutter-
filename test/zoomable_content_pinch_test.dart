// [확대(Pinch Zoom) 회귀 방지 테스트]
//
// 사용자 신고 원문:
//   "확대를 하면 확대한 사항에서 그대로 있어야 하는데 바로 원상태로 돌아가"
//   "손으로 자기가 조절하고 확대한 크기가 그대로 머물러야지"
//   "어떤 행동을 취하면 원상으로 돌아오던지 그래야 되는 것 아니야"
//
// 즉 요구사항은 3가지다.
//   R1. 두 손가락으로 확대가 실제로 된다.
//   R2. 손가락을 떼도 확대 배율이 그대로 유지된다.
//   R3. 명시적 조작(닫기 버튼 등)으로만 원래대로 돌아간다.
//       → 손가락을 하나씩 떼는 과정의 잔여 탭으로 화면이 닫히면 안 된다.
//
// 이 테스트는 위 3가지를 실제 두 손가락 제스처 주입으로 검증한다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/core/widgets/zoomable_content.dart';

/// 전체화면 뷰를 연다. (InteractiveViewer에는 transformationController가
/// 넘어가지 않으므로, 배율은 위젯 트리의 Transform 행렬에서 직접 읽는다.)
Future<void> _openFullScreen(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: ZoomableContent(
            // 실제 사용 조건과 동일하게 "작은" 콘텐츠를 쓴다.
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
}

/// InteractiveViewer 내부 Transform 행렬에서 현재 최대 배율을 읽는다.
double? _currentScale(WidgetTester tester) {
  if (find.byType(InteractiveViewer).evaluate().isEmpty) return null;
  final transforms = tester.widgetList<Transform>(
    find.descendant(
      of: find.byType(InteractiveViewer),
      matching: find.byType(Transform),
    ),
  );
  double? max;
  for (final t in transforms) {
    final v = t.transform.getMaxScaleOnAxis();
    if (max == null || v > max) max = v;
  }
  return max;
}

/// 화면 중앙을 기준으로 두 손가락을 [dx]만큼 벌린다.
/// [startHalfGap]은 처음 두 손가락 사이 거리의 절반이다.
/// 이 값이 콘텐츠(100x100) 밖이면 "손가락 하나가 여백에 찍힌" 실제 상황이 된다.
Future<void> _pinchOut(
  WidgetTester tester, {
  required double startHalfGap,
  int steps = 8,
  double step = 14,
}) async {
  final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
  final center = Offset(screen.width / 2, screen.height / 2);

  final g1 = await tester.startGesture(center - Offset(startHalfGap, 0));
  final g2 = await tester.startGesture(center + Offset(startHalfGap, 0));
  await tester.pump();

  for (var i = 0; i < steps; i++) {
    await g1.moveBy(Offset(-step, 0));
    await g2.moveBy(Offset(step, 0));
    await tester.pump(const Duration(milliseconds: 16));
  }

  // 사용자 신고 상황 그대로: 손가락을 하나씩 뗀다.
  await g1.up();
  await tester.pump(const Duration(milliseconds: 50));
  await g2.up();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('R1+R2: 콘텐츠 안에서 핀치하면 확대되고, 손을 떼도 배율이 유지된다', (
    tester,
  ) async {
    await _openFullScreen(tester);
    expect(_currentScale(tester), closeTo(1.0, 0.001), reason: '진입 직후 배율은 1.0');

    await _pinchOut(tester, startHalfGap: 40);

    expect(
      find.byType(InteractiveViewer),
      findsOneWidget,
      reason: 'R3 위반: 핀치 후 화면이 닫혔다 (잔여 탭으로 배경 닫기가 실행됨)',
    );
    final scale = _currentScale(tester)!;
    expect(
      scale,
      greaterThan(1.2),
      reason: 'R2 위반: 손을 뗀 뒤 배율이 되돌아갔다. 배율=$scale',
    );
  });

  testWidgets('R1: 손가락 하나가 콘텐츠 밖 여백에 찍혀도 핀치 확대가 된다', (tester) async {
    await _openFullScreen(tester);

    // 두 손가락 모두 화면 안쪽, 그러나 콘텐츠(100x100)보다 훨씬 바깥에서 시작.
    await _pinchOut(tester, startHalfGap: 140);

    final scale = _currentScale(tester) ?? 1.0;
    expect(
      scale,
      greaterThan(1.2),
      reason:
          'R1 위반: 여백에서 시작한 손가락이 InteractiveViewer에 전달되지 않아 '
          '핀치가 성립하지 않았다. 배율=$scale',
    );
  });

  testWidgets('R3: 여백을 탭해도 확대 화면이 닫히지 않는다', (tester) async {
    await _openFullScreen(tester);
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;

    // 우상단은 닫기(X) 버튼이므로 제외. 나머지 여백을 탭해본다.
    for (final p in <Offset>[
      const Offset(8, 8),
      Offset(8, screen.height / 2),
      Offset(8, screen.height - 8),
      Offset(screen.width - 8, screen.height - 8),
      Offset(screen.width / 2, 30),
    ]) {
      await tester.tapAt(p);
      await tester.pumpAndSettle();
      expect(
        find.byType(InteractiveViewer),
        findsOneWidget,
        reason: 'R3 위반: 여백($p) 탭으로 확대 화면이 닫혔다',
      );
    }
  });

  testWidgets('R3: 확대 후에도 닫기 버튼으로는 정상적으로 닫힌다', (tester) async {
    await _openFullScreen(tester);
    await _pinchOut(tester, startHalfGap: 40);

    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(
      find.byType(InteractiveViewer),
      findsNothing,
      reason: '닫기 버튼은 확대 상태에서도 정상 동작해야 한다',
    );
  });
}
