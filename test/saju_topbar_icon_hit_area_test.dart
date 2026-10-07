import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/features/saju_renewal/widgets/saju_base_widgets.dart';

/// [E-44pt — docs/02_컴포넌트.md §C-01 "Icon 버튼 히트 영역 44×44" /
/// docs/08_QA_체크리스트.md "터치 영역 최소 44pt(아이콘 버튼·용어
/// 링크 포함)"]
///
/// 이전 구현(`SajuIconButton` 내부 `SizedBox(36)+OverflowBox(44)`)은
/// `tester.tapAt()` 실측 결과 36×36 경계 밖을 전혀 탭할 수 없었다
/// (OverflowBox는 paint만 overflow되고 hitTest는 확장되지 않음 —
/// Flutter RenderBox.hitTest()가 자신의 `_size` 안의 position만 자식에
/// 전달하기 때문). 이를 `SajuTopBar`의 `Stack`+`Positioned(44×44)` +
/// `SajuIconButton`의 단순 36×36 비주얼 위젯으로 재구성했으므로, 실제
/// `SajuTopBar(left: SajuIconButton(...))` 조합에서 44×44 전체 영역이
/// 탭 가능한지, 그 경계 밖은 탭이 안 되는지를 end-to-end로 검증한다.
///
/// `find.byType` + `tester.tap()`은 위젯의 geometric center만 탭하므로
/// "영역"의 경계를 검증하기에 부적합하다 — 반드시 `tester.tapAt()`으로
/// 중심에서 오프셋을 준 좌표를 직접 탭해 실제 확장 여부를 확인한다.
void main() {
  Widget wrap(VoidCallback onTap) {
    return MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 320,
            child: SajuTopBar(
              title: 'TEST',
              left: SajuIconButton(icon: '←', onTap: onTap),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets(
    'SajuTopBar 좌측 SajuIconButton은 44×44 전체 영역에서 탭이 작동한다 '
    '(36×36 비주얼 경계 밖, 44×44 히트 영역 안쪽 좌표 포함)',
    (tester) async {
      var tapCount = 0;
      await tester.pumpWidget(wrap(() => tapCount++));
      await tester.pumpAndSettle();

      // SajuTopBar(height:44)의 좌상단 원점은 Align(topLeft) 덕분에
      // (0,0)이다. Positioned(left:-4, top:0, width:44, height:44)이므로
      // 히트 영역은 화면 좌표 기준 x∈[-4, 40], y∈[0, 44]이다.
      // 안전하게 영역 내부의 네 모서리 근처 좌표를 각각 탭해 전체
      // 44×44 영역이 반응하는지 확인한다.
      const inboundProbes = <Offset>[
        Offset(0, 2), // 좌상단 근처(비주얼 36×36 경계 밖, 44×44 안쪽)
        Offset(38, 2), // 우상단 근처
        Offset(0, 42), // 좌하단 근처
        Offset(38, 42), // 우하단 근처
        Offset(18, 22), // 중앙(비주얼 36×36 안쪽)
      ];
      for (final p in inboundProbes) {
        await tester.tapAt(p);
        await tester.pump();
      }
      expect(
        tapCount,
        inboundProbes.length,
        reason:
            '44×44 히트 영역 내부의 모든 좌표(모서리 포함)에서 탭이 '
            '등록되어야 한다. 실제: $tapCount / ${inboundProbes.length}',
      );
    },
  );

  testWidgets(
    'SajuTopBar 좌측 SajuIconButton의 44×44 히트 영역 밖(예: 중앙 타이틀 '
    '영역 쪽 좌표)은 탭이 등록되지 않는다',
    (tester) async {
      var tapCount = 0;
      await tester.pumpWidget(wrap(() => tapCount++));
      await tester.pumpAndSettle();

      // 히트 영역은 x∈[-4, 40] 이므로, x=60(타이틀 영역)은 명백히 밖이다.
      await tester.tapAt(const Offset(60, 22));
      await tester.pump();

      expect(
        tapCount,
        0,
        reason: '44×44 히트 영역 밖(x=60)은 탭이 등록되면 안 된다.',
      );
    },
  );
}
