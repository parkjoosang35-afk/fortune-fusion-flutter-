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
  ///
  /// [6-7-4-B-4] admin_web `/api/public/auth/signup`이 이용약관/개인정보처리방침
  /// 동의를 필수 요건으로 검증하도록 변경됨에 따라(미동의 시 400/TERMS_NOT_AGREED),
  /// 클라이언트도 이 두 값을 함께 전송한다. 상위 레이어(AuthProvider/SignupScreen)가
  /// 체크박스 상태를 그대로 전달하므로 여기서는 값 검증만 하고 통과시킨다.
  Future<ApiResult<UserModel>> emailSignup(
    String email,
    String password,
    String nickname, {
    required bool termsAgreed,
    required bool privacyAgreed,
  }) async {
    if (email.isEmpty || password.isEmpty || nickname.isEmpty) {
      return ApiResult.fail('필수 정보를 모두 입력해 주세요.');
    }
    if (password.length < 8) {
      return ApiResult.fail('비밀번호는 8자 이상이어야 합니다.');
    }
    if (!termsAgreed || !privacyAgreed) {
      return ApiResult.fail(
        '이용약관 및 개인정보처리방침에 동의해야 가입할 수 있습니다.',
        code: 'TERMS_NOT_AGREED',
      );
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
              'termsAgreed': termsAgreed,
              'privacyAgreed': privacyAgreed,
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
      lastFirstLoginReward = data['firstLoginReward'] as Map<String, dynamic>?;
      return ApiResult.ok(user);
    } catch (e) {
      debugPrint('[AuthRepository] [emailLogin] 예외 -> $e');
      return ApiResult.fail('로그인 중 오류가 발생했습니다: $e');
    }
  }

  /// [로드맵⑤] 실제 카카오/구글 OAuth SDK 연동 완료.
  /// [provider]는 'kakao' 또는 'google', [accessToken]은 각 SDK가 발급한
  /// 액세스 토큰(카카오)/ID 토큰(구글)이다. 서버(admin_web)가 이 토큰을 다시
  /// 각 사(카카오/구글) API로 검증하므로, 클라이언트가 위조한 값으로는
  /// 로그인이 성립하지 않는다(가짜 성공 처리 금지 원칙 유지).
  Future<ApiResult<UserModel>> socialLogin(
    String provider,
    String accessToken, {
    String tokenType = 'id_token',
  }) async {
    final uri = Uri.parse('$_base/social-login');
    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'provider': provider,
              'accessToken': accessToken,
              // [웹 소셜로그인 활성화] 구글 웹은 idToken 대신 accessToken을
              // 보내므로 서버가 검증 엔드포인트를 구분할 수 있게 표시한다.
              'tokenType': tokenType,
            }),
          )
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        return ApiResult.fail(
          decoded['error'] as String? ?? '$provider 로그인에 실패했습니다.',
          code: decoded['code'] as String?,
        );
      }
      final data = decoded['data'] as Map<String, dynamic>;
      final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
      await _persistSession(user, data['token'] as String);
      lastFirstLoginReward = data['firstLoginReward'] as Map<String, dynamic>?;
      return ApiResult.ok(user);
    } catch (e) {
      debugPrint('[AuthRepository] [socialLogin] 예외 -> $e');
      return ApiResult.fail('$provider 로그인 중 오류가 발생했습니다: $e');
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
              // [신통방통 2단계] 음력이 아니면 항상 false로 전송(양력에서는
              // 윤달 개념을 사용하지 않는다는 원칙을 서버 전송 시점에도 지킨다).
              'is_leap_month': updated.isLunar ? updated.isLeapMonth : false,
              'birth_time_unknown': updated.birthTimeUnknown,
              'birth_place': updated.birthPlace,
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

  /// [Phase C - 웰컴 리워드 팝업 1회성 노출] WelcomeRewardModal의 CTA("복주머니
  /// 받기") 탭 시 호출. 서버 `users.welcome_gift_claimed`를 true로 갱신해
  /// 이후 세션 복원/재로그인 시 팝업이 다시 뜨지 않도록 한다. 실패해도(네트워크
  /// 오류 등) 팝업 자체는 이미 닫힌 뒤이므로 조용히 무시한다(사용자 경험을
  /// 막지 않음 — 다음 세션에서 재시도될 수 있음을 감수).
  Future<void> claimWelcomeGift() async {
    final token = await AuthTokenStore.getToken();
    if (token == null) return;
    final uri = Uri.parse('$_base/welcome-gift/claim');
    try {
      await http
          .post(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('[AuthRepository] [claimWelcomeGift] 예외 -> $e');
    }
  }
}
