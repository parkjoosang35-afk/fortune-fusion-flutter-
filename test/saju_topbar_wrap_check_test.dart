import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/saju_renewal/widgets/saju_base_widgets.dart';
import 'package:flutter_app/features/saju_renewal/theme/saju_dark_tokens.dart';

/// 사용자가 언급한 "ANALYSIS · 05 / 09 상단 라벨이 두 줄로 꺾이던 문제"가
/// 현재 Flutter 코드(SajuTopBar)에서 실제로 재현되는지 검증한다.
/// 추측이 아니라 TextPainter의 실제 라인 수를 측정한다.
void main() {
  testWidgets('SajuTopBar 각 단계 라벨이 실제 화면 폭에서 한 줄로 렌더링되는지 확인', (tester) async {
    final titles = [
      'ANALYSIS · 01 / 09',
      'ANALYSIS · 05 / 09',
      'ANALYSIS · 09 / 09',
      'PREVIEW · 05',
      'STORY · 09',
      'DETAIL · 07',
      'MORE · 08',
    ];

    // 실제 기기 폭 후보: 가장 좁은 일반 기기(iPhone SE 320pt)부터 확인.
    for (final width in [320.0, 360.0, 375.0, 414.0]) {
      for (final title in titles) {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(size: Size(width, 800)),
              child: Scaffold(
                body: SizedBox(
                  width: width,
                  child: SajuTopBar(
                    left: const SizedBox(width: 36, height: 36),
                    title: title,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final textWidgetFinder = find.descendant(
          of: find.byType(SajuTopBar),
          matching: find.text(title),
        );
        expect(textWidgetFinder, findsOneWidget,
            reason: '$title 텍스트가 렌더링되지 않음(width=$width)');

        final renderParagraph = tester.renderObject<RenderParagraph>(
          textWidgetFinder,
        );
        final lineCount = renderParagraph.text is TextSpan
            ? null
            : null;
        // computeLineMetrics로 실제 라인 수 측정.
        final metrics = renderParagraph.getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: title.length),
        );
        // 라인 수는 y 좌표가 다른 box 개수로 판별(같은 줄이면 top이 동일).
        final tops = metrics.map((b) => b.top.round()).toSet();
        final actualLines = tops.length;

        // Expanded 영역의 실제 가용 폭 계산(좌우 36pt 슬롯 제외).
        final availableWidth = width - 36 - 36;
        final textWidth = renderParagraph.size.width;

        // ignore: unused_local_variable
        final _ = lineCount;

        print(
          'width=$width title="$title" availableWidth=$availableWidth '
          'textWidth=${textWidth.toStringAsFixed(1)} actualLines=$actualLines',
        );

        expect(
          actualLines,
          1,
          reason:
              '[결함 재현] width=$width 에서 "$title" 라벨이 $actualLines줄로 렌더링됨 '
              '(가용폭=$availableWidth, 텍스트폭=${textWidth.toStringAsFixed(1)})',
        );
      }
    }
  });

  testWidgets('mono10 스타일 실제 자간/폭 측정', (tester) async {
    const style = SajuType.mono10;
    final tp = TextPainter(
      text: const TextSpan(text: 'ANALYSIS · 05 / 09', style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    print('mono10 "ANALYSIS · 05 / 09" 폭 = ${tp.width}');
  });
}
