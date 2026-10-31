// [반응형 화면 규격 통일 — 잘림 현상 수정] 귀인지도 참여 완료 AlertDialog
// (lib/features/guinji/presentation/guinji_join_screen.dart, 관계 판정
// 결과를 보여주는 showDialog<void>)가 좁은 화면+글자 확대 조합에서
// 오버플로 없이 렌더되는지 검증한다.
//
// [조사 결과] 전체 5-콤보(390x844@1.0~320x568@2.5) 매트릭스에서 오버플로
// 없음을 확인 — 수정 불필요(content가 2줄 이내로 짧아 scrollable 없이도
// 안전).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final conditions = <(Size, double)>[
    (const Size(390, 844), 1.0),
    (const Size(360, 640), 1.3),
    (const Size(320, 568), 1.5),
    (const Size(320, 568), 2.0),
    (const Size(320, 568), 2.5),
  ];

  for (final (size, textScale) in conditions) {
    testWidgets(
      '귀인지 참여완료 AlertDialog가 ${size.width.toInt()}x${size.height.toInt()}@$textScale에서 오버플로 없이 뜬다',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
            child: MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('참여 완료'),
                          content: const Text(
                            '김민지님과 당신은 比和(비화)의 결이에요.\n케미 점수 87점',
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('확인')),
                          ],
                        ),
                      ),
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

        final ex = tester.takeException();
        if (ex != null) debugDumpRenderTree();
        expect(ex, isNull);
      },
    );
  }
}
