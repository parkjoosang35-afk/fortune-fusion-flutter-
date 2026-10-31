// [신통방통 반응형 화면 규격 통일 지시서] 로그인 유도 바텀시트
// (showLoginRequiredSheet, pass_gate_helper.dart) 오버플로 회귀 테스트.
//
// [확인된 실제 버그 1건 - debugDumpRenderTree로 근본원인 확정]
// 이 시트는 `SafeArea > Padding > Column(mainAxisSize: min, [그랩핸들,
// 이모지, 제목, categoryTitle 포함 안내문, 버튼, "나중에 할게요"])` 구조로
// SingleChildScrollView 보호가 없었다. categoryTitle은
// all_categories_screen.dart/categories_grid_screen.dart가 관리자 카테고리
// 목록의 entry.title을 그대로 넘기므로 길이가 보장되지 않는데, 긴 카테고리
// 제목 + 작은 화면(320px대) + textScale 2.0배 이상 조합에서 실제 세로
// RenderFlex 오버플로가 발생했다(실측 223px/522px). 수정: Column을
// SingleChildScrollView로 감싸 내용이 화면보다 작을 때는 기존과 시각적으로
// 완전히 동일하고 넘칠 때만 스크롤되게 했다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/features/pass/presentation/pass_gate_helper.dart';

const _longCategoryTitle = '2026년 신년 특별 운세 종합 패키지(사주·타로·관상·손금 올인원)';

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
      '로그인 유도 시트(긴 카테고리명)가 ${size.width.toInt()}x${size.height.toInt()}@$textScale에서 오버플로 없이 뜬다',
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
              routes: {
                '/login': (context) => const Scaffold(body: Text('login')),
              },
              home: Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () => showLoginRequiredSheet(
                        context,
                        categoryTitle: _longCategoryTitle,
                      ),
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
        expect(find.text('로그인 / 회원가입'), findsOneWidget);
        expect(find.text('나중에 할게요'), findsOneWidget);
      },
    );
  }
}
