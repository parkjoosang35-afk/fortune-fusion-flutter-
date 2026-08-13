// 2026-08-13 결정. 정통사주 결과 in-memory LRU + TTL 캐시.
// - 신 dependency 0. dart:collection(+model/builder) 만.
// - 결정론 유지: TTL/LRU eviction 은 삽입 순서 + 명시적 now() 주입만으로 동작.
// - report_builder / 모델 / 결과화면 본문 무수정.
//
// [STEP 0-B 실측 시그니처 반영] JeontongReportBuilder.build()의 첫 positional
// 인자는 `JeontongCategoryEntry entry` (문자열 categoryCode 가 아니다). 따라서
// 이 캐시의 진입점도 `entry: JeontongCategoryEntry` 를 받아 그대로
// JeontongReportBuilder.build(entry, ...) 에 위임한다. 캐시 키의 문자열
// 구성요소는 entry.id 를 사용한다.
import 'dart:collection';

import '../../fortune/shared/domain/fortune_report_model.dart';
import 'jeontong_eighty_matrix.dart';
import 'jeontong_eighty_report_builder.dart';

class JeontongReportCache {
  JeontongReportCache({
    this.capacity = 240,
    this.ttl = const Duration(hours: 24),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final int capacity;
  final Duration ttl;
  final DateTime Function() _now;

  // LinkedHashMap = 삽입 순서 유지 → LRU 로 안전.
  final LinkedHashMap<String, _Entry> _entries = LinkedHashMap<String, _Entry>();

  int _hits = 0;
  int _misses = 0;
  int _evictions = 0;

  /// 캐시 히트면 그대로, 미스면 [JeontongReportBuilder.build] 를 1회 호출한 뒤
  /// 저장하고 반환한다.
  FortuneReport getOrBuild({
    required JeontongCategoryEntry entry,
    DateTime? date,
    String? userId,
    DateTime? birthDateTimeUtc,
    String? gender,
    bool? isLunar,
  }) {
    final key = _key(entry.id, userId, birthDateTimeUtc, gender, isLunar);
    final t = _now();

    final hit = _entries.remove(key);
    if (hit != null && t.isBefore(hit.expiresAt)) {
      _entries[key] = hit; // touch: 삽입 순서 재정렬 = LRU 갱신
      _hits++;
      return hit.value;
    }
    _misses++;

    final built = JeontongReportBuilder.build(
      entry,
      date: date,
      userId: userId,
      birthDateTimeUtc: birthDateTimeUtc,
      gender: gender,
      isLunar: isLunar,
    );

    _entries[key] = _Entry(built, t.add(ttl));
    while (_entries.length > capacity) {
      _entries.remove(_entries.keys.first); // 가장 오래된 것부터 제거
      _evictions++;
    }
    return built;
  }

  int get size => _entries.length;

  void clear() {
    _entries.clear();
    _hits = 0;
    _misses = 0;
    _evictions = 0;
  }

  int get hits => _hits;
  int get misses => _misses;
  int get evictions => _evictions;

  /// 카운터만 0 으로 되돌린다. 캐시 엔트리는 유지 (테스트/관측 재시작용).
  void resetCounters() {
    _hits = 0;
    _misses = 0;
    _evictions = 0;
  }

  String _key(
    String catId,
    String? uid,
    DateTime? bdt,
    String? gen,
    bool? lun,
  ) {
    return [
      catId,
      uid ?? '',
      bdt?.toIso8601String() ?? '',
      gen ?? '',
      lun == null ? '' : (lun ? '1' : '0'),
    ].join('|');
  }
}

class _Entry {
  _Entry(this.value, this.expiresAt);
  final FortuneReport value;
  final DateTime expiresAt;
}

/// 앱 전역 공용 인스턴스. 새 Provider·DI 를 만들지 않는다.
final JeontongReportCache jeontongReportCache = JeontongReportCache();
