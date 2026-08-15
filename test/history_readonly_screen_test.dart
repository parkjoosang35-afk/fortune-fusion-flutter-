import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/core/router/app_router.dart';
import 'package:flutter_app/features/history/presentation/history_readonly_screen.dart';
import 'package:flutter_app/features/home/data/jeontong_history_store.dart';
import 'package:flutter_app/features/home/domain/jeontong_eighty_matrix.dart';

/// [미션 4 · 즐겨찾기/히스토리 진입점 마무리] `HistoryReadOnlyScreen` 자체
/// (5탭 전환, 정통사주 탭 실데이터 렌더링, "한눈에 미리보기" 버튼
/// 네비게이션)에 대한 위젯 테스트가 그동안 부재했던 갭을 메운다.
///
/// 이 화면은 Provider 의존성이 없으므로(AuthTokenStore/JeontongHistoryStore
/// 모두 정적/싱글톤 접근) 별도 MultiProvider wrapping 없이 MaterialApp만으로
/// 테스트 가능하다.
void main() {
  setUp(() {
    JeontongHistoryStore.instance.clearForTest();
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    JeontongHistoryStore.instance.clearForTest();
  });

  testWidgets('기본 진입 시 5개 탭 칩과 타로 탭(준비 중 안내)이 보인다', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: HistoryReadOnlyScreen()),
    );
    await tester.pumpAndSettle();

    for (final label in ['타로', '상담', '관상', '손금', '정통사주']) {
      expect(find.widgetWithText(ChoiceChip, label), findsOneWidget);
    }
    // 기본 선택 탭(index 0 = 타로)은 실데이터 저장소가 없어 "준비 중" 폴백.
    expect(find.textContaining('타로 기록은 준비 중입니다'), findsOneWidget);
  });

  testWidgets('정통사주 탭 전환 시 이력이 없으면 안내 문구, "한눈에 미리보기" 버튼은 항상 노출', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: HistoryReadOnlyScreen()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, '정통사주'));
    await tester.pumpAndSettle();

    expect(find.text('한눈에 미리보기'), findsOneWidget);
    expect(find.text('결과가 아직 없습니다'), findsOneWidget);
  });

  testWidgets('정통사주 이력이 있으면 섹션 뷰가 렌더된다', (tester) async {
    JeontongHistoryStore.instance.record(
      userId: '1',
      categoryId: 'A01',
      title: 'A01 결과 제목',
      subtitle: 'A01 결과 부제',
      createdAtUtc: DateTime.utc(2026, 1, 1),
    );

    await tester.pumpWidget(
      const MaterialApp(home: HistoryReadOnlyScreen()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, '정통사주'));
    await tester.pumpAndSettle();

    expect(find.textContaining('A01 결과 제목'), findsOneWidget);
  });

  testWidgets(
    '"한눈에 미리보기" 버튼 탭 시 /jeontong/overview 라우트로 userId Map 전달',
    (tester) async {
      JeontongHistoryStore.instance.record(
        userId: '1',
        categoryId: 'A01',
        title: 'A01 결과 제목',
        subtitle: 'A01 결과 부제',
        createdAtUtc: DateTime.utc(2026, 1, 1),
      );

      String? capturedRouteName;
      Object? capturedArguments;

      await tester.pumpWidget(
        MaterialApp(
          home: const HistoryReadOnlyScreen(),
          onGenerateRoute: (settings) {
            if (settings.name == '/jeontong/overview') {
              capturedRouteName = settings.name;
              capturedArguments = settings.arguments;
              return MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('overview-stub')),
              );
            }
            return AppRouter.onGenerateRoute(settings);
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ChoiceChip, '정통사주'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('한눈에 미리보기'));
      await tester.pumpAndSettle();

      expect(capturedRouteName, '/jeontong/overview');
      expect(capturedArguments, isA<Map>());
      expect((capturedArguments as Map)['userId'], isA<String>());
    },
  );

  testWidgets('타로→정통사주→타로 탭 왕복 전환 시 상태가 유지된다(크래시 없음)', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: HistoryReadOnlyScreen()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, '정통사주'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '타로'));
    await tester.pumpAndSettle();

    expect(find.textContaining('타로 기록은 준비 중입니다'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('JeontongEightyMatrix 유효성 sanity — id 개수(회귀 안전장치, 2026-08-16 69종으로 확정)', () {
    // [2026-08-16] E01~E07/G09/H06/H08/H09 11종이 "구현 불가능하면 즉시
    // 삭제" 원칙에 따라 카탈로그에서 완전히 제거되어 80종에서 69종으로
    // 축소되었다. 80이라는 숫자에 집착하지 않는다(사용자 확정 지시 §4/§7).
    expect(JeontongEightyMatrix.all.length, 69);
  });
}
