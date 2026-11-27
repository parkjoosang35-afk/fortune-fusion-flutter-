// [반응형 화면 규격 통일 — 잘림 현상 수정]
// app_bottom_sheet.dart의 showAppBottomSheet()는 소스 코드 주석에
// 기록된 대로, 과거 ConstrainedBox+SingleChildScrollView 보호 장치가
// 없던 시절 "행운상자 확률공개 시트" 경유로 320x568@1.5 55px, @2.0
// 585px, @2.5 2152px RenderFlex 오버플로가 실측되었다. 현재 소스는
// 이미 ConstrainedBox(maxHeight: 90%)+SingleChildScrollView로 수정된
// 상태이나, 이 공용 헬퍼 자체를 직접 호출해 표준 5콤보 매트릭스로
// 검증하는 테스트가 없었다(send_bok_sheet.dart,
// luckybag_probability_sheet.dart 두 실제 호출부가 있지만 각각의
// 전용 테스트가 이 공용 헬퍼의 일반 동작까지 보장하지는 않음). 실제
// showAppBottomSheet() 함수를 길고 짧은 본문 둘 다로 직접 호출해
// 검증한다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/widgets/app_bottom_sheet.dart';

void main() {
  final conditions = <(Size, double)>[
    (const Size(390, 844), 1.0),
    (const Size(360, 640), 1.3),
    (const Size(320, 568), 1.5),
    (const Size(320, 568), 2.0),
    (const Size(320, 568), 2.5),
  ];

  // 과거 버그가 실측된 "행운상자 확률공개" 수준의 긴 리스트 본문을
  // 재현한다 — 제목 + 여러 줄 텍스트 목록.
  Widget longBody() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(
        10,
        (i) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text('${i + 1}등급 당첨 확률: ${(10 - i) * 3.5}% — 복주머니 ${(i + 1) * 10}개'),
        ),
      ),
    );
  }

  for (final (size, textScale) in conditions) {
    testWidgets(
      '공용 바텀시트(긴 본문)가 ${size.width.toInt()}x${size.height.toInt()}@$textScale에서 오버플로 없이 뜬다',
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
                    onPressed: () => showAppBottomSheet<void>(
                      context,
                      title: '당첨 확률 안내',
                      child: longBody(),
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
        final ex = tester.takeException();
        if (ex != null) debugDumpRenderTree();
        expect(ex, isNull);
        expect(find.text('당첨 확률 안내'), findsOneWidget);
      },
    );
  }

  for (final (size, textScale) in conditions) {
    testWidgets(
      '공용 바텀시트(짧은 본문)가 ${size.width.toInt()}x${size.height.toInt()}@$textScale에서 오버플로 없이 뜬다',
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
                    onPressed: () => showAppBottomSheet<void>(
                      context,
                      title: '옵션 선택',
                      child: const Text('간단한 설명 한 줄.'),
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
        final ex = tester.takeException();
        if (ex != null) debugDumpRenderTree();
        expect(ex, isNull);
      },
    );
  }
}
