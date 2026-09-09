import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import '../../../core/config/social_auth_config.dart';

/// [로드맵④] 카카오/구글 SDK 호출을 캡슐화한 서비스.
///
/// login_screen.dart는 이 클래스가 반환하는 (provider, accessToken) 쌍만
/// AuthProvider.loginWithSocial()로 전달하면 된다 — 실제 토큰을 서버에
/// 보내 검증하는 책임은 AuthRepository/서버(admin_web)에 있다(이 클래스는
/// "로그인 위조"를 할 수 없고, 각 사 SDK가 정상 발급한 토큰만 받아온다).
///
/// 반환값이 null이면 "사용자가 취소함"을 의미하며(에러 아님), 호출부는
/// 조용히 아무 것도 하지 않아야 한다. 그 외 예외는 그대로 던져 호출부가
/// 사용자에게 실패를 안내하게 한다.
class SocialAuthResult {
  final String provider; // 'google' | 'kakao'
  final String accessToken;
  const SocialAuthResult(this.provider, this.accessToken);
}

class SocialAuthService {
  SocialAuthService._();

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    // [Firebase 콘솔에서 발급된 Web Client ID] Android에서도 이 값을
    // serverClientId로 지정해야 서버(admin_web)가 검증 가능한 ID 토큰이
    // 발급된다(clientId 없이 serverClientId만 지정하는 것이 Android 표준
    // 사용법 — google_sign_in 패키지 문서 참고).
    serverClientId: SocialAuthConfig.googleWebClientId,
  );

  /// 구글 로그인 실행. 성공 시 ID 토큰을 반환, 사용자가 취소하면 null.
  static Future<SocialAuthResult?> signInWithGoogle() async {
    final account = await _googleSignIn.signIn();
    if (account == null) return null; // 사용자가 취소
    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null) {
      throw Exception('구글 로그인 토큰을 가져오지 못했습니다. 다시 시도해 주세요.');
    }
    return SocialAuthResult('google', idToken);
  }

  /// 카카오 로그인 실행. 카카오톡 앱이 설치되어 있으면 카카오톡으로,
  /// 없으면 카카오계정(웹) 방식으로 자동 폴백한다. 성공 시 액세스 토큰을
  /// 반환, 사용자가 취소하면 null.
  static Future<SocialAuthResult?> signInWithKakao() async {
    try {
      final installed = await isKakaoTalkInstalled();
      final OAuthToken token = installed
          ? await UserApi.instance.loginWithKakaoTalk()
          : await UserApi.instance.loginWithKakaoAccount();
      return SocialAuthResult('kakao', token.accessToken);
    } on KakaoClientException catch (e) {
      if (e.reason == ClientErrorCause.cancelled) return null; // 사용자가 취소
      rethrow;
    } on PlatformException catch (e) {
      // [폴백] 카카오톡 앱으로 로그인 도중 사용자가 카카오톡 내에서
      // 취소한 경우, 카카오계정(웹) 방식으로 한 번 더 시도한다(공식
      // SDK 문서 권장 패턴).
      if (e.code == 'CANCELED') return null;
      debugPrint('[SocialAuthService] 카카오톡 로그인 실패, 카카오계정으로 재시도 -> $e');
      try {
        final token = await UserApi.instance.loginWithKakaoAccount();
        return SocialAuthResult('kakao', token.accessToken);
      } on KakaoClientException catch (e2) {
        if (e2.reason == ClientErrorCause.cancelled) return null;
        rethrow;
      }
    }
  }
}
