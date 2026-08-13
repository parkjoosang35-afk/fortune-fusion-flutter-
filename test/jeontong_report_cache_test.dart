import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/features/home/domain/jeontong_eighty_matrix.dart';
import 'package:flutter_app/features/home/domain/jeontong_report_cache.dart';

void main() {
  group('JeontongReportCache', () {
    test('cache hit: 같은 키 두 번 호출 시 동일 인스턴스 반환', () {
      final cache = JeontongReportCache(
        capacity: 8,
        ttl: const Duration(hours: 24),
      );
      final entry = JeontongEightyMatrix.all.first;
      final a = cache.getOrBuild(
        entry: entry,
        userId: 'seed-user-A',
        birthDateTimeUtc: DateTime.utc(1972, 2, 12, 17),
        gender: 'M',
        isLunar: false,
      );
      final b = cache.getOrBuild(
        entry: entry,
        userId: 'seed-user-A',
        birthDateTimeUtc: DateTime.utc(1972, 2, 12, 17),
        gender: 'M',
        isLunar: false,
      );
      // 같은 인스턴스 (identical) 여야 캐시 히트로 확정.
      expect(identical(a, b), isTrue);
      expect(cache.size, 1);
    });

    test('cache miss: 축이 하나만 달라도 별개 엔트리', () {
      final cache = JeontongReportCache();
      final entries = JeontongEightyMatrix.all;
      final e1 = entries[0];
      final e2 = entries[1];
      cache.getOrBuild(entry: e1, userId: 'a');
      cache.getOrBuild(entry: e1, userId: 'b');
      cache.getOrBuild(entry: e2, userId: 'a');
      expect(cache.size, 3);
    });

    test('LRU eviction: capacity 초과 시 가장 오래된 것부터 제거', () {
      final cache = JeontongReportCache(capacity: 2);
      final entries = JeontongEightyMatrix.all;
      cache.getOrBuild(entry: entries[0], userId: 'u1'); // 오래된
      cache.getOrBuild(entry: entries[1], userId: 'u1');
      cache.getOrBuild(entry: entries[2], userId: 'u1'); // 넣으면 entries[0] evict
      expect(cache.size, 2);
    });

    test('TTL: 만료된 엔트리는 재계산', () {
      var t = DateTime.utc(2026, 8, 13, 0, 0, 0);
      final cache = JeontongReportCache(
        ttl: const Duration(hours: 24),
        now: () => t,
      );
      final entry = JeontongEightyMatrix.all.first;
      final r1 = cache.getOrBuild(entry: entry, userId: 'u1');
      t = t.add(const Duration(hours: 23)); // 아직 유효
      final r2 = cache.getOrBuild(entry: entry, userId: 'u1');
      expect(identical(r1, r2), isTrue);
      t = t.add(const Duration(hours: 2)); // TTL 초과
      final r3 = cache.getOrBuild(entry: entry, userId: 'u1');
      expect(identical(r1, r3), isFalse); // 재계산됨
    });

    test('clear: 캐시 비운 뒤 크기 0', () {
      final cache = JeontongReportCache();
      final entry = JeontongEightyMatrix.all.first;
      cache.getOrBuild(entry: entry, userId: 'u1');
      cache.clear();
      expect(cache.size, 0);
    });
  });

  group('JeontongReportCache counters', () {
    test('초기값은 모두 0', () {
      final cache = JeontongReportCache();
      expect(cache.hits, 0);
      expect(cache.misses, 0);
      expect(cache.evictions, 0);
    });

    test('miss → hit 시퀀스가 카운터에 반영', () {
      final cache = JeontongReportCache();
      final a01 = JeontongEightyMatrix.byId('A01')!;
      final a02 = JeontongEightyMatrix.byId('A02')!;
      cache.getOrBuild(entry: a01, userId: 'u1');
      expect(cache.hits, 0);
      expect(cache.misses, 1);
      cache.getOrBuild(entry: a01, userId: 'u1');
      expect(cache.hits, 1);
      expect(cache.misses, 1);
      cache.getOrBuild(entry: a02, userId: 'u1');
      expect(cache.hits, 1);
      expect(cache.misses, 2);
    });

    test('LRU eviction 발생 시 evictions 증가', () {
      final cache = JeontongReportCache(capacity: 2);
      final a01 = JeontongEightyMatrix.byId('A01')!;
      final a02 = JeontongEightyMatrix.byId('A02')!;
      final a03 = JeontongEightyMatrix.byId('A03')!;
      final a04 = JeontongEightyMatrix.byId('A04')!;
      cache.getOrBuild(entry: a01, userId: 'u1');
      cache.getOrBuild(entry: a02, userId: 'u1');
      expect(cache.evictions, 0);
      cache.getOrBuild(entry: a03, userId: 'u1'); // a01 evict
      expect(cache.evictions, 1);
      cache.getOrBuild(entry: a04, userId: 'u1'); // a02 evict
      expect(cache.evictions, 2);
    });

    test('resetCounters 는 엔트리는 유지, 카운터만 0', () {
      final cache = JeontongReportCache();
      final a01 = JeontongEightyMatrix.byId('A01')!;
      cache.getOrBuild(entry: a01, userId: 'u1'); // miss
      cache.getOrBuild(entry: a01, userId: 'u1'); // hit
      final sizeBefore = cache.size;
      cache.resetCounters();
      expect(cache.hits, 0);
      expect(cache.misses, 0);
      expect(cache.evictions, 0);
      expect(cache.size, sizeBefore); // 엔트리는 유지
      // 리셋 후에도 같은 키는 여전히 hit
      cache.getOrBuild(entry: a01, userId: 'u1');
      expect(cache.hits, 1);
      expect(cache.misses, 0);
    });

    test('clear 는 엔트리와 카운터 모두 0', () {
      final cache = JeontongReportCache();
      final a01 = JeontongEightyMatrix.byId('A01')!;
      cache.getOrBuild(entry: a01, userId: 'u1');
      cache.getOrBuild(entry: a01, userId: 'u1');
      cache.clear();
      expect(cache.size, 0);
      expect(cache.hits, 0);
      expect(cache.misses, 0);
      expect(cache.evictions, 0);
    });
  });
}
