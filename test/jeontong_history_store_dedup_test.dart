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
    expect(s.list(userId).single.createdAtUtc, DateTime.utc(2026, 8, 14, 9, 0));
  });

  test('distinct categoryIds keep distinct entries (dedup by categoryId)', () {
    // [2026-08-16] 이 테스트는 JeontongEightyMatrix 카탈로그 개수(현재 69종)와
    // 무관하게, JeontongHistoryStore의 categoryId별 dedup 동작 자체를
    // 검증하기 위해 임의로 80개의 합성 categoryId(A01~H10 형식)를 사용한다.
    // 80이라는 숫자는 카탈로그 크기를 의미하지 않으며 단순 테스트 픽스처다.
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
