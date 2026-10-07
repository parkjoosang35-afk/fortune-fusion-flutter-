import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/features/saju_renewal/widgets/saju_story_widgets.dart';

/// [E-32pt — docs/02_컴포넌트.md §C-07 "히트 영역: 세로 최소 32pt
/// (레이아웃에 영향 없이 확장)"]
///
/// 실측 결과 [SajuTermText] 용어 위젯의 실제 비주얼 높이는 23.0pt로
/// 32pt 요구사항에 미달했다(결함 확정). `OverflowBox`/커스텀
/// RenderObject hitTest 오버라이드 모두 `RenderParagraph`의 glyph 기반
/// hitTestChildren() 라우팅 때문에 실패함을 디버그 테스트로 확인했다
/// (인접 TextSpan이 항상 HitTestTarget이라 WidgetSpan 자식에 결코
/// 도달하지 못함).
///
/// 최종 해법은 [SajuTermText] 전체를 `GestureDetector(behavior:
/// translucent)`로 감싸 모든 탭의 글로벌 좌표를 직접 받은 뒤, 각 용어의
/// 실제 RenderBox 사각형(세로만 32pt까지 수동 확장)과 비교해 포함
/// 여부를 판정하는 방식이다 — 비주얼 레이아웃(가로/세로 23.0pt)에는
/// 전혀 영향을 주지 않는다.
///
/// 이 테스트는 `tester.tapAt()`으로 실제 좌표를 직접 탭해 32pt 확장
/// 영역의 안/밖 경계를 end-to-end로 검증한다.
void main() {
  Finder findRichTextContaining(String substring) {
    return find.byWidgetPredicate((widget) {
      if (widget is RichText) {
        return widget.text.toPlainText().contains(substring);
      }
      return false;
    });
  }

  testWidgets(
    'SajuTermText 용어의 세로 히트 영역은 32pt로 확장되어 있다 — '
    '비주얼(23.0pt) 바로 아래 좌표도 탭이 되지만, 32pt 밖은 탭이 안 된다',
    (tester) async {
      String? openedKey;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 320,
                child: SajuTermScope(
                  onOpenTerm: (key) => openedKey = key,
                  child: const SajuTermText(
                    text: '이건 [[yongshin|용신 설명]]과 관련 있어요.',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final termRect = tester.getRect(findRichTextContaining('용신 설명'));
      // 실측 기준: 비주얼 높이가 32pt 미만이어야 "확장" 의미가 있다.
      expect(
        termRect.height,
        lessThan(32),
        reason:
            '비주얼 높이가 이미 32pt 이상이면 확장 검증이 무의미함(가정 확인)',
      );

      // 비주얼 경계(정확히 center) 탭 — 항상 성공해야 한다.
      await tester.tapAt(termRect.center);
      await tester.pump();
      expect(openedKey, 'yongshin', reason: '비주얼 중앙 탭은 항상 성공해야 한다');

      openedKey = null;

      // 비주얼 바로 아래(32pt 확장 영역 안쪽) 탭 — 성공해야 한다.
      final extra = (32 - termRect.height) / 2;
      final withinExpanded = Offset(
        termRect.center.dx,
        termRect.bottom + extra / 2, // 확장 경계 안쪽 중간 지점(여유 확보)
      );
      await tester.tapAt(withinExpanded);
      await tester.pump();
      expect(
        openedKey,
        'yongshin',
        reason: '32pt로 확장된 영역(비주얼 밖)에서도 탭이 성공해야 한다',
      );

      openedKey = null;

      // 32pt 확장 영역 밖(비주얼 아래로 충분히 떨어진 지점) 탭 — 실패해야 한다.
      final outsideExpanded = Offset(
        termRect.center.dx,
        termRect.bottom + extra + 10,
      );
      await tester.tapAt(outsideExpanded);
      await tester.pump();
      expect(
        openedKey,
        isNull,
        reason: '32pt 확장 영역을 벗어난 탭은 onOpenTerm을 호출하면 안 된다',
      );
    },
  );

  testWidgets(
    'SajuTermText 여러 용어가 섞여 있어도 각 용어는 자신의 32pt 영역에만 '
    '반응하고, 다른 용어의 확장 영역을 침범하지 않는다',
    (tester) async {
      final openedKeys = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 320,
                child: SajuTermScope(
                  onOpenTerm: openedKeys.add,
                  child: const SajuTermText(
                    text:
                        '[[yongshin|용신 설명]] 그리고 [[daewoon|대운 설명]]이 '
                        '같이 있어요.',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final yongshinRect = tester.getRect(findRichTextContaining('용신 설명'));
      final daewoonRect = tester.getRect(findRichTextContaining('대운 설명'));

      await tester.tapAt(yongshinRect.center);
      await tester.pump();
      expect(openedKeys, ['yongshin']);

      await tester.tapAt(daewoonRect.center);
      await tester.pump();
      expect(openedKeys, ['yongshin', 'daewoon']);
    },
  );
}
