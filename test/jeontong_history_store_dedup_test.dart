import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/features/home/data/jeontong_history_store.dart';

void main() {
  test('record dedup keeps latest entry per (userId, categoryId)', () {
    final s = JeontongHistoryStore.instance;
    final userId = 'u-${DateTime.now().microsecondsSinceEpoch}';
    s.record(
      userId: userId,
      categoryId: 'A01',
      title: '평생 총운 v1',
      subtitle: 'A',
      createdAtUtc: DateTime.utc(2026, 1, 1, 10, 0),
    );
    expect(s.list(userId).length, 1);
    s.record(
      userId: userId,
      categoryId: 'A01',
      title: '평생 총운 v2',
      subtitle: 'A',
      createdAtUtc: DateTime.utc(2026, 8, 14, 9, 0),
    );
    expect(s.list(userId).length, 1); // ★ 핵심: 여전히 1건
    expect(s.list(userId).single.title, '평생 총운 v2');
    expect(
      s.list(userId).single.createdAtUtc,
      DateTime.utc(2026, 8, 14, 9, 0),
    );
  });

  test('distinct categoryIds keep distinct entries (max 80 per user)', () {
    final s = JeontongHistoryStore.instance;
    final userId = 'u-${DateTime.now().microsecondsSinceEpoch}';
    for (var i = 0; i < 80; i++) {
      final code =
          String.fromCharCode(65 + (i ~/ 10)) +
          (i % 10 + 1).toString().padLeft(2, '0');
      s.record(
        userId: userId,
        categoryId: code,
        title: 't-$code',
        subtitle: code[0],
        createdAtUtc: DateTime.utc(2026, 8, 14),
      );
    }
    expect(s.list(userId).length, 80);
    // 동일 카테고리 5번 재기록 → 여전히 80
    for (var n = 0; n < 5; n++) {
      s.record(
        userId: userId,
        categoryId: 'A01',
        title: '평생 총운 v$n',
        subtitle: 'A',
        createdAtUtc: DateTime.utc(2026, 8, 14, n, 0),
      );
    }
    expect(s.list(userId).length, 80);
  });
}
