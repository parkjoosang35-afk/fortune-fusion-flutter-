import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/history/presentation/history_jeontong_overview_screen.dart';
import 'package:flutter_app/features/home/data/jeontong_history_store.dart';
import 'package:flutter_app/features/home/domain/jeontong_eighty_matrix.dart';

const _testUserId = 'overview_test_user';

void main() {
  setUp(() {
    JeontongHistoryStore.instance.clearForTest();
    // 80개 카테고리 전부를 해당 사용자 이력으로 직접 누적한다. 고정
    // 시각(2026-01-01 UTC + index초)을 사용해 DateTime.now() 의존 0건을
    // 유지한다(비용/결정론 원칙 준수).
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

  testWidgets('80개 누적 결과 렌더 + 타이틀 노출', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HistoryJeontongOverviewScreen(userId: _testUserId),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('정통사주 한눈에 보기'), findsOneWidget);
    expect(find.textContaining('A01 평생 총운'), findsOneWidget);
    expect(find.textContaining('H10 개운 습관'), findsOneWidget);
  });

  testWidgets('A 섹션 필터 탭 시 다른 섹션 카드가 사라진다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HistoryJeontongOverviewScreen(userId: _testUserId),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('B01'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'A'));
    await tester.pumpAndSettle();

    expect(find.textContaining('A01 평생 총운'), findsOneWidget);
    expect(find.textContaining('B01'), findsNothing);
  });

  testWidgets('카드 탭 시 결과 라우트로 categoryId(String) 단독 전달', (tester) async {
    String? pushedRoute;
    Object? pushedArgs;

    await tester.pumpWidget(
      MaterialApp(
        home: const HistoryJeontongOverviewScreen(userId: _testUserId),
        onGenerateRoute: (settings) {
          pushedRoute = settings.name;
          pushedArgs = settings.arguments;
          return MaterialPageRoute(builder: (_) => const SizedBox());
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('A01 평생 총운').first);
    await tester.pumpAndSettle();

    expect(pushedRoute, '/jeontong/eighty/result');
    expect(pushedArgs, isA<String>());
    expect(pushedArgs, 'A01');
  });

  testWidgets('섹션 필터 액션 버튼으로 전체 ↔ A 토글 가능', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HistoryJeontongOverviewScreen(userId: _testUserId),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('섹션 필터'), findsOneWidget);

    await tester.tap(find.text('섹션 필터'));
    await tester.pumpAndSettle();

    expect(find.text('A 필터 중'), findsOneWidget);
    expect(find.textContaining('B01'), findsNothing);
  });

  testWidgets('이력이 없는 사용자는 안내 문구만 표시', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HistoryJeontongOverviewScreen(userId: 'no_history_user'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('아직 열람한 결과가 없습니다'), findsOneWidget);
  });
}
