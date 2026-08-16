import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/features/history/presentation/history_jeontong_overview_screen.dart';
import 'package:flutter_app/features/home/data/jeontong_bookmark_store.dart';
import 'package:flutter_app/features/home/data/jeontong_history_store.dart';
import 'package:flutter_app/features/home/domain/jeontong_eighty_matrix.dart';

const _testUserId = 'overview_test_user';

void main() {
  setUp(() {
    JeontongHistoryStore.instance.clearForTest();
    // [미션 4] "⭐ 즐겨찾기만 보기" 스위치가 JeontongBookmarkStore(내부적으로
    // SharedPreferences 사용)를 조회하므로, 다른 jeontong_*_test.dart와
    // 동일한 관례로 빈 값 초기화해 결정론적 "즐겨찾기 없음" 경로를 보장한다.
    SharedPreferences.setMockInitialValues({});
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

  // [미션 4 · 즐겨찾기/히스토리 진입점 마무리] "⭐ 즐겨찾기만 보기" 스위치가
  // 실제로 JeontongBookmarkStore 데이터를 반영해 목록을 필터링하는지
  // 검증한다. 스토어 레벨 로직(add/toggle/dedup 등)은 이미
  // jeontong_bookmark_store_test.dart에서 충분히 검증됐으므로, 여기서는
  // "화면이 스토어를 올바르게 소비하는가"라는 UI 통합 레벨만 확인한다.
  testWidgets('즐겨찾기 없음 상태에서 스위치 ON → 전체 목록이 사라진다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HistoryJeontongOverviewScreen(userId: _testUserId),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('A01 평생 총운'), findsOneWidget);

    final switchFinder = find.byKey(
      const ValueKey('jeontong_only_bookmarks_switch'),
    );
    expect(switchFinder, findsOneWidget);

    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    // 즐겨찾기가 하나도 없으므로 A01을 포함한 모든 카드가 사라져야 한다.
    expect(find.textContaining('A01 평생 총운'), findsNothing);
    expect(find.text('해당 섹션 결과가 없습니다'), findsOneWidget);
  });

  testWidgets('A01만 즐겨찾기된 상태에서 스위치 ON → A01만 남고 나머지는 사라진다', (tester) async {
    final bookmarks = JeontongBookmarkStore();
    await bookmarks.add(_testUserId, 'A01');

    await tester.pumpWidget(
      const MaterialApp(
        home: HistoryJeontongOverviewScreen(userId: _testUserId),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('A01 평생 총운'), findsOneWidget);
    expect(find.textContaining('B01'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('jeontong_only_bookmarks_switch')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('A01 평생 총운'), findsOneWidget);
    expect(find.textContaining('B01'), findsNothing);
  });

  testWidgets('스위치 ON 후 다시 OFF → 전체 목록이 복원된다', (tester) async {
    final bookmarks = JeontongBookmarkStore();
    await bookmarks.add(_testUserId, 'A01');

    await tester.pumpWidget(
      const MaterialApp(
        home: HistoryJeontongOverviewScreen(userId: _testUserId),
      ),
    );
    await tester.pumpAndSettle();

    final switchFinder = find.byKey(
      const ValueKey('jeontong_only_bookmarks_switch'),
    );
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();
    expect(find.textContaining('B01'), findsNothing);

    await tester.tap(switchFinder);
    await tester.pumpAndSettle();
    expect(find.textContaining('B01'), findsOneWidget);
    expect(find.textContaining('A01 평생 총운'), findsOneWidget);
  });
}
