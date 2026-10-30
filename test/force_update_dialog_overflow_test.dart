import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// force_update_gate.dart의 _showForceUpdateDialog와 동일한 구조를 재현해
// 서버가 내려주는 policy.notice가 길 때 다이얼로그가 세로로 잘리는지 확인한다.
// (StatefulWidget 내부 private 메서드라 직접 import가 어려워 동일 위젯
// 트리를 구성해 검증한다.)
void showDialogLike(BuildContext context, String notice) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('업데이트가 필요합니다'),
        content: Text(notice),
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text('업데이트'),
          ),
        ],
      ),
    ),
  );
}

void main() {
  final conditions = <(Size, double)>[
    (const Size(390, 844), 1.0),
    (const Size(360, 640), 1.0),
    (const Size(360, 640), 1.3),
    (const Size(320, 568), 1.3),
  ];

  const longNotice =
      '이번 업데이트에는 다음과 같은 중요한 변경사항이 포함되어 있습니다.\n\n'
      '1. 결제 시스템 전면 개편으로 인한 보안 강화\n'
      '2. 사주/타로 계산 엔진 정확도 개선\n'
      '3. 알림 기능 안정화 및 푸시 수신 오류 수정\n'
      '4. 앱 실행 속도 30% 개선\n'
      '5. 기타 다수의 버그 수정 및 안정성 개선\n\n'
      '현재 버전은 더 이상 지원되지 않으며, 계속 이용하시려면 반드시 최신 '
      '버전으로 업데이트해야 합니다. 업데이트하지 않을 경우 서비스 이용이 '
      '제한될 수 있습니다.';

  for (final (size, textScale) in conditions) {
    testWidgets(
      '강제 업데이트 다이얼로그(긴 공지)가 ${size.width.toInt()}x${size.height.toInt()}@$textScale에서 오버플로 없이 뜬다',
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
                    onPressed: () => showDialogLike(context, longNotice),
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
