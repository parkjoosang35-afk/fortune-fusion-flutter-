// [반응형 화면 규격 통일 — 잘림 현상 수정] 소원방 "안내서"(GuideBook,
// showModalBottomSheet)가 좁은 화면+글자 확대 조합에서 오버플로 없이
// 렌더되는지 검증한다. GuideBook은 이미 Container(maxHeight: .86 화면높이)
// + Column(mainAxisSize:min) + Flexible(SingleChildScrollView)로 구성돼
// 있어 설계상 안전해 보이지만, 실제로 가장 긴 항목(seal, 5줄 본문)을
// 펼친 상태로 실측 검증한다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/features/wishroom/features/guide/guide_sheet.dart';

void main() {
  final conditions = <(Size, double)>[
    (const Size(390, 844), 1.0),
    (const Size(360, 640), 1.0),
    (const Size(360, 640), 1.3),
    (const Size(320, 568), 1.3),
  ];

  for (final (size, textScale) in conditions) {
    testWidgets(
      '소원방 안내서(GuideBook, seal 항목 펼침)가 ${size.width.toInt()}x${size.height.toInt()}@$textScale에서 오버플로 없이 뜬다',
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
              home: Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          isScrollControlled: true,
                          builder: (_) => const GuideBook(focus: 'seal'),
                        );
                      },
                      child: const Text('open'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('GUIDE · 소원방 안내서'), findsOneWidget);
        // seal 항목이 focus로 펼쳐져 본문(가장 긴 5번째 줄)이 보여야 한다.
        expect(
          find.textContaining('열어본 뒤에는 이루어졌는지'),
          findsOneWidget,
        );
      },
    );
  }
}
