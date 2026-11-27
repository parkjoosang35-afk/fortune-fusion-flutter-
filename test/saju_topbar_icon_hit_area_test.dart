import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/features/saju_renewal/widgets/saju_base_widgets.dart';

/// [E-44pt — docs/02_컴포넌트.md §C-01 "Icon 버튼 히트 영역 44×44" /
/// docs/08_QA_체크리스트.md "터치 영역 최소 44pt(아이콘 버튼·용어
/// 링크 포함)"]
///
/// [버그 이력]
/// 1) 1차 구현(`SajuIconButton` 내부 `SizedBox(36)+OverflowBox(44)`)은
///    `tester.tapAt()` 실측 결과 36×36 경계 밖을 전혀 탭할 수 없었다
///    (OverflowBox는 paint만 overflow되고 hitTest는 확장되지 않음).
/// 2) 2차 구현(`SajuTopBar`를 Stack화하고 `Positioned(left: -4, width:
///    44)`로 36pt 슬롯 "중심"에 걸치게 함)도 실측 결과 결함이 있었다 —
///    실제 프로덕션 구조(SafeArea→Column, 화면 전체 폭, 좌우 여백
///    없음)에서는 x<0 구간이 Stack bounds(화면 폭) 밖이라 히트 불가능,
///    유효 히트 폭이 40pt(44pt 요구사항 미달)로 줄어들었다(Positioned의
///    음수 오프셋도 OverflowBox와 동일한 "자신의 size 밖은 자식에 도달
///    불가" 문제를 겪는다).
/// 3) 최종 구현: `Positioned(left: 0, width: 44)`로 44×44 히트 박스
///    전체가 Stack bounds 안에 완전히 포함되게 하고, 그 안에서 36×36
///    비주얼은 `Align(centerLeft)`로 화면 가장자리에 그대로 둔다(기존
///    Row(SizedBox(width:36)) 비주얼 위치와 동일, 히트 영역만 안쪽
///    방향으로 8pt 확장).
///
/// 이 테스트는 x=0(왼쪽 끝 정확히 안쪽) ~ x=43.9(44pt 경계 바로 안쪽)
/// 까지 44pt 전체가 히트되고, x=44(경계 바로 밖)는 히트되지 않음을
/// `tester.tapAt()`으로 직접 검증한다. `find.byType` + `tester.tap()`은
/// 위젯의 geometric center만 탭하므로 "영역"의 경계를 검증하기에
/// 부적합하다.
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
    'SajuTopBar 좌측 SajuIconButton은 44×44 전체 영역(x∈[0,44), '
    'y∈[0,44))에서 탭이 작동한다(36×36 비주얼 경계 밖 좌표 포함)',
    (tester) async {
      var tapCount = 0;
      await tester.pumpWidget(wrap(() => tapCount++));
      await tester.pumpAndSettle();

      // Stack의 좌상단 원점은 Align(topLeft) 덕분에 (0,0)이다.
      // Positioned(left:0, top:0, width:44, height:44)이므로 히트
      // 영역은 화면 좌표 기준 x∈[0,44), y∈[0,44)이다. 4개 모서리(경계
      // 바로 안쪽) + 비주얼(36×36, x∈[4,40]) 밖이지만 44×44 안쪽인
      // 좌표를 포함해 전 영역이 반응하는지 확인한다.
      const inboundProbes = <Offset>[
        Offset(0.5, 0.5), // 좌상단 경계 바로 안쪽
        Offset(43.4, 0.5), // 우상단 경계 바로 안쪽(비주얼 36×36 밖)
        Offset(0.5, 43.4), // 좌하단 경계 바로 안쪽
        Offset(43.4, 43.4), // 우하단 경계 바로 안쪽(비주얼 밖)
        Offset(22, 22), // 중앙(비주얼 36×36 안쪽)
        Offset(1, 22), // 비주얼 왼쪽 패딩 영역(x∈[0,4), 비주얼 밖)
        Offset(42, 22), // 비주얼 오른쪽 패딩 영역(x∈[40,44), 비주얼 밖)
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
    'SajuTopBar 좌측 SajuIconButton의 44×44 히트 영역 경계 밖(x=44 이상, '
    '또는 타이틀 영역 쪽)은 탭이 등록되지 않는다',
    (tester) async {
      var tapCount = 0;
      await tester.pumpWidget(wrap(() => tapCount++));
      await tester.pumpAndSettle();

      // x=44는 Positioned(width:44)의 정확한 경계(배타적 상한) 밖이다.
      await tester.tapAt(const Offset(44, 22));
      await tester.pump();
      expect(tapCount, 0, reason: '44×44 히트 영역의 정확한 경계(x=44)는 탭이 등록되면 안 된다.');

      // x=60(타이틀 영역)은 명백히 밖이다.
      await tester.tapAt(const Offset(60, 22));
      await tester.pump();
      expect(tapCount, 0, reason: '44×44 히트 영역 밖(x=60, 타이틀 영역)은 탭이 등록되면 안 된다.');
    },
  );

  testWidgets(
    'SajuTopBar 우측 SajuIconButton도 동일하게 44×44 전체 영역(화면 '
    '오른쪽 가장자리 기준)에서 탭이 작동하고, 경계 밖은 작동하지 않는다',
    (tester) async {
      var tapCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 320,
                child: SajuTopBar(
                  title: 'TEST',
                  right: SajuIconButton(icon: '✕', onTap: () => tapCount++),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 우측 히트 영역은 x∈[320-44, 320)=[276,320), y∈[0,44).
      const inboundProbes = <Offset>[
        Offset(276.5, 0.5), // 좌상단 경계 바로 안쪽(비주얼 밖)
        Offset(319.4, 43.4), // 우하단 경계 바로 안쪽(화면 끝 바로 안쪽)
        Offset(298, 22), // 중앙(비주얼 36×36 안쪽)
      ];
      for (final p in inboundProbes) {
        await tester.tapAt(p);
        await tester.pump();
      }
      expect(
        tapCount,
        inboundProbes.length,
        reason: '우측 44×44 히트 영역 내부는 모두 탭이 등록되어야 한다. '
            '실제: $tapCount / ${inboundProbes.length}',
      );

      // 경계 밖(화면 끝을 넘어가거나, 타이틀 쪽) 확인.
      await tester.tapAt(const Offset(275, 22)); // 276 바로 왼쪽(밖)
      await tester.pump();
      expect(tapCount, inboundProbes.length, reason: '우측 히트 영역 왼쪽 경계(x=275) 밖은 탭이 등록되면 안 된다.');
    },
  );
}
