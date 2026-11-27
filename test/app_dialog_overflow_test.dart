import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/widgets/app_dialog.dart';

void main() {
  final conditions = <(Size, double)>[
    (const Size(390, 844), 1.0),
    (const Size(360, 640), 1.3),
    (const Size(320, 568), 1.5),
    (const Size(320, 568), 2.0),
    (const Size(320, 568), 2.5),
  ];

  const longMessage =
      '탈퇴 시 계정 정보와 이용 내역이 모두 삭제되며 복구할 수 없습니다.\n'
      '정말 탈퇴하시겠어요?\n\n'
      '추가로 안내드립니다. 보유 중인 포인트, 복주머니, 상품권, 구독 혜택, '
      '소원방 기록, 저장된 운세 결과, 작성한 게시글과 댓글이 모두 영구히 삭제되며 '
      '어떠한 경우에도 복구가 불가능합니다. 진행 중인 결제나 구독이 있다면 '
      '자동으로 해지되며 환불 규정에 따라 처리됩니다. 정말로 탈퇴를 진행하시겠습니까? '
      '한 번 더 신중하게 생각해 주세요.';

  for (final (size, textScale) in conditions) {
    testWidgets(
      '확인 다이얼로그(긴 메시지)가 ${size.width.toInt()}x${size.height.toInt()}@$textScale에서 오버플로 없이 뜬다',
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
                    onPressed: () => showAppConfirmDialog(
                      context,
                      title: '회원탈퇴',
                      message: longMessage,
                      confirmLabel: '탈퇴하기',
                      isDanger: true,
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
      },
    );
  }

  for (final (size, textScale) in conditions) {
    testWidgets(
      '안내 다이얼로그(긴 메시지)가 ${size.width.toInt()}x${size.height.toInt()}@$textScale에서 오버플로 없이 뜬다',
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
                    onPressed: () => showAppInfoDialog(
                      context,
                      title: '프리패스 안내',
                      message: longMessage,
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
      },
    );
  }
}
