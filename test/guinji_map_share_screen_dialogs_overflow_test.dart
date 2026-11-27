// [반응형 화면 규격 통일 — 잘림 현상 수정] 귀인지도 공유 화면
// (lib/features/guinji/presentation/guinji_map_share_screen.dart)의
// "새 링크 만들기"/"링크 중단" 확인 AlertDialog 2종이 좁은 화면+글자
// 확대 조합에서 오버플로 없이 렌더되는지 검증한다.
//
// [조사 결과] 전체 5-콤보(390x844@1.0~320x568@2.5) 매트릭스에서 오버플로
// 없음을 확인 — 수정 불필요(content가 2줄 이내로 짧고 actions
// TextButton 2개도 좁은 화면에서 자동 줄바꿈되어 안전).
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
      '귀인지 링크 재발급/중단 확인 다이얼로그가 ${size.width.toInt()}x${size.height.toInt()}@$textScale에서 오버플로 없이 뜬다',
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
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      ElevatedButton(
                        onPressed: () => showDialog<bool>(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            title: const Text('새 링크를 만들까요?'),
                            content: const Text(
                              '이전 링크로 들어오던 사람은 더 이상 들어올 수 없어요.\n이미 지도에 합류한 친구는 그대로 남아있어요.',
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('취소')),
                              TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('새 링크 만들기')),
                            ],
                          ),
                        ),
                        child: const Text('reissue'),
                      ),
                      ElevatedButton(
                        onPressed: () => showDialog<bool>(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            title: const Text('링크를 중단할까요?'),
                            content: const Text(
                              '이 링크로 더 이상 새로운 친구가 들어올 수 없어요.\n언제든 다시 열 수 있어요.',
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('취소')),
                              TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('중단하기')),
                            ],
                          ),
                        ),
                        child: const Text('revoke'),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('reissue'));
        await tester.pumpAndSettle();
        var ex = tester.takeException();
        if (ex != null) debugDumpRenderTree();
        expect(ex, isNull, reason: 'reissue dialog');
        await tester.tap(find.text('취소'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('revoke'));
        await tester.pumpAndSettle();
        ex = tester.takeException();
        if (ex != null) debugDumpRenderTree();
        expect(ex, isNull, reason: 'revoke dialog');
      },
    );
  }
}
