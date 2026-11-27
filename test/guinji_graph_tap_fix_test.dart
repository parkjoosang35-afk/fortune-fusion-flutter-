// test/guinji_graph_tap_fix_test.dart
// [버그 수정 회귀 테스트] 귀인지도 H4 지도 화면에서 "별(얼굴 노드)을 탭해도
// 상세정보가 열리지 않는" 버그의 재발을 방지한다.
//
// 원인: GuinjiAnimatedRelationGraph의 GestureDetector가 onSelect 콜백 호출을
// onScaleEnd 블록 안에만 두고 있었다. Flutter 제스처 아레나 특성상 "이동
// 없는 단순 탭"에서는 onScaleStart/Update/End가 전혀 호출되지 않고 onTapUp만
// 호출되므로, 정적 탭으로는 onSelect가 절대 실행되지 않았다.
//
// 수정: onTapUp 핸들러에도 _hitTestNode 체크를 추가해, 단순 탭으로도 노드
// 선택 콜백이 호출되도록 했다.
import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/features/guinji/domain/guinji_person.dart';
import 'package:flutter_app/features/guinji/widgets/guinji_animated_graph.dart';
import 'package:flutter_app/features/guinji/widgets/guinji_layout.dart';

void main() {
  testWidgets(
    'GuinjiAnimatedRelationGraph: 정적 탭(이동 없음)만으로도 '
    'onSelect 콜백이 호출된다 (버그1 회귀 방지)',
    (tester) async {
      GuinjiPerson? selected;

      final people = [
        const GuinjiPerson(
          id: 'p1',
          name: '테스트지인',
          birth: '2000·01·01',
          ohaeng: 'mok',
          relation: 'CHEON_GWII', // guinjiTypeOrder 첫 번째(k=0, base=-90도).
          score: 88,
          note: '테스트',
          unlocked: true,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GuinjiAnimatedRelationGraph(
              people: people,
              onSelect: (p) => selected = p,
            ),
          ),
        ),
      );
      // 입장(entrance) 애니메이션 안정화 대기.
      // 주의: 그래프 내부에 무한 반복(repeat) 타임 컨트롤러가 있어
      // pumpAndSettle()은 타임아웃된다. 고정 시간만 흘려보낸다.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 1));

      // 그래프 위젯의 중심 근처를 "이동 없는" 단순 탭으로 누른다.
      // (tpPlace 배치상 1인 배치는 중심 부근에 오므로 center 탭으로 충분히
      // 노드를 맞출 수 있다. 혹시 배치가 어긋나 못 맞히더라도, 이 테스트의
      // 핵심은 "onScaleEnd 없이도 onTapUp 경로가 실행된다"는 메커니즘
      // 검증이므로 그래프 영역 내 여러 지점을 순회하며 확인한다.)
      final graphFinder = find.byType(GuinjiAnimatedRelationGraph);
      expect(graphFinder, findsOneWidget);
      final topLeft = tester.getTopLeft(graphFinder);
      final size = tester.getSize(graphFinder);

      // 단일 'CHEON_GWII' 유형 1인 배치(tpPlace)의 노드 좌표를
      // computeGuinjiTpPlacement()로 직접 계산해 정확히 그 지점을
      // "이동 없는 단순 탭"으로 누른다(충돌 해소 보정이 들어가므로
      // 공식을 손으로 재현하지 않고 실제 함수를 그대로 호출한다).
      final placement = computeGuinjiTpPlacement([
        const GuinjiNodeIn('p1', '테스트지인', 'CHEON_GWII', 88),
      ]);
      final canvasX = placement.nodes.single.x;
      final canvasY = placement.nodes.single.y;

      const canvasWidth = 390.0, canvasHeight = 520.0;
      final fitScale = size.width / canvasWidth;
      final fitDy = (size.height - canvasHeight * fitScale) / 2;
      final localX = canvasX * fitScale;
      final localY = canvasY * fitScale + fitDy;

      final nodePoint = topLeft + Offset(localX, localY);
      await tester.tapAt(nodePoint);
      // onDoubleTap이 함께 등록되어 있어 단일 탭은 더블탭 대기시간
      // (kDoubleTapTimeout, 300ms)이 지나야 onTapUp이 실제로 발동한다.
      await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 50));

      // 혹시 계산이 약간 어긋나도 테스트가 깨지지 않도록, 주변 격자도
      // 보조로 순회한다(배치 알고리즘 디테일 변경에 다소 완충).
      if (selected == null) {
        outer:
        for (var dx = -20.0; dx <= 20.0; dx += 5) {
          for (var dy = -20.0; dy <= 20.0; dy += 5) {
            await tester.tapAt(nodePoint + Offset(dx, dy));
            await tester.pump(const Duration(milliseconds: 16));
            if (selected != null) break outer;
          }
        }
      }

      expect(
        selected,
        isNotNull,
        reason:
            '정적 탭만으로 onSelect가 호출되어야 한다(onScaleEnd 의존 금지)',
      );
      expect(selected!.id, 'p1');
    },
  );
}
