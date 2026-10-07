import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// [가설 2 검증] RenderParagraph.hitTestChildren()는 position의 "가장 가까운
/// glyph"가 속한 TextSpan을 먼저 찾아 HitTestTarget으로 처리(TextSpan은
/// 항상 HitTestTarget 구현)하므로, WidgetSpan 자식에 도달하기 전에 인접
/// 텍스트가 탭을 가로챈다(가설 1 — _VerticalHitExpander 실패로 확인됨).
///
/// 가설 2: RichText 전체를 GestureDetector(behavior: translucent)로
/// 감싸면, 이 GestureDetector는 "부모"로서 자신의 바운드 안의 모든 탭을
/// 항상 수신한다(RenderProxyBoxWithHitTestBehavior의 translucent 분기는
/// 자식의 히트테스트 결과와 무관하게 자기 자신도 항상 히트 목록에 추가).
/// 따라서 onTapUp에서 "탭 글로벌 좌표"를 받아 term의 실제 RenderBox
/// 사각형을 세로로 32pt까지 수동으로 확장(inflate)해 포함 여부를 직접
/// 판정하면, 레이아웃을 전혀 변경하지 않고도(비주얼 크기 그대로) 세로
/// 히트 영역만 확장할 수 있다.
void main() {
  testWidgets(
    '가설2: 바깥 GestureDetector(translucent)가 RenderParagraph 내부 '
    '라우팅과 무관하게 모든 탭을 수신해 term의 32pt 확장 영역을 '
    '수동으로 판정할 수 있다',
    (tester) async {
      final termBoxKey = GlobalKey();
      var tapCount = 0;
      const bodyStyle = TextStyle(fontSize: 14, height: 1.6);

      Rect? lastExpandedRect;
      Offset? lastTapGlobal;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 200,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTapUp: (details) {
                    final rb =
                        termBoxKey.currentContext?.findRenderObject()
                            as RenderBox?;
                    if (rb == null) return;
                    final box = rb.localToGlobal(Offset.zero) & rb.size;
                    const minHeight = 32.0;
                    final extra = (minHeight - box.height) / 2;
                    final expanded = extra > 0 ? box.inflate(extra) : box;
                    // inflate()는 가로/세로 모두 확장하므로, 세로만
                    // 확장하려면 수동으로 Rect를 재구성한다.
                    final expandedVerticalOnly = Rect.fromLTRB(
                      box.left,
                      box.top - (extra > 0 ? extra : 0),
                      box.right,
                      box.bottom + (extra > 0 ? extra : 0),
                    );
                    lastExpandedRect = expandedVerticalOnly;
                    lastTapGlobal = details.globalPosition;
                    if (expandedVerticalOnly.contains(details.globalPosition)) {
                      tapCount++;
                    }
                  },
                  child: RichText(
                    text: TextSpan(
                      style: bodyStyle,
                      children: [
                        const TextSpan(
                          text: '이것은 앞 문장입니다. 그리고 용어 ',
                        ),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Container(
                            key: termBoxKey,
                            color: Colors.red,
                            width: 44.8,
                            height: 23.0,
                            child: const Text('term'),
                          ),
                        ),
                        const TextSpan(
                          text: ' 입니다. 그리고 뒷 문장이 계속 이어집니다 '
                              '줄바꿈이 발생할 만큼 충분히 긴 텍스트로 '
                              '작성합니다.',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final rect = tester.getRect(find.byType(Container).first);
      // 레이아웃(렌더 사이즈)은 그대로 23.0이어야 한다(= 레이아웃 영향 없음).
      expect(rect.height, 23.0, reason: '비주얼/레이아웃 크기는 그대로여야 한다');

      // 중앙 탭 — 항상 성공
      await tester.tapAt(rect.center);
      await tester.pump();
      expect(tapCount, 1, reason: '중앙 탭: expanded=$lastExpandedRect tap=$lastTapGlobal');

      // 확장 영역 안(비주얼 아래 +4, extra=4.5 이내) 탭 — 성공해야 함.
      await tester.tapAt(Offset(rect.center.dx, rect.bottom + 4));
      await tester.pump();
      expect(
        tapCount,
        2,
        reason:
            '32pt 확장 영역 안(비주얼 밖) 탭 실패: expanded=$lastExpandedRect '
            'tap=$lastTapGlobal',
      );

      // 확장 영역 밖(비주얼 아래 +10, extra=4.5 초과) 탭 — 실패해야 함.
      await tester.tapAt(Offset(rect.center.dx, rect.bottom + 10));
      await tester.pump();
      expect(
        tapCount,
        2,
        reason: '확장 영역 밖인데 탭이 등록됨: expanded=$lastExpandedRect '
            'tap=$lastTapGlobal',
      );
    },
  );
}
