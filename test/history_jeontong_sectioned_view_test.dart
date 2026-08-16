import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/core/router/app_router.dart';
import 'package:flutter_app/features/history/domain/history_readonly_adapter.dart';
import 'package:flutter_app/features/history/presentation/history_jeontong_sectioned_view.dart';

void main() {
  // 80개 HistoryReadOnlyEntry 합성 — A01..H10, section letter = id 첫 글자.
  // id 포맷은 실제 JeontongHistoryStore.record()와 동일하게
  // '$categoryId-$userId-$epoch' 형태를 재현한다.
  List<HistoryReadOnlyEntry> buildEighty() {
    const letters = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];
    final list = <HistoryReadOnlyEntry>[];
    var epoch = 1000;
    for (final letter in letters) {
      for (var i = 1; i <= 10; i++) {
        final num = i.toString().padLeft(2, '0');
        final categoryId = '$letter$num';
        list.add(
          HistoryReadOnlyEntry(
            id: '$categoryId-u-test-$epoch',
            title: '$categoryId 결과 제목',
            subtitle: '$categoryId 결과 부제',
            createdAt: DateTime.utc(2026, 8, 14, 0, 0, epoch % 60),
          ),
        );
        epoch += 1;
      }
    }
    return list;
  }

  testWidgets('80건 → ExpansionTile 8개 + A 섹션 펼침 시 카드 ≥10', (tester) async {
    final eighty = buildEighty();

    // ListView.builder는 지연 렌더링이므로, 뷰포트 밖 섹션(B~H)까지 모두
    // 렌더되는지 확인하려면 오버사이즈 뷰포트가 필요하다(페이지 전환
    // 애니메이션이 없는 직접 pump 테스트이므로 안전 — 그리드 신설 미션의
    // 동일 패턴 재사용).
    addTearDown(tester.view.resetPhysicalSize);
    tester.view.physicalSize = const Size(1200, 20000);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: AppRouter.onGenerateRoute,
        home: Scaffold(
          body: HistoryJeontongSectionedView(entries: eighty, userId: 'u-test'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ExpansionTile), findsAtLeastNWidgets(8));

    // A 섹션은 initiallyExpanded = true 이므로 이미 펼쳐져 카드 10개가 보여야 함.
    expect(find.byType(ListTile), findsAtLeastNWidgets(10));
  });

  testWidgets('카드 탭 시 정통사주 결과 라우트로 categoryId(String) 단독 전달', (tester) async {
    final eighty = buildEighty();
    String? capturedRouteName;
    Object? capturedArguments;

    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (settings) {
          if (settings.name == '/jeontong/eighty/result') {
            capturedRouteName = settings.name;
            capturedArguments = settings.arguments;
            return MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('result-stub')),
            );
          }
          return AppRouter.onGenerateRoute(settings);
        },
        home: Scaffold(
          body: HistoryJeontongSectionedView(entries: eighty, userId: 'u-test'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // A 섹션은 이미 펼쳐져 있으므로 A01 카드가 바로 보인다.
    await tester.tap(find.text('A01 결과 제목'));
    await tester.pumpAndSettle();

    expect(capturedRouteName, '/jeontong/eighty/result');
    expect(capturedArguments, isA<String>());
    expect(capturedArguments, 'A01');
  });
}
