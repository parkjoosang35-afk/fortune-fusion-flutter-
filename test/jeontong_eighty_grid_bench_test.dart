import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/features/home/presentation/jeontong_eighty_grid_screen.dart';
import 'package:flutter_app/features/home/data/jeontong_history_store.dart';
import 'package:flutter_app/features/home/domain/jeontong_eighty_matrix.dart';

void main() {
  testWidgets('JeontongEightyGridScreen 전체 카테고리 렌더 + 진입 시 전체 일괄 record', (
    tester,
  ) async {
    const userId = 'u-grid-test';
    JeontongHistoryStore.instance.clearForTest();

    // ListView.builder는 지연 렌더링이므로, 뷰포트 밖 카드까지 모두
    // 화면에 나타나는지 확인하려면 스크롤을 통해 순회해야 한다.
    addTearDown(tester.view.resetPhysicalSize);
    tester.view.physicalSize = const Size(1200, 20000);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      const MaterialApp(home: JeontongEightyGridScreen(userId: userId)),
    );
    await tester.pumpAndSettle();

    for (final entry in JeontongEightyMatrix.all) {
      expect(
        find.text(entry.id),
        findsOneWidget,
        reason: '${entry.id} 카드가 화면에 렌더되지 않음',
      );
    }

    expect(
      JeontongHistoryStore.instance.list(userId).length,
      greaterThanOrEqualTo(JeontongEightyMatrix.all.length),
      reason: '진입 시 전체 카테고리 일괄 record 가 수행되지 않음',
    );

    JeontongHistoryStore.instance.clearForTest();
  });
}
