import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api/api_result.dart';
import '../../../core/utils/mock_delay.dart';
import '../domain/user_model.dart';

/// 06단계 §4.1 `/v1/auth`, `/v1/users` 대응 Repository
/// 10단계(A안): Mock 구현 - 로컬 SharedPreferences에 세션을 저장하여 실제 로그인처럼 동작
/// 향후 실제 NestJS API 연동 시 이 클래스의 내부 구현만 http 호출로 교체하면
/// AuthProvider 이상 레이어는 변경 없이 그대로 재사용 가능(07단계 아키텍처 원칙).
class AuthRepository {
  static const _kUserKey = 'auth_user';
  static const _kTokenKey = 'auth_token';

  /// Phase2-2: 이메일 가입 중복 체크용 로컬 저장소(Mock).
  /// 실제 API 연동 시 서버측 users.email UNIQUE 제약으로 대체된다.
  static final Set<String> _registeredEmails = {'demo@fortunefusion.app'};

  /// 02번 §1.1 "이메일 가입" — 로그인과 분리된 신규 가입 절차.
  /// 중복 이메일이면 실패를 반환(06단계 §4.1 `/v1/auth/email/signup` 대응).
  Future<ApiResult<UserModel>> emailSignup(
    String email,
    String password,
    String nickname,
  ) async {
    await mockDelay();
    if (email.isEmpty || password.isEmpty || nickname.isEmpty) {
      return ApiResult.fail('필수 정보를 모두 입력해 주세요.');
    }
    if (password.length < 8) {
      return ApiResult.fail('비밀번호는 8자 이상이어야 합니다.');
    }
    if (_registeredEmails.contains(email)) {
      return ApiResult.fail('이미 가입된 이메일입니다.', code: 'EMAIL_DUPLICATE');
    }
    _registeredEmails.add(email);
    final user = UserModel(
      id: 'u_${email.hashCode.abs()}',
      nickname: nickname,
      email: email,
    );
    await _persistSession(user);
    return ApiResult.ok(user);
  }

  Future<ApiResult<UserModel>> emailLogin(String email, String password) async {
    await mockDelay();
    if (email.isEmpty || password.isEmpty) {
      return ApiResult.fail('이메일과 비밀번호를 입력해 주세요.');
    }
    if (!_registeredEmails.contains(email)) {
      return ApiResult.fail('가입되지 않은 이메일입니다. 회원가입을 먼저 진행해 주세요.');
    }
    final user = UserModel(
      id: 'u_${email.hashCode.abs()}',
      nickname: email.split('@').first,
      email: email,
    );
    await _persistSession(user);
    return ApiResult.ok(user);
  }

  Future<ApiResult<UserModel>> socialLogin(String provider) async {
    await mockDelay();
    final user = UserModel(
      id: 'u_${provider}_${DateTime.now().millisecondsSinceEpoch}',
      nickname: '$provider사용자',
    );
    await _persistSession(user);
    return ApiResult.ok(user);
  }

  Future<ApiResult<UserModel>> updateProfile(UserModel updated) async {
    await mockDelay(ms: 300);
    await _persistSession(updated);
    return ApiResult.ok(updated);
  }

  Future<UserModel?> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kUserKey);
    if (raw == null) return null;
    try {
      return UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUserKey);
    await prefs.remove(_kTokenKey);
  }

  Future<void> _persistSession(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserKey, jsonEncode(user.toJson()));
    await prefs.setString(_kTokenKey, 'mock_token_${user.id}');
  }
}
