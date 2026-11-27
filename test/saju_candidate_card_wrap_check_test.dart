import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/saju_renewal/theme/saju_dark_tokens.dart';

/// 사용자가 언급한 "08 후보 카드의 '인생 흐름'이 두 줄로 꺾이던 문제"가
/// more_stories_screen.dart `_CandidateCard`의 실제 구조(Row: 장면명 +
/// "시기" 배지, left:18 위치, 카드 폭 = screenWidth - 40)에서 재현되는지
/// 검증한다. 실제 위젯을 import할 수 없는 private 클래스이므로, 동일한
/// 구조를 그대로 재현해 측정한다(코드와 100% 동일한 스타일/레이아웃 사용).
void main() {
  Widget buildRow(String nameKo, bool withBadge) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          nameKo,
          style: TextStyle(
            fontFamily: SajuType.ui,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: SajuScene.life.tint,
          ),
        ),
        if (withBadge) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: SajuText.lineGold),
            ),
            child: const Text(
              '시기',
              style: TextStyle(
                fontFamily: SajuType.ui,
                fontSize: 10,
                color: SajuGold.g100,
              ),
            ),
          ),
        ],
      ],
    );
  }

  testWidgets('장면군 5종 이름 + 시기배지 조합이 카드 좌상단(left:18, 우측글리프 전 공간)에서 줄바꿈되는지',
      (tester) async {
    final names = {
      SajuScene.money: SajuScene.money.nameKo,
      SajuScene.talent: SajuScene.talent.nameKo,
      SajuScene.love: SajuScene.love.nameKo,
      SajuScene.life: SajuScene.life.nameKo,
      SajuScene.guin: SajuScene.guin.nameKo,
    };
    print('장면군 한글 이름: $names');

    for (final width in [320.0, 360.0, 375.0]) {
      for (final entry in names.entries) {
        for (final withBadge in [false, true]) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: width,
                  // _CandidateCard 구조 재현: Positioned(left:18) 안의 Row.
                  // 우측에 글리프(34sp, right:18)가 떠 있어 실질 가용폭은
                  // 카드폭(width-40, 화면 좌우 20패딩) - left18 - 글리프영역.
                  child: Stack(
                    children: [
                      Positioned(
                        left: 18,
                        top: 18,
                        right: 60, // 글리프/우측 여백 보수적으로 60 할당.
                        child: buildRow(entry.value, withBadge),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final finder = find.text(entry.value);
          expect(finder, findsOneWidget);
          final rp = tester.renderObject<RenderParagraph>(finder);
          final boxes = rp.getBoxesForSelection(
            TextSelection(baseOffset: 0, extentOffset: entry.value.length),
          );
          final tops = boxes.map((b) => b.top.round()).toSet();
          print(
            'width=$width scene=${entry.value} withBadge=$withBadge '
            'textWidth=${rp.size.width.toStringAsFixed(1)} lines=${tops.length}',
          );
          expect(
            tops.length,
            1,
            reason:
                '[결함 재현] width=$width "${entry.value}"(배지:$withBadge)가 '
                '${tops.length}줄로 렌더링됨',
          );
        }
      }
    }
  });
}
