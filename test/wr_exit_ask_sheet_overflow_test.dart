// [신통방통 반응형 화면 규격 통일 지시서] 소원방 공용 "신통방통 홈으로
// 갈까요" 확인시트(_showExitAskSheet, wr_nav_pill.dart) 오버플로 테스트.
//
// [확인된 실제 버그 1건 - debugDumpRenderTree로 근본원인 확정]
// 이 시트는 explore/main_room/notifications/vault/complete/decor 등
// 소원방 탭 루트 화면들의 공용 뒤로가기(wrBackOrAskExit)에서 공통으로
// 뜨는 바텀시트인데, 기존 `Container > Column(mainAxisSize: min, [이모지,
// 제목, 안내문, 버튼 Row])` 구조에 SingleChildScrollView 보호가 없어
// 작은 화면(320px대) + textScale 1.5배 이상 조합에서 세로 RenderFlex
// 오버플로가 발생했다(실측: 320x568@1.5 56px, @2.0 204px, @2.5 365px).
// SingleChildScrollView로 감싸 내용이 화면보다 작을 때는 기존과 동일하게
// 렌더링되고, 넘칠 때만 스크롤되도록 수정했다 — 디자인/문구/버튼 변경 없음.
// 메시지는 모든 호출부가 고정 기본 문구만 쓰지만(커스텀 메시지를 넘기는
// 곳 없음), 공용 팝업이라 5개 기기폭×텍스트스케일 조합으로 검증한다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/features/wishroom/core/wr_nav_pill.dart';

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
      '소원방 홈이동 확인시트가 ${size.width.toInt()}x${size.height.toInt()}@$textScale에서 오버플로 없이 뜬다',
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
                      // 탭 루트에서 maybePop()이 실패해 확인시트가 뜨는
                      // 상황을 그대로 재현한다(별도 push된 라우트 없음).
                      onPressed: () => wrBackOrAskExit(context),
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
        expect(find.text('신통방통 홈으로 갈까요'), findsOneWidget);
        expect(find.text('머무를게요'), findsOneWidget);
        expect(find.text('홈으로'), findsOneWidget);
      },
    );
  }
}
