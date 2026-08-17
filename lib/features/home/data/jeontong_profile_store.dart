import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/jeontong_input.dart';

/// [정통사주 80종 · MVP 라스트 마일] 사용자가 입력 화면(JeontongInputScreen)에서
/// 채운 [JeontongInput](생년월일시/성별/음양력/이름)을 사용자당 1건으로
/// 영속화하는 스토어.
///
/// [기존 패턴 재사용] `JeontongBookmarkStore`(jeontong_bookmark_store.dart)와
/// 완전히 동일한 설계 원칙을 따른다 — `ChangeNotifier` +
/// `SharedPreferences`(주 저장소) + in-memory 캐시(폴백/동기 접근용).
/// SharedPreferences 접근이 어떤 이유로든 실패해도(웹 프라이빗 모드, 플러그인
/// 미등록 등) 크래시 없이 in-memory로만 동작하도록 `_prefsBroken` 플래그로
/// 이후 영속화 시도를 건너뛴다.
///
/// [키 설계] 사용자당 1건만 저장하므로(즐겨찾기처럼 다건 리스트가 아님)
/// prefs 키에 userId를 포함해 사용자별로 분리한다: `jeontong_profile_v1_<uid>`.
class JeontongProfileStore extends ChangeNotifier {
  static const String _kPrefsKeyPrefix = 'jeontong_profile_v1_';

  final Map<String, JeontongInput?> _cache = {};
  bool _prefsBroken = false;

  String _prefsKey(String userId) => '$_kPrefsKeyPrefix$userId';

  Map<String, dynamic> _toJson(JeontongInput input) => {
    'birthDateTimeUtc': input.birthDateTimeUtc.toIso8601String(),
    'gender': input.gender,
    'isLunar': input.isLunar,
    // [신통방통 2단계] 로컬 저장에도 윤달/출생시간모름 상태를 함께 보존한다
    // (반영사항1: birthTimeUnknown은 로컬 전용이 아니라 서버에도 저장
    // 가능해야 한다는 지시 — 로컬 스토어 자체도 계속 지원해야 함).
    'isLeapMonth': input.isLeapMonth,
    'birthTimeUnknown': input.birthTimeUnknown,
    'name': input.name,
  };

  JeontongInput? _fromJson(Map<String, dynamic> json) {
    final bdtRaw = json['birthDateTimeUtc'] as String?;
    final genderRaw = json['gender'] as String?;
    if (bdtRaw == null || genderRaw == null) return null;
    final bdtUtc = DateTime.tryParse(bdtRaw);
    if (bdtUtc == null) return null;
    // 저장 규약: birthDateTimeUtc는 "KST 벽시계 시각을 UTC로 변환한 값"이므로,
    // 복원 시 +9시간 해서 다시 KST 로컬 벽시계 시각으로 되돌린다
    // (JeontongInput.birthDateTimeUtc getter의 역연산).
    final kstLocal = bdtUtc.add(const Duration(hours: 9));
    return JeontongInput(
      birthDateTimeLocal: DateTime(
        kstLocal.year,
        kstLocal.month,
        kstLocal.day,
        kstLocal.hour,
        kstLocal.minute,
      ),
      gender: genderRaw,
      isLunar: json['isLunar'] as bool? ?? false,
      isLeapMonth: json['isLeapMonth'] as bool? ?? false,
      birthTimeUnknown: json['birthTimeUnknown'] as bool? ?? false,
      name: json['name'] as String?,
    );
  }

  /// 저장된 프로필을 비동기로 조회(SharedPreferences 우선, 실패 시 in-memory
  /// 캐시). 저장된 적 없으면 null.
  Future<JeontongInput?> get(String userId) async {
    if (_cache.containsKey(userId)) return _cache[userId];

    if (!_prefsBroken) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_prefsKey(userId));
        if (raw != null) {
          final decoded = jsonDecode(raw) as Map<String, dynamic>;
          final input = _fromJson(decoded);
          _cache[userId] = input;
          return input;
        }
      } catch (_) {
        _prefsBroken = true;
      }
    }

    _cache[userId] = null;
    return null;
  }

  /// 동기 캐시 조회 — 이미 [get]/[save]로 캐시가 채워져 있을 때만 유효한 값을
  /// 반환한다(캐시 미스면 null — 저장된 값이 있어도 아직 로드 전이면 null).
  JeontongInput? getSync(String userId) => _cache[userId];

  /// 프로필을 저장(덮어쓰기)한다.
  Future<void> save(String userId, JeontongInput input) async {
    _cache[userId] = input;
    notifyListeners();

    if (_prefsBroken) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey(userId), jsonEncode(_toJson(input)));
    } catch (_) {
      _prefsBroken = true;
    }
  }

  /// 저장된 프로필을 삭제한다.
  Future<void> clear(String userId) async {
    _cache[userId] = null;
    notifyListeners();

    if (_prefsBroken) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey(userId));
    } catch (_) {
      _prefsBroken = true;
    }
  }

  /// 테스트 전용 — 모든 캐시/폴백 플래그 초기화(SharedPreferences 데이터
  /// 자체는 건드리지 않음 — 테스트에서는
  /// `SharedPreferences.setMockInitialValues({})`로 별도 초기화한다).
  @visibleForTesting
  void clearForTest() {
    _cache.clear();
    _prefsBroken = false;
  }
}

/// 앱 전역 공용 인스턴스. 새 Provider/DI 를 만들지 않고,
/// [JeontongBookmarkStore]와 동일한 방식(전역 싱글톤 인스턴스 직접 생성)을
/// 재사용한다.
final JeontongProfileStore jeontongProfileStore = JeontongProfileStore();
