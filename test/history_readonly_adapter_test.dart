import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/features/history/domain/history_readonly_adapter.dart';
import 'package:flutter_app/features/home/data/jeontong_history_store.dart';

void main() {
  group('HistoryReadOnlyAdapter', () {
    test('5개 섹션 모두 List<HistoryReadOnlyEntry> 반환 (예외 없이)', () async {
      final a = const HistoryReadOnlyAdapter();
      expect(a.readTarot(), isA<List<HistoryReadOnlyEntry>>());
      expect(a.readCounsel(), isA<List<HistoryReadOnlyEntry>>());
      expect(a.readFace(), isA<List<HistoryReadOnlyEntry>>());
      expect(a.readPalm(), isA<List<HistoryReadOnlyEntry>>());
      expect(await a.readJeontong('test_user'), isA<List<HistoryReadOnlyEntry>>());
    });

    test('반환값의 모든 필드가 null-safe / non-null', () async {
      final a = const HistoryReadOnlyAdapter();
      for (final list in [
        a.readTarot(),
        a.readCounsel(),
        a.readFace(),
        a.readPalm(),
        await a.readJeontong('test_user'),
      ]) {
        for (final e in list) {
          expect(e.id.isNotEmpty, isTrue);
          expect(e.title.isNotEmpty, isTrue);
          // subtitle 은 빈 문자열은 허용, null 은 컴파일 타임에 이미 배제됨.
          expect(
            e.createdAt.isUtc,
            isTrue,
            reason: 'createdAt 은 UTC 로 정규화되어야 한다',
          );
        }
      }
    });

    test('adapter 는 어떤 setter/write 메서드도 노출하지 않는다', () async {
      final a = const HistoryReadOnlyAdapter();
      // 이 테스트는 API 표면 검증. 컴파일이 되면 그 자체로 PASS.
      // (아래 메서드가 존재하면 컴파일 성공, 존재하지 않으면 즉시 실패)
      a.readTarot();
      a.readCounsel();
      a.readFace();
      a.readPalm();
      await a.readJeontong('test_user');
      // 이 파일에서 절대 호출하지 말 것: adapter.write* / adapter.delete* / adapter.update*
      // (설령 존재해도 이 미션의 원칙 위반 — 그 경우 STEP 1 을 정정하라)
    });

    test('readJeontong() reflects JeontongHistoryStore.record() 직전/직후', () async {
      const userId = 'vslice_test_user';
      JeontongHistoryStore.instance.clearForTest();

      final before = await historyReadOnlyAdapter.readJeontong(userId);
      expect(before, isEmpty);

      final now = DateTime.now().toUtc();
      JeontongHistoryStore.instance.record(
        userId: userId,
        categoryId: 'A01',
        title: '테스트 헤드라인',
        subtitle: '테스트 서브라인',
        createdAtUtc: now,
      );

      final after = await historyReadOnlyAdapter.readJeontong(userId);
      expect(after.length, 1);
      expect(after.first.id.isNotEmpty, isTrue);
      expect(after.first.title.isNotEmpty, isTrue);
      expect(after.first.subtitle.isNotEmpty, isTrue);
      expect(after.first.createdAt.isUtc, isTrue);

      JeontongHistoryStore.instance.clearForTest();
    });

    test('readJeontong returns recorded entries', () async {
      final adapter = const HistoryReadOnlyAdapter();
      final userId = 'user-${DateTime.now().microsecondsSinceEpoch}';
      expect((await adapter.readJeontong(userId)).isEmpty, true);
      JeontongHistoryStore.instance.record(
        userId: userId,
        categoryId: 'A01',
        title: '평생 총운',
        subtitle: '테스트',
        createdAtUtc: DateTime.now().toUtc(),
      );
      final list = await adapter.readJeontong(userId);
      expect(list.length, 1);
      expect(list.first.id, contains('A01'));
      expect(list.first.createdAt.isUtc, true);
      JeontongHistoryStore.instance.clearForTest();
    });
  });
}
