import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/history/presentation/history_jeontong_overview_screen.dart';
import 'package:flutter_app/features/home/data/jeontong_history_store.dart';
import 'package:flutter_app/features/home/domain/jeontong_eighty_matrix.dart';

const _testUserId = 'keyword_search_test_user';

void main() {
  setUp(() {
    JeontongHistoryStore.instance.clearForTest();
    // 80개 카테고리 전부를 해당 사용자 이력으로 직접 누적한다. 고정
    // 시각(2026-01-01 UTC + index초)을 사용해 DateTime.now() 의존 0건을
    // 유지한다(비용/결정론 원칙 준수). test 자체에서도 DateTime.now()는
    // 호출하지 않는다(base 는 리터럴 상수 DateTime.utc 사용).
    final base = DateTime.utc(2026, 1, 1);
    final all = JeontongEightyMatrix.all;
    for (var i = 0; i < all.length; i++) {
      final entry = all[i];
      JeontongHistoryStore.instance.record(
        userId: _testUserId,
        categoryId: entry.id,
        title: '${entry.id} ${entry.title}',
        subtitle: '${entry.title} 요약',
        createdAtUtc: base.add(Duration(seconds: i)),
      );
    }
  });

  tearDown(() {
    JeontongHistoryStore.instance.clearForTest();
  });

  testWidgets('검색바 1개 존재 + "재물" 입력 시 매칭 카드만 표시', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HistoryJeontongOverviewScreen(userId: _testUserId),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    // 검색 전: 무관한 카드(A01)도 보임
    expect(find.textContaining('A01 평생 총운'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '재물');
    await tester.pumpAndSettle();

    // "재물"이 title 에 포함된 카드(A03 평생 재물운)는 남고,
    expect(find.textContaining('A03 평생 재물운'), findsOneWidget);
    // 포함되지 않은 카드(A01 평생 총운)는 사라진다.
    expect(find.textContaining('A01 평생 총운'), findsNothing);
  });

  testWidgets('"A01" 입력 시 id 매칭 1건만 표시', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HistoryJeontongOverviewScreen(userId: _testUserId),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'A01');
    await tester.pumpAndSettle();

    expect(find.textContaining('A01 평생 총운'), findsOneWidget);
    expect(find.textContaining('A02'), findsNothing);
    expect(find.textContaining('B01'), findsNothing);
  });

  testWidgets('매치 0건("ZZZ") 이면 "검색 결과 없음" 안내', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HistoryJeontongOverviewScreen(userId: _testUserId),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'ZZZ');
    await tester.pumpAndSettle();

    expect(find.text('검색 결과 없음'), findsOneWidget);
    // 검색바 자체의 hint 문구("예: 재물, A01, 정재")에도 'A01'이 포함되어
    // 있으므로, 카드 텍스트 특정 문자열로 정확히 검증한다.
    expect(find.textContaining('A01 평생 총운'), findsNothing);
  });

  testWidgets('검색바 clear(X) 탭 시 전체 80건 복귀', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HistoryJeontongOverviewScreen(userId: _testUserId),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'A01');
    await tester.pumpAndSettle();
    expect(find.textContaining('B01'), findsNothing);

    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();

    expect(find.textContaining('A01 평생 총운'), findsOneWidget);
    expect(find.textContaining('H10'), findsWidgets);
  });
}
