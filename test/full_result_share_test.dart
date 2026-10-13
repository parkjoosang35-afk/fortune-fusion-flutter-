import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/share/presentation/full_result_sheet.dart';

void main() {
  test('사주 마지막 문장과 모든 블록 보존', () {
    final long = '${List.filled(1000, '긴 본문').join()}마지막표식';
    final sections = fullResultSections({
      'blocks': [
        {'title': '핵심', 'body': long},
        {'title': '끝', 'body': '최종블록'},
      ],
    });
    expect(sections.first['body'], long);
    expect(sections.last['body'], '최종블록');
  });
  test('타로 5장과 관상 손금 모든 항목 보존', () {
    expect(
      fullResultSections({
        'positions': List.generate(
          5,
          (i) => {
            'label': '위치$i',
            'cardName': '카드$i',
            'interpretation': '해석$i',
          },
        ),
      }).length,
      5,
    );
    expect(
      fullResultSections({
        'features': {'눈': '눈 전체', '턱': '턱 전체'},
        'topicResults': {'건강': '건강 전체'},
      }).length,
      3,
    );
    expect(
      fullResultSections({
        'lines': {'생명선': '전체 생명선'},
      }).single['body'],
      '전체 생명선',
    );
  });
  testWidgets('긴 결과 전체를 스크롤하며 끝까지 볼 수 있고 저장 전송 버튼 유지', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FullResultSheet(
            title: '시험 결과',
            shareUrl: 'https://sintong.kr/r/test',
            payload: {
              'blocks': List.generate(
                12,
                (i) => {
                  'title': '블록$i',
                  'body': '본문 $i\n${List.filled(30, '전체 내용').join()}',
                },
              ),
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('전체 저장'), findsOneWidget);
    expect(find.text('링크 전송'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('블록11'),
      500,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('블록11'), findsOneWidget);
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find
          .descendant(
            of: find.byType(FullResultSheet),
            matching: find.byType(RepaintBoundary),
          )
          .first,
    );
    expect(boundary.size.height, greaterThan(600));
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      expect(image.height, boundary.size.height.ceil());
      expect(await image.toByteData(format: ui.ImageByteFormat.png), isNotNull);
      image.dispose();
    });
    expect(tester.takeException(), null);
  });
}
