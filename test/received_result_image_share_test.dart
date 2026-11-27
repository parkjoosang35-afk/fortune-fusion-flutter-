
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/share/presentation/full_result_sheet.dart';

void main() {
  final png = File('assets/tarot/oz/card-back.png').readAsBytesSync();
  for (final status in ['success', 'dismissed', 'unavailable']) {
    testWidgets('공유 수신 화면 이미지 버튼 실제 파일 호출: $status', (tester) async {
      final calls = <MethodCall>[];
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), (_) async => '/tmp');
      messenger.setMockMethodCallHandler(const MethodChannel('dev.fluttercommunity.plus/share'), (call) async {
        calls.add(call);
        return status == 'unavailable' ? 'dev.fluttercommunity.plus/share/unavailable' : status == 'dismissed' ? '' : 'com.example.recipient';
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), null);
        messenger.setMockMethodCallHandler(const MethodChannel('dev.fluttercommunity.plus/share'), null);
      });
      await tester.pumpWidget(MaterialApp(home:Scaffold(body:FullResultSheet(
        title:'검수 결과', shareUrl:'https://qa.example.invalid/web-result/test',
        payload:const {'summary':'전체 결과'}, originalPng:png,
      ))));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('이미지 전송'));
        await Future<void>.delayed(const Duration(milliseconds:500));
      });
      await tester.pump();
      expect(calls.length,1);
      expect(calls.single.method,'shareFiles');
      final paths = (calls.single.arguments as Map)['paths'] as List;
      expect(paths.length,1);
      final bytes = await tester.runAsync(() => File(paths.single as String).readAsBytes());
      expect(bytes,png);
      expect(find.text('링크 전송'),findsNothing);
      if (status == 'unavailable') {
        expect(find.textContaining('결과 이미지를 공유하지 못했어요'),findsOneWidget);
      } else {
        expect(find.textContaining('결과 이미지를 공유하지 못했어요'),findsNothing);
      }
      expect(tester.takeException(),isNull);
      await tester.pump(const Duration(seconds:4));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
