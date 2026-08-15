import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 정통사주 결과 카드 즐겨찾기 스토어.
///
/// [STEP 0 raw 확인] 이 파일 자체는 미션 가정 경로
/// (`lib/features/home/data/jeontong_bookmark_store.dart`)와 실제 관례 경로가
/// 일치해 별도 조정이 필요 없다(신규 dependency 0 — shared_preferences는
/// pubspec.yaml에 이미 등록됨, 새로 추가하지 않음).
///
/// - 사용자당 최대 20건(하드캡)
/// - 삽입 순서 유지(Set 순회 순서 = 삽입 순서, 결정론)
/// - dedup: 동일 (userId, categoryCode) 재추가 = idempotent no-op, true 반환
/// - SharedPreferences 예외 → in-memory fallback (crash 금지)
/// - 룰 매트릭스(jeontong_eighty_matrix.dart)·체크섬(jeontong_rules_hash_test)
///   무접촉(읽기조차 하지 않음, 완전 격리).
///
/// [설계 노트] 이 스토어는 싱글톤이 아니라 인스턴스화 가능한 일반 클래스다
/// (기존 `JeontongHistoryStore.instance` 싱글톤 패턴과 다름). 화면마다 자체
/// 인스턴스를 생성해도, `SharedPreferences` 영속화를 공용 진리 소스로 삼아
/// 각 인스턴스가 `_ensureLoaded()` 시점에 최신 상태를 다시 읽어오므로 결과적
/// 일관성이 유지된다(테스트의 "인스턴스 재생성 후 동일 데이터 로드" 케이스가
/// 이 설계를 그대로 검증한다).
class JeontongBookmarkStore extends ChangeNotifier {
  static const String _kPrefsKey = 'jeontong_bookmarks_v1';
  static const int _kMax = 20;

  /// userId → 삽입 순서를 유지하는 카테고리 코드 집합.
  final Map<String, Set<String>> _cache = <String, Set<String>>{};
  bool _loaded = false;
  bool _prefsBroken = false;

  /// Snack 문구(raw 잠금 — 테스트가 이 상수를 직접 참조).
  static const String kSnackFullMessage = '즐겨찾기는 최대 20개까지';
  static const String kSnackAddedMessage = '즐겨찾기 추가';
  static const String kSnackRemovedMessage = '즐겨찾기 해제';

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPrefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          decoded.forEach((k, v) {
            if (k is String && v is List) {
              _cache[k] = <String>{
                for (final e in v)
                  if (e is String) e,
              };
            }
          });
        }
      }
    } catch (_) {
      // SharedPreferences 접근 실패 → in-memory 만 유지(crash 금지).
      _prefsBroken = true;
    } finally {
      _loaded = true;
    }
  }

  Future<void> _persist() async {
    if (_prefsBroken) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final serial = <String, List<String>>{
        for (final e in _cache.entries) e.key: e.value.toList(growable: false),
      };
      await prefs.setString(_kPrefsKey, jsonEncode(serial));
    } catch (_) {
      _prefsBroken = true;
    }
  }

  /// 조회 — null 아님, 빈 Set 반환.
  Future<Set<String>> get(String userId) async {
    await _ensureLoaded();
    final s = _cache[userId];
    if (s == null) return <String>{};
    return <String>{...s};
  }

  /// 동기 조회(UI 렌더 시 캐시 히트, 사전에 [get]/[contains]/[add] 등으로
  /// `_ensureLoaded`가 최소 1회 실행되어야 정확한 값을 반환한다).
  Set<String> getSync(String userId) {
    final s = _cache[userId];
    if (s == null) return <String>{};
    return <String>{...s};
  }

  Future<bool> contains(String userId, String categoryCode) async {
    await _ensureLoaded();
    return _cache[userId]?.contains(categoryCode) ?? false;
  }

  /// 추가 — 성공/idempotent 시 true, 20건 초과 시 false.
  Future<bool> add(String userId, String categoryCode) async {
    await _ensureLoaded();
    final set = _cache.putIfAbsent(userId, () => <String>{});
    if (set.contains(categoryCode)) {
      return true; // idempotent no-op
    }
    if (set.length >= _kMax) {
      return false; // 하드캡
    }
    set.add(categoryCode);
    await _persist();
    notifyListeners();
    return true;
  }

  /// 제거 — 존재 여부 무관 true(idempotent).
  Future<bool> remove(String userId, String categoryCode) async {
    await _ensureLoaded();
    final set = _cache[userId];
    if (set == null || !set.contains(categoryCode)) {
      return true;
    }
    set.remove(categoryCode);
    if (set.isEmpty) _cache.remove(userId);
    await _persist();
    notifyListeners();
    return true;
  }

  /// 토글 — 반환값:
  ///   true  = 추가됨(또는 이미 있었음)
  ///   false = 제거됨
  ///   null  = 하드캡 도달로 추가 실패
  Future<bool?> toggle(String userId, String categoryCode) async {
    await _ensureLoaded();
    final has = _cache[userId]?.contains(categoryCode) ?? false;
    if (has) {
      await remove(userId, categoryCode);
      return false;
    }
    final ok = await add(userId, categoryCode);
    if (!ok) return null;
    return true;
  }

  Future<int> count(String userId) async {
    await _ensureLoaded();
    return _cache[userId]?.length ?? 0;
  }

  int countSync(String userId) => _cache[userId]?.length ?? 0;

  /// 테스트/디버그 전용 리셋.
  @visibleForTesting
  Future<void> clearForTest() async {
    _cache.clear();
    _loaded = false;
    _prefsBroken = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kPrefsKey);
    } catch (_) {
      // ignore
    }
  }
}
