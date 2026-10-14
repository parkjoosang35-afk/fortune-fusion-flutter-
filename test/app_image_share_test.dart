import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/share/application/share_service.dart';
import 'package:flutter_app/features/share/domain/share_result_model.dart';

/// [앱·웹 공유 분리 — 2026-10-14] 앱 분기는 원본 PNG를 OS 공유 시트로
/// 직접 전송한다(서버 업로드·/r 링크·동의 팝업 없음). shareXFiles 내부의
/// 실제 임시파일 IO가 있어 runAsync로 실비동기를 완료시킨 뒤 검증한다.
void main() {
  final png = Uint8List.fromList([1, 2, 3]);

  Future<List<MethodCall>> pumpAndTapShare(WidgetTester tester) async {
    final calls = <MethodCall>[];
    Future<Object?>? Function(MethodCall)? handler;
    handler = (call) async {
      calls.add(call);
      return 'success';
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/share'),
          handler,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => '/tmp',
        );
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('dev.fluttercommunity.plus/share'),
            null,
          );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            null,
          );
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => ShareService.shareResult(
                context,
                resultType: ShareResultType.saju,
                title: '정통사주 결과',
                description: '요약',
                payload: {'summary': 'x'},
                preCapturedPng: png,
              ),
              child: const Text('공유'),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await tester.tap(find.text('공유'));
      await Future<void>.delayed(const Duration(milliseconds: 800));
    });
    await tester.pumpAndSettle();
    return calls;
  }

  testWidgets('앱에서는 공개 동의 팝업 없이 이미지 공유 채널로 바로 전송한다', (tester) async {
    final calls = await pumpAndTapShare(tester);
    expect(find.text('이 결과 그대로 공개할까요?'), findsNothing);
    expect(calls.length, 1);
    expect(calls.single.method, 'shareFiles');
    expect((calls.single.arguments as Map)['paths'], isNotEmpty);
    final textParam = calls
        .map(
          (call) =>
              '${call.arguments is Map ? (call.arguments as Map)['text'] ?? '' : ''}',
        )
        .join('\n');
    expect(textParam, contains('sintong.kr'));
    expect(tester.takeException(), null);
  });

  testWidgets('앱 이미지 공유 예외는 실패 안내하며 문구 공유와 복사로 대체하지 않는다', (tester) async {
    final attempts = <MethodCall>[];
    var copies = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'), (_) async => '/tmp',
    );
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'), null,
    ));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/share'),
           (call) async {
             attempts.add(call);
             throw PlatformException(code: 'unsupported');
           },
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
             copies++;
             throw PlatformException(code: 'denied');
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('dev.fluttercommunity.plus/share'),
            null,
          );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => ShareService.shareResult(
                context,
                resultType: ShareResultType.saju,
                title: '정통사주 결과',
                description: '요약',
                payload: {'summary': 'x'},
                preCapturedPng: png,
              ),
              child: const Text('공유'),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await tester.tap(find.text('공유'));
      await Future<void>.delayed(const Duration(milliseconds: 800));
    });
    await tester.pumpAndSettle();
    expect(find.textContaining('결과 이미지를 공유하지 못했어요'), findsOneWidget);
    expect(attempts.length, 1);
    expect(copies, 0);
    expect(find.text('직접 복사해서 전달해주세요'), findsNothing);
    expect(find.text('이 결과 그대로 공개할까요?'), findsNothing);
    expect(tester.takeException(), null);
  });
}
