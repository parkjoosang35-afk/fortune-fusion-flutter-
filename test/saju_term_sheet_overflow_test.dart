import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/saju_renewal/widgets/saju_story_widgets.dart';

void main() {
  final conditions = <(Size, double)>[
    (const Size(390, 844), 1.0),
    (const Size(360, 640), 1.0),
    (const Size(360, 640), 1.3),
    (const Size(320, 568), 1.3),
  ];

  for (final (size, textScale) in conditions) {
    testWidgets(
      '용어 설명 시트가 ${size.width.toInt()}x${size.height.toInt()}@$textScale에서 오버플로 없이 뜬다(긴 설명 포함)',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(textScale),
            ),
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => showSajuTermSheet(
                      context,
                      termLabel: '정인(正印)',
                      definition:
                          '정인은 사주팔자에서 나를 돕고 보호해주는 길한 기운을 뜻하는 용어로, '
                          '학문과 문서, 어른의 도움, 명예 등을 상징하며 일간을 생하는 오행 중 '
                          '음양이 다른 경우를 말합니다. 전통적으로 정인이 강하면 학업운과 '
                          '윗사람의 도움이 따른다고 해석되며, 반대로 정인이 지나치게 많으면 '
                          '의존적이거나 게으른 성향으로 풀이되기도 합니다.',
                    ),
                    child: const Text('열기'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('열기'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('쉬운 설명'), findsOneWidget);
      },
    );
  }
}
