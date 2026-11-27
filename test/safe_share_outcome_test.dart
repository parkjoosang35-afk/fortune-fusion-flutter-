import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/util/safe_share.dart';
import 'package:flutter_app/core/util/web_share_outcome.dart';

void main() {
  test('공유 성공·취소는 복사하지 않고 미지원만 복사', () {
    expect(needsShareCopy(NativeWebShareOutcome.shared), false);
    expect(needsShareCopy(NativeWebShareOutcome.cancelled), false);
    expect(needsShareCopy(NativeWebShareOutcome.unavailable), true);
  });
  testWidgets('네이티브 공유와 클립보드 실패 시 선택 가능한 원문 안내', (tester) async {
    const text = 'http://localhost/result';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/share'),
          (_) async => throw PlatformException(code: 'unsupported'),
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            throw PlatformException(code: 'denied');
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('dev.fluttercommunity.plus/share'),
            null,
          );
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => safeShareText(context, text),
              child: const Text('전송'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('전송'));
    await tester.pumpAndSettle();
    expect(find.text('직접 복사해서 전달해주세요'), findsOneWidget);
    expect(find.byType(SelectableText), findsOneWidget);
    expect(find.text(text), findsOneWidget);
    expect(tester.takeException(), null);
  });
}
