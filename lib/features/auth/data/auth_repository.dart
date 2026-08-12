import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/api/api_result.dart';
import '../../../core/auth/auth_token_store.dart';
import '../../../core/config/env_config.dart';
import '../domain/user_model.dart';

/// 06단계 §4.1 `/v1/auth`, `/v1/users` 대응 Repository
/// [로드맵④] 정공법 전환: Mock(SharedPreferences 로컬 저장)에서 admin_web의 공개
/// 인증 API(`/api/public/auth/*`)를 실제로 호출하는 방식으로 교체했다. 서버가
/// bcrypt 해싱 + JWT(Bearer, 30일 만료) 검증을 수행하며, AuthProvider 이상
/// 레이어는 이 클래스의 메서드 시그니처가 동일하게 유지되어 변경이 필요 없다
/// (07단계 아키텍처 원칙).
class AuthRepository {
  static String get _base => '${EnvConfig.adminApiBaseUrl}/api/public/auth';

  /// [인트로 전면 개편] 직전 emailSignup() 호출이 성공하면서 서버가 함께
  /// 내려준 회원가입 보상 정보(`{amount, balanceAfter}`). 가입 자체가 없거나
  /// 정책이 비활성(amount=0)이면 null. SignupRewardHandler가 이 값을 읽어
  /// 토스트 표시 + WalletProvider 갱신을 트리거한다.
  Map<String, dynamic>? lastSignupReward;

  /// [복주머니 정책표 §3 - 첫로그인10(1회)] 직전 emailLogin() 호출이 성공했을 때
  /// 서버가 함께 내려준 첫 로그인 보상 정보(`{amount, balanceAfter}`). 이미
  /// 로그인한 적이 있거나 정책이 비활성(amount=0)이면 null. login_screen.dart가
  /// signup_screen.dart의 SignupRewardHandler와 동일한 패턴으로 이 값을 읽어
  /// 토스트 표시 + WalletProvider 갱신을 트리거한다.
  Map<String, dynamic>? lastFirstLoginReward;

  /// 02번 §1.1 "이메일 가입" — 로그인과 분리된 신규 가입 절차.
  /// 서버 응답이 성공하면 JWT를 [AuthTokenStore]에 저장한다.
  Future<ApiResult<UserModel>> emailSignup(
    String email,
    String password,
    String nickname,
  ) async {
    if (email.isEmpty || password.isEmpty || nickname.isEmpty) {
      return ApiResult.fail('필수 정보를 모두 입력해 주세요.');
    }
    if (password.length < 8) {
      return ApiResult.fail('비밀번호는 8자 이상이어야 합니다.');
    }
    final uri = Uri.parse('$_base/signup');
    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'password': password,
              'nickname': nickname,
            }),
          )
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        return ApiResult.fail(
          decoded['error'] as String? ?? '회원가입에 실패했습니다.',
          code: decoded['code'] as String?,
        );
      }
      final data = decoded['data'] as Map<String, dynamic>;
      final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
      await _persistSession(user, data['token'] as String);
      // [인트로 전면 개편] 서버가 함께 내려준 회원가입 보상 정보를 보관해둔다
      // (없으면 null — 정책 비활성/amount=0 케이스).
      lastSignupReward = data['signupReward'] as Map<String, dynamic>?;
      return ApiResult.ok(user);
    } catch (e) {
      debugPrint('[AuthRepository] [emailSignup] 예외 -> $e');
      return ApiResult.fail('회원가입 중 오류가 발생했습니다: $e');
    }
  }

  Future<ApiResult<UserModel>> emailLogin(String email, String password) async {
    if (email.isEmpty || password.isEmpty) {
      return ApiResult.fail('이메일과 비밀번호를 입력해 주세요.');
    }
    final uri = Uri.parse('$_base/login');
    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        return ApiResult.fail(
          decoded['error'] as String? ?? '로그인에 실패했습니다.',
          code: decoded['code'] as String?,
        );
      }
      final data = decoded['data'] as Map<String, dynamic>;
      final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
      await _persistSession(user, data['token'] as String);
      // [복주머니 정책표 §3] 서버가 함께 내려준 첫 로그인 보상 정보를 보관해둔다
      // (없으면 null — 이미 로그인한 적 있음/정책 비활성 케이스).
      lastFirstLoginReward =
          data['firstLoginReward'] as Map<String, dynamic>?;
      return ApiResult.ok(user);
    } catch (e) {
      debugPrint('[AuthRepository] [emailLogin] 예외 -> $e');
      return ApiResult.fail('로그인 중 오류가 발생했습니다: $e');
    }
  }

  /// [설계결정 - 로드맵④] 실제 카카오/구글 OAuth SDK 연동은 이번 범위 밖이다.
  /// 서버는 501(NOT_IMPLEMENTED)을 정직하게 응답하며, 이 메서드는 그 실패를
  /// 그대로 전달한다(가짜 성공 처리 금지). presentation 레이어(login_screen.dart)는
  /// 이 실패를 "추후 지원 예정" 안내로 표시한다.
  Future<ApiResult<UserModel>> socialLogin(String provider) async {
    final uri = Uri.parse('$_base/social-login');
    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'provider': provider}),
          )
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return ApiResult.fail(
        decoded['error'] as String? ?? '$provider 로그인은 추후 지원 예정입니다.',
        code: decoded['code'] as String? ?? 'NOT_IMPLEMENTED',
      );
    } catch (e) {
      debugPrint('[AuthRepository] [socialLogin] 예외 -> $e');
      return ApiResult.fail(
        '$provider 소셜 로그인은 추후 지원 예정입니다.',
        code: 'NOT_IMPLEMENTED',
      );
    }
  }

  Future<ApiResult<UserModel>> updateProfile(UserModel updated) async {
    final token = await AuthTokenStore.getToken();
    if (token == null) {
      return ApiResult.fail('로그인이 필요합니다.');
    }
    final uri = Uri.parse('$_base/profile');
    try {
      final response = await http
          .patch(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'nickname': updated.nickname,
              'birth_date': updated.birthDate,
              'birth_time': updated.birthTime,
              'is_lunar': updated.isLunar,
              'gender': updated.gender,
            }),
          )
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        return ApiResult.fail(
          decoded['error'] as String? ?? '프로필 수정에 실패했습니다.',
          code: decoded['code'] as String?,
        );
      }
      final data = decoded['data'] as Map<String, dynamic>;
      final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
      return ApiResult.ok(user);
    } catch (e) {
      debugPrint('[AuthRepository] [updateProfile] 예외 -> $e');
      return ApiResult.fail('프로필 수정 중 오류가 발생했습니다: $e');
    }
  }

  /// 앱 부팅 시 저장된 JWT로 `/api/public/auth/me`를 호출해 세션을 복원한다.
  /// 토큰이 없거나 만료/무효(401)면 null을 반환(로그인 화면으로 이동).
  Future<UserModel?> restoreSession() async {
    final token = await AuthTokenStore.getToken();
    if (token == null) return null;
    final uri = Uri.parse('$_base/me');
    try {
      final response = await http
          .get(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        // 토큰 만료/무효 — 로컬 세션도 함께 정리한다.
        await AuthTokenStore.clear();
        return null;
      }
      final data = decoded['data'] as Map<String, dynamic>;
      return UserModel.fromJson(data['user'] as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[AuthRepository] [restoreSession] 예외 -> $e');
      return null;
    }
  }

  Future<void> logout() async {
    await AuthTokenStore.clear();
  }

  /// Phase2-3: 02번 §1.1 "회원탈퇴(소프트 삭제)" — 서버가 `users.status='withdrawn'`
  /// 전환 + `user_withdrawal_logs` 기록을 수행한다. [email] 파라미터는 더 이상
  /// 사용하지 않지만(토큰으로 사용자를 식별) 상위 레이어 호환을 위해 시그니처를 유지한다.
  Future<ApiResult<void>> withdrawAccount(String? email) async {
    final token = await AuthTokenStore.getToken();
    if (token == null) {
      return ApiResult.fail('로그인이 필요합니다.');
    }
    final uri = Uri.parse('$_base/withdraw');
    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({}),
          )
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        return ApiResult.fail(decoded['error'] as String? ?? '탈퇴 처리에 실패했습니다.');
      }
      await AuthTokenStore.clear();
      return ApiResult.ok(null);
    } catch (e) {
      debugPrint('[AuthRepository] [withdrawAccount] 예외 -> $e');
      return ApiResult.fail('탈퇴 처리 중 오류가 발생했습니다: $e');
    }
  }

  Future<void> _persistSession(UserModel user, String token) async {
    await AuthTokenStore.save(token: token, userId: int.parse(user.id));
  }
}
