// [반응형 화면 규격 통일 — 잘림 현상 수정]
// safe_share.dart의 safeShareText()가 네이티브 공유/클립보드 복사에
// 모두 실패했을 때 띄우는 "직접 복사해서 전달해주세요" AlertDialog를
// 표준 5콤보 매트릭스(390x844@1.0 ~ 320x568@2.5)로 검증한다. 기존
// safe_share_outcome_test.dart는 이 다이얼로그가 뜨는 것만 확인하고
// textScale/작은 화면 조합에서의 오버플로는 검증하지 않았다. 이
// 다이얼로그는 content가 이미 SingleChildScrollView(SelectableText)로
// 감싸여 있어 본문 자체는 스크롤 가능하지만, title+actions를 포함한
// 전체 AlertDialog가 작은 화면+글자확대 조합에서 안전한지는 별도
// 검증이 필요하다. 실제 safeShareText() 함수를 직접 호출해(재구성이
// 아닌 실제 코드 경로) 검증한다.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/util/safe_share.dart';

void main() {
  final conditions = <(Size, double)>[
    (const Size(390, 844), 1.0),
    (const Size(360, 640), 1.3),
    (const Size(320, 568), 1.5),
    (const Size(320, 568), 2.0),
    (const Size(320, 568), 2.5),
  ];

  // 실제 공유 결과 URL 수준의 길이 있는 텍스트(링크+안내 문구 포함)로
  // 검증한다 — 공유 실패 폴백 다이얼로그는 result_access 등에서 긴 URL과
  // 안내 문구를 함께 전달하는 경우가 많다.
  const longText =
      'https://sintong.kr/share/result/abcdefg1234567890?ref=guinji&from=kakao\n'
      '신통방통에서 확인한 나의 2026년 신년운세를 함께 확인해보세요!';

  for (final (size, textScale) in conditions) {
    testWidgets(
      '공유 실패 시 "직접 복사" 안내 다이얼로그가 ${size.width.toInt()}x${size.height.toInt()}@$textScale에서 오버플로 없이 뜬다',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

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
          MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(textScale),
            ),
            child: MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => safeShareText(context, longText),
                    child: const Text('전송'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('전송'));
        await tester.pumpAndSettle();
        var ex = tester.takeException();
        if (ex != null) debugDumpRenderTree();
        expect(ex, isNull);
        expect(find.text('직접 복사해서 전달해주세요'), findsOneWidget);

        await tester.tap(find.text('닫기'));
        await tester.pumpAndSettle();
        ex = tester.takeException();
        if (ex != null) debugDumpRenderTree();
        expect(ex, isNull);
      },
    );
  }
}
