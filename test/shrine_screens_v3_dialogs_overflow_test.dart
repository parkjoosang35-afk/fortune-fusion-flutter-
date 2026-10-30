import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// [반응형 화면 규격 통일] 신당(shrine) screens_v3.dart 내 showDialog 4종을
// 각 소스의 실제 위젯 트리와 동일하게 재구성해 검증한다. 모두 private
// 메서드 내부에 있어 직접 import해 호출하기 어려우므로,
// force_update_dialog_overflow_test.dart와 동일한 접근 방식을 사용한다.

// 1) ConnectScreen._showLinkError() — 서버 메시지(e.message)를 그대로
// 보여주므로 길어질 수 있는 동적 콘텐츠를 가진 유일한 다이얼로그다.
Future<String?> showLinkErrorDialogLike(
  BuildContext context, {
  required String code,
  required String message,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(code == 'NOT_LOGGED_IN' ? '로그인이 필요합니다' : '실명 등록이 필요합니다'),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('취소')),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(code == 'NOT_LOGGED_IN' ? '/login' : '/my/settings'),
          child: Text(code == 'NOT_LOGGED_IN' ? '로그인하기' : '설정으로 이동'),
        ),
      ],
    ),
  );
}

// 2) MeaningScreen._go() UNAUTHORIZED 로그인 유도 다이얼로그(고정 문구).
Future<bool?> showMeaningLoginDialogLike(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('로그인이 필요합니다'),
      content: const Text(
        '부적을 받으려면 신통방통 로그인이 필요합니다.\n로그인 후 다시 돌아와 이어서 진행해 주세요.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('취소')),
        TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('로그인하기')),
      ],
    ),
  );
}

// 3) MeaningScreen._go() gate.ok==false 사유 다이얼로그 — gate.reason이
// 서버 동적 문구라 길어질 수 있다.
Future<void> showGateReasonDialogLike(
  BuildContext context, {
  required String code,
  required String? reason,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
        code == 'ALREADY_ISSUED'
            ? '이미 받은 부적입니다'
            : code == 'DAILY_LIMIT'
                ? '오늘은 더 받을 수 없습니다'
                : '지금은 부적을 받을 수 없습니다',
      ),
      content: Text(reason ?? '지금은 부적을 받을 수 없습니다. 잠시 후 다시 시도해 주세요.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(code == 'ALREADY_ISSUED' ? '부적함으로' : '확인'),
        ),
      ],
    ),
  );
}

// 4) ReceiveScreen._keep() UNAUTHORIZED 로그인 유도 다이얼로그(고정 문구).
Future<bool?> showReceiveLoginDialogLike(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('로그인이 필요합니다'),
      content: const Text(
        '부적을 간직하려면 신통방통 로그인이 필요합니다.\n로그인 후 다시 돌아와 이어서 진행해 주세요.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('취소')),
        TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('로그인하기')),
      ],
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

  // 서버가 내려줄 수 있는 긴 안내 문구(길이 상한을 가정하지 않는 구조적
  // 취약점 점검을 위해 충분히 긴 문구로 재현).
  const longMessage =
      '본인 인증 정보와 신통방통 계정에 등록된 실명이 일치하지 않아 신당 '
      '명부 연결을 진행할 수 없습니다. 마이페이지의 설정 화면에서 실명을 '
      '다시 등록하거나 고객센터로 문의해 주세요.';

  for (final (size, textScale) in conditions) {
    final suffix = '${size.width.toInt()}x${size.height.toInt()}@$textScale';

    testWidgets('신당 명부연결 오류 안내 다이얼로그(긴 메시지)가 $suffix에서 오버플로 없이 뜬다', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showLinkErrorDialogLike(
                    context,
                    code: 'NO_REAL_NAME',
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
    });

    testWidgets('신당 부적수령 로그인유도 다이얼로그가 $suffix에서 오버플로 없이 뜬다', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showMeaningLoginDialogLike(context),
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
    });

    testWidgets('신당 발급제한 사유 다이얼로그(긴 사유)가 $suffix에서 오버플로 없이 뜬다', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showGateReasonDialogLike(
                    context,
                    code: 'DAILY_LIMIT',
                    reason:
                        '오늘 발급 가능한 부적 수량을 모두 사용했습니다. 자정이 지나면 다시 새로운 '
                        '이야기를 통해 부적을 받을 수 있어요. 그동안 다른 이야기들도 둘러보세요.',
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
    });

    testWidgets('신당 부적간직 로그인유도 다이얼로그가 $suffix에서 오버플로 없이 뜬다', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showReceiveLoginDialogLike(context),
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
    });
  }
}
