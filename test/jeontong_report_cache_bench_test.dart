import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/features/home/domain/jeontong_eighty_matrix.dart';
import 'package:flutter_app/features/home/domain/jeontong_report_cache.dart';

void main() {
  group('JeontongReportCache benchmark', () {
    const int reps = 240; // 80 categories 중 8개 × 30 users

    test('cache hit is at least 2x faster than miss (deterministic contract)',
        () {
      final cache = JeontongReportCache(capacity: 512);

      final cats = JeontongEightyMatrix.all.take(8).toList(growable: false);
      final keys = <_Key>[
        for (int u = 0; u < 30; u++)
          for (int c = 0; c < 8; c++) _Key(cats[c], 'user-$u'),
      ];
      final work = keys.take(reps).toList(growable: false);

      // ── warmup: 로직 클래스 로드 안정화용 1회 (측정 제외)
      cache.getOrBuild(entry: cats.first, userId: 'warm');

      // ── phase 1: 전부 miss
      cache.resetCounters();
      final swMiss = Stopwatch()..start();
      for (final k in work) {
        cache.getOrBuild(entry: k.entry, userId: k.uid);
      }
      swMiss.stop();
      expect(cache.misses, reps, reason: 'phase1 은 전부 miss 여야 한다');
      expect(cache.hits, 0);

      // ── phase 2: 같은 순서로 다시 접근 → 전부 hit
      cache.resetCounters();
      final swHit = Stopwatch()..start();
      for (final k in work) {
        cache.getOrBuild(entry: k.entry, userId: k.uid);
      }
      swHit.stop();
      expect(cache.hits, reps, reason: 'phase2 는 전부 hit 여야 한다');
      expect(cache.misses, 0);

      // ── 성능 계약: hit × 2 < miss  (hit 가 최소 2배 빠름)
      // CI 환경 편차를 흡수하기 위해 절대 ms 값이 아니라 비율만 본다.
      final missUs = swMiss.elapsedMicroseconds;
      final hitUs = swHit.elapsedMicroseconds;
      expect(
        hitUs * 2 < missUs,
        isTrue,
        reason:
            '캐시 히트가 미스 대비 최소 2배 빠르지 않음. '
            'missUs=$missUs, hitUs=$hitUs. '
            '캐시가 실제로 동작하는지 확인 필요.',
      );
    });

    test('capacity 초과 시 evictions 이 정확히 (reps - capacity) 만큼', () {
      const int cap = 64;
      const int r = 200;
      final cache = JeontongReportCache(capacity: cap);
      final all = JeontongEightyMatrix.all;
      for (int i = 0; i < r; i++) {
        cache.getOrBuild(entry: all[i % all.length], userId: 'u$i');
      }
      expect(cache.size, cap);
      expect(cache.evictions, r - cap);
    });

    test('TTL 만료 이후 재조회는 다시 miss', () {
      var t = DateTime.utc(2026, 8, 13, 0, 0, 0);
      final cache = JeontongReportCache(
        ttl: const Duration(hours: 24),
        now: () => t,
      );
      final a01 = JeontongEightyMatrix.byId('A01')!;
      cache.getOrBuild(entry: a01, userId: 'u1');
      expect(cache.misses, 1);
      t = t.add(const Duration(hours: 23));
      cache.getOrBuild(entry: a01, userId: 'u1');
      expect(cache.hits, 1);
      t = t.add(const Duration(hours: 2));
      cache.getOrBuild(entry: a01, userId: 'u1');
      expect(cache.misses, 2);
    });
  });
}

class _Key {
  final JeontongCategoryEntry entry;
  final String uid;
  const _Key(this.entry, this.uid);
}
