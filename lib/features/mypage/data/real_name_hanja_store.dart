import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [마이페이지 리뉴얼 · DEV 2026-11-06 §S14] "이름(한자 · 선택)" 로컬 전용
/// 저장소.
///
/// README S14 스펙은 "이름(한글)"과 "이름(한자 · 선택)" 두 입력을 요구한다.
/// 한글 이름은 기존 서버 필드 [UserModel.realName]/`PATCH /api/.../profile`
/// (`real_name` 컬럼, `admin_web/prisma/schema.prisma` UserProfile)에 이미
/// 저장 경로가 있어 그대로 재사용한다. 하지만 한자 이름은 admin_web
/// 스키마에도, `UserModel`에도 대응 필드가 전혀 없다 — 이 작업(flutter_app
/// 저장소 한정)은 백엔드 스키마를 변경할 권한/범위가 없으므로(운영 정책상
/// 3개 저장소 커밋을 섞지 않음), 새 서버 컬럼을 임의로 추가하지 않는다
/// ("로직은 그대로, 스킨만 교체"/"기획 확인 없는 서버 필드 임의 추가 금지"
/// 원칙 — S12에서 "야간 알림" 토글에 적용한 것과 동일한 판단).
///
/// 대신 `home/data/jeontong_profile_store.dart`(JeontongProfileStore)와
/// 완전히 동일한 설계(SharedPreferences, 사용자별 키 분리, 실패 시 조용히
/// 무시)를 따르는 경량 로컬 저장소를 둔다 — 한자 이름은 "선택" 입력이고
/// 성명학 풀이 등 클라이언트 로컬에서만 참고하면 되는 보조 정보이므로,
/// 서버 영속화 없이도 README가 요구하는 "입력하면 다음에도 남아있는" UX는
/// 충분히 만족한다. 추후 서버 컬럼이 기획 확정되면 이 저장소를
/// `AuthProvider.updateProfile`로 교체하기만 하면 된다(이 화면의 호출부만
/// 바꾸면 되는 구조).
class RealNameHanjaStore {
  RealNameHanjaStore._();

  static const String _kPrefsKeyPrefix = 'mypage_real_name_hanja_v1_';

  static final Map<String, String?> _cache = {};
  static bool _prefsBroken = false;

  static String _prefsKey(String userId) => '$_kPrefsKeyPrefix$userId';

  /// 저장된 한자 이름을 조회한다(없으면 null).
  static Future<String?> get(String userId) async {
    if (_cache.containsKey(userId)) return _cache[userId];
    if (!_prefsBroken) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final value = prefs.getString(_prefsKey(userId));
        _cache[userId] = (value == null || value.isEmpty) ? null : value;
        return _cache[userId];
      } catch (_) {
        _prefsBroken = true;
      }
    }
    _cache[userId] = null;
    return null;
  }

  /// 한자 이름을 저장(덮어쓰기)한다. 빈 문자열을 넘기면 삭제와 동일하게
  /// 처리한다.
  static Future<void> save(String userId, String value) async {
    final trimmed = value.trim();
    _cache[userId] = trimmed.isEmpty ? null : trimmed;
    if (_prefsBroken) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (trimmed.isEmpty) {
        await prefs.remove(_prefsKey(userId));
      } else {
        await prefs.setString(_prefsKey(userId), trimmed);
      }
    } catch (_) {
      _prefsBroken = true;
    }
  }

  @visibleForTesting
  static void clearForTest() {
    _cache.clear();
    _prefsBroken = false;
  }
}
