// [신통방통 전역 핀치 확대 시스템 통합 개발 지시서 §9 ⑥⑦⑨ 자동화 검증]
//
// 안드로이드 실기기 멀티터치 테스트는 이 개발 샌드박스 환경에서 물리적으로
// 수행할 수 없다. 대신 `WidgetTester.createGesture()`로 다중 포인터를
// 프로그래밍적으로 시뮬레이션해, 코드 레벨에서 검증 가능한 범위의 핵심
// 요구사항(1손가락 입력 완전 보존, 2손가락 핀치 시작/종료, 제외 구역,
// 배율 클램프, 경계 클램프, 반복 확대 시 리소스 해제)을 자동화 테스트로
// 확인한다. 이 테스트 통과가 "실기기 테스트를 대체한다"는 뜻은 아니며,
// 최종 보고서에서 그 한계를 별도로 명시한다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/core/zoom/global_pinch_zoom_manager.dart';
import 'package:flutter_app/core/zoom/pinch_zoom_boundary_controller.dart';
import 'package:flutter_app/core/zoom/pinch_zoom_exclusion.dart';
import 'package:flutter_app/core/zoom/pinch_zoom_transform_controller.dart';

/// 테스트용 더미 화면 — 버튼(탭), 스크롤 리스트, 제외 구역(WebView
/// 자리)을 모두 포함해 전역 핀치 오버레이 아래에서도 기존 기능이
/// 그대로 동작하는지 확인한다.
class _DummyScreen extends StatefulWidget {
  const _DummyScreen();

  @override
  State<_DummyScreen> createState() => _DummyScreenState();
}

class _DummyScreenState extends State<_DummyScreen> {
  int tapCount = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          ElevatedButton(
            key: const Key('dummy_button'),
            onPressed: () => setState(() => tapCount++),
            child: Text('tapped:$tapCount'),
          ),
          Expanded(
            child: ListView.builder(
              key: const Key('dummy_list'),
              itemCount: 50,
              itemBuilder: (context, index) => SizedBox(
                height: 60,
                child: Text('item $index'),
              ),
            ),
          ),
          PinchZoomDisabled(
            child: Container(
              key: const Key('excluded_region'),
              height: 100,
              color: Colors.black12,
              child: const Center(child: Text('webview placeholder')),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => GlobalPinchZoomOverlay(child: child!),
      home: const _DummyScreen(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('GlobalPinchZoomOverlay — 1손가락 입력 완전 보존(회귀 방지)', () {
    testWidgets('버튼 탭은 전역 핀치 오버레이 삽입 후에도 정상 동작한다', (tester) async {
      await _pumpApp(tester);

      expect(find.text('tapped:0'), findsOneWidget);
      await tester.tap(find.byKey(const Key('dummy_button')));
      await tester.pumpAndSettle();
      expect(find.text('tapped:1'), findsOneWidget);

      // 반복 탭에도 문제 없어야 한다(핀치 리스너가 상태를 오염시키지
      // 않는지 확인).
      await tester.tap(find.byKey(const Key('dummy_button')));
      await tester.tap(find.byKey(const Key('dummy_button')));
      await tester.pumpAndSettle();
      expect(find.text('tapped:3'), findsOneWidget);
    });

    testWidgets('한 손가락 스크롤(드래그)은 전역 핀치 오버레이 삽입 후에도 정상 동작한다', (
      tester,
    ) async {
      await _pumpApp(tester);

      expect(find.text('item 0'), findsOneWidget);
      await tester.drag(find.byKey(const Key('dummy_list')), const Offset(0, -500));
      await tester.pumpAndSettle();
      // 스크롤이 실제로 일어났다면 item 0은 더 이상 보이지 않아야 한다.
      expect(find.text('item 0'), findsNothing);
    });
  });

  group('GlobalPinchZoomOverlay — 2손가락 핀치 확대/축소', () {
    testWidgets('두 손가락 핀치 시작 시 확대 오버레이(RawImage)가 나타나고, 손을 떼면 사라진다', (
      tester,
    ) async {
      await _pumpApp(tester);

      final center = tester.getCenter(find.byKey(const Key('dummy_list')));
      final posA = center + const Offset(-40, 0);
      final posB = center + const Offset(40, 0);

      final gestureA = await tester.createGesture(pointer: 1);
      final gestureB = await tester.createGesture(pointer: 2);

      await gestureA.down(posA);
      await gestureB.down(posB);
      // 화면 캡처는 비동기(toImage)이므로 몇 프레임 기다려준다.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        find.byType(RawImage),
        findsOneWidget,
        reason: '2손가락이 닿으면 화면 캡처 기반 확대 오버레이가 떠야 한다',
      );

      // 손가락을 벌려 확대 배율을 키운다.
      await gestureA.moveTo(center + const Offset(-80, 0));
      await gestureB.moveTo(center + const Offset(80, 0));
      await tester.pump();

      // 손가락 하나를 떼면 핀치가 즉시 종료되어야 한다("터치 종료 시
      // 상태 복구" 요구사항) — 리셋 애니메이션 종료까지 pumpAndSettle.
      await gestureA.up();
      await gestureB.up();
      await tester.pumpAndSettle();

      expect(
        find.byType(RawImage),
        findsNothing,
        reason: '손가락을 떼면 확대 오버레이가 사라지고 원래 화면으로 복귀해야 한다',
      );
    });

    testWidgets('반복적인 확대·축소 후에도 예외 없이 안정적으로 동작한다(메모리 누수 방지 점검)', (
      tester,
    ) async {
      await _pumpApp(tester);
      final center = tester.getCenter(find.byKey(const Key('dummy_list')));

      for (var i = 0; i < 5; i++) {
        final gestureA = await tester.createGesture(pointer: 10 + i * 2);
        final gestureB = await tester.createGesture(pointer: 11 + i * 2);
        await gestureA.down(center + const Offset(-30, 0));
        await gestureB.down(center + const Offset(30, 0));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 30));
        await gestureA.moveTo(center + const Offset(-70, 20));
        await gestureB.moveTo(center + const Offset(70, -20));
        await tester.pump();
        await gestureA.up();
        await gestureB.up();
        await tester.pumpAndSettle();
      }

      // 5회 반복 후에도 오버레이가 깨끗하게 해제되어 있고(이미지 잔존
      // 없음) 앱이 계속 정상 렌더링됨을 확인한다.
      expect(find.byType(RawImage), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('제외 구역(PinchZoomDisabled) 위에서 시작한 핀치는 전역 확대를 켜지 않는다', (
      tester,
    ) async {
      await _pumpApp(tester);

      final center = tester.getCenter(find.byKey(const Key('excluded_region')));
      final gestureA = await tester.createGesture(pointer: 20);
      final gestureB = await tester.createGesture(pointer: 21);
      await gestureA.down(center + const Offset(-20, 0));
      await gestureB.down(center + const Offset(20, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        find.byType(RawImage),
        findsNothing,
        reason: 'WebView/광고 등 제외 구역 위의 2손가락 입력은 전역 확대를 켜면 안 된다',
      );

      await gestureA.up();
      await gestureB.up();
      await tester.pumpAndSettle();
    });
  });

  group('PinchZoomTransformController — 배율 클램프(어뷰징 방지) 단위 테스트', () {
    test('rawScale이 maxScale을 초과해도 결과 scale은 maxScale을 넘지 않는다', () {
      final controller = PinchZoomTransformController(
        minScale: 1.0,
        maxScale: 3.0,
      );
      controller.start(Offset.zero, const Offset(10, 0));
      // 거리를 100배로 벌려 극단적인 rawScale(100.0)을 유발한다.
      controller.update(Offset.zero, const Offset(1000, 0));
      expect(controller.scale, 3.0);
    });

    test('rawScale이 minScale 밑으로 내려가도 결과 scale은 minScale 밑으로 내려가지 않는다', () {
      final controller = PinchZoomTransformController(
        minScale: 1.0,
        maxScale: 3.0,
      );
      controller.start(Offset.zero, const Offset(100, 0));
      controller.update(Offset.zero, const Offset(1, 0));
      expect(controller.scale, 1.0);
    });

    test('두 손가락이 완전히 겹치는 비정상 입력은 안전하게 무시된다(0으로 나누기 방지)', () {
      final controller = PinchZoomTransformController();
      controller.start(Offset.zero, Offset.zero);
      expect(() => controller.update(const Offset(5, 5), const Offset(5, 5)), returnsNormally);
    });
  });

  group('PinchZoomBoundaryController — 경계 제한(무한 이동 방지) 단위 테스트', () {
    const controller = PinchZoomBoundaryController();

    test('scale이 1.0 이하(평상시)면 이동량은 항상 0이다', () {
      final result = controller.clamp(
        translation: const Offset(500, 500),
        viewportSize: const Size(300, 600),
        scale: 1.0,
      );
      expect(result, Offset.zero);
    });

    test('확대 중 과도한 이동은 뷰포트 기반 허용 범위 안으로 잘린다', () {
      final result = controller.clamp(
        translation: const Offset(10000, -10000),
        viewportSize: const Size(300, 600),
        scale: 2.0,
      );
      final maxOverflowX = 300 * (2.0 - 1) / 2;
      final maxOverflowY = 600 * (2.0 - 1) / 2;
      expect(result.dx, maxOverflowX);
      expect(result.dy, -maxOverflowY);
    });
  });

  group('PinchZoomExclusionRegistry', () {
    testWidgets('등록된 위젯 좌표 범위는 isExcluded가 true를 반환한다', (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PinchZoomDisabled(
                child: SizedBox(key: key, width: 100, height: 100),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final center = tester.getCenter(find.byKey(key));
      expect(PinchZoomExclusionRegistry.instance.isExcluded(center), isTrue);
      expect(
        PinchZoomExclusionRegistry.instance.isExcluded(const Offset(-9999, -9999)),
        isFalse,
      );
    });
  });
}
