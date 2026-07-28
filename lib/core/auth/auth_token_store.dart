import 'package:shared_preferences/shared_preferences.dart';

/// 로드맵④(회원 인증 시스템 정공법) — JWT Bearer 토큰 저장/조회 담당.
///
/// admin_web의 관리자 세션(HttpOnly Cookie 기반, src/lib/session.ts)과는 별도로,
/// Flutter 모바일 앱은 Bearer 토큰을 SharedPreferences에 저장한 뒤 매 요청
/// `Authorization: Bearer <token>` 헤더로 전달하는 방식을 사용한다(MVP 범위,
/// flutter_secure_storage 미도입 — 기존 Mock의 `_kTokenKey` 패턴과 동일 선상).
///
/// 리프레시 토큰은 두지 않는다(03§9.2 과설계 방지 원칙) — 서버 토큰 만료(30일) 시
/// 재로그인을 유도한다.
///
/// 12개 기존 Repository의 `_userId = 1` 하드코딩을 실 로그인 사용자 ID로 교체할 때
/// [currentUserId]를 사용한다(비로그인 시 폴백값 1 유지 — 게스트/데모 열람 허용).
class AuthTokenStore {
  AuthTokenStore._();

  static const _kTokenKey = 'auth_token';
  static const _kUserIdKey = 'auth_user_id';

  /// 폴백 사용자 ID — 비로그인 상태에서도 각 Repository가 API를 호출할 수 있도록
  /// 유지하는 값이다(기존 12개 Repository의 `_userId = 1`과 동일한 테스트 계정).
  static const int fallbackUserId = 1;

  static String? _cachedToken;
  static int? _cachedUserId;

  /// 로그인/회원가입 성공 시 토큰과 userId를 함께 저장한다.
  static Future<void> save({required String token, required int userId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTokenKey, token);
    await prefs.setInt(_kUserIdKey, userId);
    _cachedToken = token;
    _cachedUserId = userId;
  }

  /// 로그아웃/탈퇴 시 토큰을 삭제한다.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kTokenKey);
    await prefs.remove(_kUserIdKey);
    _cachedToken = null;
    _cachedUserId = null;
  }

  /// 저장된 토큰을 반환한다(없으면 null).
  static Future<String?> getToken() async {
    if (_cachedToken != null) return _cachedToken;
    final prefs = await SharedPreferences.getInstance();
    _cachedToken = prefs.getString(_kTokenKey);
    return _cachedToken;
  }

  /// 현재 로그인된 사용자 ID. 비로그인 시 [fallbackUserId]를 반환한다.
  static Future<int> getCurrentUserId() async {
    if (_cachedUserId != null) return _cachedUserId!;
    final prefs = await SharedPreferences.getInstance();
    _cachedUserId = prefs.getInt(_kUserIdKey);
    return _cachedUserId ?? fallbackUserId;
  }

  /// 동기 접근용 — 앱 부팅 시 [getToken]/[getCurrentUserId]를 1회 호출해 캐시를
  /// 채운 뒤 사용한다(각 Repository가 매번 await SharedPreferences 하지 않도록).
  static int? get cachedUserIdOrNull => _cachedUserId;

  /// `Authorization: Bearer <token>` 헤더 맵. 토큰이 없으면 빈 맵(비로그인 호출 허용).
  static Future<Map<String, String>> authHeader() async {
    final token = await getToken();
    if (token == null) return {};
    return {'Authorization': 'Bearer $token'};
  }
}
