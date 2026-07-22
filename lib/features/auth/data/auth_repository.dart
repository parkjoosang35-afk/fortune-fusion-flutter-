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

  Future<ApiResult<UserModel>> emailLogin(String email, String password) async {
    await mockDelay();
    if (email.isEmpty || password.isEmpty) {
      return ApiResult.fail('이메일과 비밀번호를 입력해 주세요.');
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
