import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/features/home/presentation/jeontong_eighty_result_screen.dart';
import 'package:flutter_app/features/home/data/jeontong_bookmark_store.dart';
import 'package:flutter_app/features/home/data/jeontong_history_store.dart';
import 'package:flutter_app/features/home/domain/jeontong_report_cache.dart';

/// [미션 4 · 즐겨찾기/히스토리 진입점 마무리] 결과 화면 헤더의 별 아이콘
/// (`jeontong_bookmark_toggle`) 탭 상호작용을 검증한다.
///
/// 기존 `jeontong_eighty_result_frame_bench_test.dart`는 초기 렌더링
/// 프레임 수만 측정할 뿐, 이 화면의 핵심 기능인 "탭하면 즐겨찾기가
/// 토글되고 아이콘/토스트가 바뀐다"는 실제 사용자 상호작용은 검증하지
/// 않는다 — 이 파일이 그 갭을 메운다.
///
/// 무한 반복 애니메이션(CircularProgressIndicator) 함정 회피를 위해
/// 기존 프레임 벤치 테스트와 동일한 `_pumpUntilLoaded` 헬퍼를 재사용한다.
Future<void> _pumpUntilLoaded(WidgetTester tester) async {
  var guard = 0;
  while (find.byType(CircularProgressIndicator).evaluate().isNotEmpty &&
      guard < 20) {
    await tester.pump(const Duration(milliseconds: 16));
    guard++;
  }
}

void main() {
  const bookmarkKey = ValueKey('jeontong_bookmark_toggle');

  setUp(() {
    jeontongReportCache.clear();
    JeontongHistoryStore.instance.clearForTest();
    // 저장된 프로필/즐겨찾기 모두 없음 상태로 시작(결정론적 "미입력" 경로).
    SharedPreferences.setMockInitialValues({});
  });

  Widget harness({required String categoryId}) {
    return MaterialApp(home: JeontongEightyResultScreen(categoryId: categoryId));
  }

  testWidgets('초기 진입 시 별 아이콘은 미즐겨찾기(테두리) 상태로 보인다', (
    tester,
  ) async {
    await tester.pumpWidget(harness(categoryId: 'A01'));
    await _pumpUntilLoaded(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(bookmarkKey), findsOneWidget);
    final icon = tester.widget<Icon>(
      find.descendant(of: find.byKey(bookmarkKey), matching: find.byType(Icon)),
    );
    expect(icon.icon, Icons.star_border_rounded);
  });

  testWidgets('별 아이콘 탭 → 즐겨찾기 추가(채워진 별) + 추가 토스트 노출', (
    tester,
  ) async {
    await tester.pumpWidget(harness(categoryId: 'A01'));
    await _pumpUntilLoaded(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(bookmarkKey));
    await tester.pumpAndSettle();

    final icon = tester.widget<Icon>(
      find.descendant(of: find.byKey(bookmarkKey), matching: find.byType(Icon)),
    );
    expect(icon.icon, Icons.star_rounded);
    expect(find.text(JeontongBookmarkStore.kSnackAddedMessage), findsOneWidget);

    // 스토어 자체에도 실제로 반영됐는지 교차 확인(1로 fallback 되는 사용자ID).
    final store = JeontongBookmarkStore();
    expect(await store.contains('1', 'A01'), true);
  });

  testWidgets('별 아이콘 두 번 탭 → 추가 후 다시 해제(빈 별) + 해제 토스트', (
    tester,
  ) async {
    await tester.pumpWidget(harness(categoryId: 'A02'));
    await _pumpUntilLoaded(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(bookmarkKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(bookmarkKey));
    await tester.pumpAndSettle();

    final icon = tester.widget<Icon>(
      find.descendant(of: find.byKey(bookmarkKey), matching: find.byType(Icon)),
    );
    expect(icon.icon, Icons.star_border_rounded);
    expect(find.text(JeontongBookmarkStore.kSnackRemovedMessage), findsOneWidget);

    final store = JeontongBookmarkStore();
    expect(await store.contains('1', 'A02'), false);
  });
}
