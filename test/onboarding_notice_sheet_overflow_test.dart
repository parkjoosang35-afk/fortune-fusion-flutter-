// [신통방통 반응형 화면 규격 통일 지시서] 온보딩 "재미·참고용 콘텐츠 안내"
// 바텀시트(showOnboardingNoticeSheet, onboarding_notice_sheet.dart) 오버플로
// 회귀 테스트.
//
// [확인된 실제 버그 1건 - debugDumpRenderTree로 근본원인 확정]
// 이 시트는 `Container(child: Column(mainAxisSize: min, [...안내문구...,
// SizedBox(height:56, child: ElevatedButton)]))` 구조로 SingleChildScrollView
// 보호가 없었다 — 320x568@2.0/2.5에서 안내문구(3줄 고정 상수)+버튼 높이가
// 화면 높이를 넘어 세로 RenderFlex 오버플로가 발생했다(실측 78px/259px,
// debugDumpRenderTree로 `Column ← Padding ← DecoratedBox ← Container ←
// ... ← SafeArea ← _OnboardingNoticeSheet` 체인에서 OVERFLOWING 확인).
// 수정: Column을 SingleChildScrollView로 감싸, 내용이 화면보다 작을 때는
// 기존과 시각적으로 완전히 동일하고 넘칠 때만 스크롤되게 했다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/features/intro/presentation/widgets/onboarding_notice_sheet.dart';

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
      '온보딩 안내 시트가 ${size.width.toInt()}x${size.height.toInt()}@$textScale에서 오버플로 없이 뜬다',
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
              home: Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () => showOnboardingNoticeSheet(context),
                      child: const Text('open'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        final ex = tester.takeException();
        if (ex != null) {
          debugDumpRenderTree();
        }
        expect(ex, isNull);
        expect(find.text('재미·참고용 콘텐츠 안내'), findsOneWidget);
        expect(find.text('알겠어요'), findsOneWidget);
      },
    );
  }
}
