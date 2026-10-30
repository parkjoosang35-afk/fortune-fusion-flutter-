// [반응형 화면 규격 통일 — 잘림 현상 수정] 홈 "관상·손금" 카드에서 열리는
// 선택 시트(showFacePalmSelectSheet, lib/core/widgets/face_palm_select_sheet.dart)가
// 좁은 화면+글자 확대 조합에서 오버플로 없이 렌더되는지 검증한다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/core/widgets/face_palm_select_sheet.dart';

void main() {
  final conditions = <(Size, double)>[
    (const Size(390, 844), 1.0),
    (const Size(360, 640), 1.0),
    (const Size(360, 640), 1.3),
    (const Size(320, 568), 1.3),
  ];

  for (final (size, textScale) in conditions) {
    testWidgets(
      '관상·손금 선택 시트가 ${size.width.toInt()}x${size.height.toInt()}@$textScale에서 오버플로 없이 뜬다',
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
                      onPressed: () => showFacePalmSelectSheet(context),
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
        expect(find.text('관상 보기'), findsOneWidget);
        expect(find.text('손금 보기'), findsOneWidget);
      },
    );
  }
}
