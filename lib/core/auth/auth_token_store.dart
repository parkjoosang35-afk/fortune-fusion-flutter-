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
/// [신통방통 엔진 통합 — STEP 2 "실 사용자 인증 전환"] 과거에는
/// `getCurrentUserId()`가 비로그인 시에도 조용히 `fallbackUserId`(=1, 서버
/// 시딩 테스트 계정)로 폴백해, 실서버(`sintong.kr`)에서 "로그인 안 한
/// 사용자가 테스트 계정 1번의 데이터/결과를 그대로 호출"하는 문제가 있었다
/// (실제로 WalletRepository/PouchBoxRepository에서 "비회원인데 테스트 계정
/// 잔액이 보임" 버그가 이미 한 차례 보고된 바 있다 — 아래 각 파일 참고).
/// 이제 [getCurrentUserId]는 비로그인 상태에서 **명시적으로 null을
/// 반환**한다 — "실패를 Mock/폴백으로 채우지 않는다"는 원칙을 인증
/// 계층까지 일관되게 적용한 것이다. 호출부는 null을 받으면 반드시
/// "로그인이 필요합니다" 류의 정직한 실패로 처리해야 한다(가짜 성공 금지).
class AuthTokenStore {
  AuthTokenStore._();

  static const _kTokenKey = 'auth_token';
  static const _kUserIdKey = 'auth_user_id';

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

  /// 현재 로그인된 사용자 ID. **비로그인 시 null을 반환한다**(STEP 2 —
  /// 더 이상 테스트 계정으로 조용히 폴백하지 않음). 호출부는 null을
  /// "로그인이 필요합니다" 같은 명시적 실패로 처리해야 한다.
  static Future<int?> getCurrentUserId() async {
    if (_cachedUserId != null) return _cachedUserId;
    final prefs = await SharedPreferences.getInstance();
    _cachedUserId = prefs.getInt(_kUserIdKey);
    return _cachedUserId;
  }

  /// 실제로 저장된 로그인 토큰이 있는지 여부. [getCurrentUserId]가 이제
  /// 비로그인 시 null을 반환하므로 원래 이 메서드가 막으려던 "비로그인인데
  /// 테스트 계정 데이터가 보이는" 문제는 구조적으로 재발할 수 없지만,
  /// 기존 23개 호출부가 이 메서드로 "로그인 여부"를 먼저 확인하는 패턴을
  /// 그대로 쓰고 있어 호환을 위해 유지한다.
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
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
