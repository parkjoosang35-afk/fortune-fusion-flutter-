import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// share_service.dart의 _shareResult() 내부 '공개 동의' showDialog<bool>과
// 동일한 구조를 재현해 검증한다. (ShareService._shareResult는 private이고
// 공개 shareResult()는 실제 네트워크(ShareApiService.createShareLink)를
// 호출하므로, 네트워크 목업 없이 다이얼로그 레이아웃만 검증하기 위해
// 동일 위젯 트리를 재구성한다 — force_update_dialog_overflow_test.dart와
// 동일한 접근 방식.)
//
// [반응형 화면 규격 통일 — 잘림 현상 수정 — 매트릭스 1.3 → 전체 5-콤보
// (390x844@1.0 ~ 320x568@2.5)로 확장 재검증] 과거 1.3배까지만 테스트했을
// 때는 문제가 없었으나, 320x568@2.5에서 content 텍스트가 확대되며 62px
// RenderFlex 오버플로가 실측 확인됐다. share_service.dart의 AlertDialog에
// scrollable: true를 추가해 해결(문구/버튼/디자인 변경 없음) — 아래
// showConsentDialogLike()도 동일하게 scrollable: true를 반영했다.
Future<bool?> showConsentDialogLike(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      scrollable: true,
      title: const Text('이 결과 그대로 공개할까요?'),
      content: const Text(
        '공유 링크를 가진 사람은 결과 화면에 보이는 이름·질문·사진·본문을 모두 볼 수 있어요. 공개하고 싶지 않은 내용이 있다면 취소해주세요.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('그대로 공유'),
        ),
      ],
    ),
  );
}

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
      '공유 결과 공개 동의 다이얼로그가 ${size.width.toInt()}x${size.height.toInt()}@$textScale에서 오버플로 없이 뜬다',
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
                    onPressed: () => showConsentDialogLike(context),
                    child: const Text('열기'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('열기'));
        await tester.pumpAndSettle();
        var ex = tester.takeException();
        if (ex != null) debugDumpRenderTree();
        expect(ex, isNull);

        // 버튼이 실제로 탭 가능한지(화면 밖으로 밀려나지 않았는지)까지 확인.
        await tester.tap(find.text('취소'));
        await tester.pumpAndSettle();
        ex = tester.takeException();
        if (ex != null) debugDumpRenderTree();
        expect(ex, isNull);
      },
    );
  }
}
