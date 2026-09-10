import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
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
  // [웹 소셜로그인 활성화] 구글 토큰의 종류. Android(APK)는 idToken을,
  // Web은 accessToken을 담아 보낸다(아래 signInWithGoogle() 주석 참고).
  // 서버(admin_web)의 /social-login이 이 값을 보고 검증 엔드포인트를
  // 분기한다. 카카오는 항상 'id_token'이 아니지만 애초에 서버가 이 필드를
  // 카카오에는 사용하지 않으므로 기본값을 넣어도 무해하다.
  final String tokenType; // 'id_token' | 'access_token'
  const SocialAuthResult(
    this.provider,
    this.accessToken, {
    this.tokenType = 'id_token',
  });
}

class SocialAuthService {
  SocialAuthService._();

  // [웹 소셜로그인 활성화] google_sign_in_web(GIS SDK 기반)은 Android와
  // 파라미터 지원이 다르다:
  //   - serverClientId: 웹에서는 지원되지 않는다. google_sign_in_web의
  //     initWithParams()가 `assert(params.serverClientId == null, ...)`로
  //     명시적으로 거부하므로, 웹에서 이 값을 넘기면 초기화 자체가
  //     실패한다(디버그 모드에서 assert 크래시, 릴리스에서도 사실상 로그인
  //     불가). 대신 웹은 clientId를 사용한다(OAuth Client ID는 Android와
  //     동일한 프로젝트의 "웹 애플리케이션" 타입 클라이언트 ID를 쓴다 —
  //     현재 SocialAuthConfig.googleWebClientId가 바로 그 값이라 그대로
  //     재사용 가능하다).
  //   - Android는 반대로 serverClientId를 써야 서버가 검증 가능한 ID
  //     토큰을 발급받을 수 있다(구글 공식 문서의 Android 표준 사용법).
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: kIsWeb ? null : SocialAuthConfig.googleWebClientId,
    clientId: kIsWeb ? SocialAuthConfig.googleWebClientId : null,
  );

  /// 구글 로그인 실행. 성공 시 (구글이 발급한 토큰, 토큰 종류)를 담아
  /// 반환, 사용자가 취소하면 null.
  ///
  /// [플랫폼별 분기 — 웹 소셜로그인 활성화]
  /// Android/iOS: `signIn()` → `idToken`을 그대로 서버로 보낸다(기존 동작
  /// 100% 유지 — APK는 이미 정상 동작 확인됨).
  /// Web: google_sign_in_web(새 GIS SDK 기반 구현)은 `signIn()`이
  /// deprecated이고, 정책상 idToken을 안정적으로 반환하지 않는다(사용자가
  /// One-Tap/자동 로그인 흐름을 타지 않으면 People API로 만든 synthetic
  /// 응답만 오고 idToken 필드가 비어있다 — 패키지 소스
  /// google_sign_in_web/lib/src/gis_client.dart의 `_computeUserDataForLastToken()`
  /// 참고). 그래서 웹에서는 `signIn()` 이후 `account.authentication`
  /// 대신 `GoogleSignInPlatform.instance.getTokens()`로 얻는 oauth2
  /// accessToken을 사용한다 — 이 accessToken은 GIS SDK가 안정적으로
  /// 채워주는 값이다.
  static Future<SocialAuthResult?> signInWithGoogle() async {
    final account = await _googleSignIn.signIn();
    if (account == null) return null; // 사용자가 취소

    if (kIsWeb) {
      final tokens = await GoogleSignInPlatform.instance.getTokens(
        email: account.email,
      );
      final accessToken = tokens.accessToken;
      if (accessToken == null) {
        throw Exception('구글 로그인 토큰을 가져오지 못했습니다. 다시 시도해 주세요.');
      }
      return SocialAuthResult(
        'google',
        accessToken,
        tokenType: 'access_token',
      );
    }

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
  ///
  /// [웹 로그인 실패 버그 수정 — sintong.kr/app 실사용자 재현]
  /// kakao_flutter_sdk_common의 웹 플러그인 구현(`isMobileDevice()`)은
  /// "카카오톡 앱이 실제로 설치되어 있는지"를 확인하는 게 아니라, 단순히
  /// User-Agent가 모바일 기기인지만 검사한다(kakao_flutter_sdk_plugin.dart
  /// `isKakaoTalkInstalled` case 참고). 그 결과 실제 모바일 브라우저에서는
  /// 카카오톡 미설치 여부와 무관하게 `isKakaoTalkInstalled()`가 항상
  /// `true`를 반환했고, 우리 코드가 이를 그대로 믿고
  /// `loginWithKakaoTalk()`(Android Intent로 카카오톡 앱을 직접 열어
  /// 앱→웹 콜백으로 돌아오는 네이티브 전용 흐름)를 호출했다. 이 흐름은
  /// 순수 웹 브라우저 탭 안에서는 앱이 콜백을 되돌려줄 경로가 없어
  /// 정상적으로 완료될 수 없고, 결국 "카카오 로그인 중 오류가
  /// 발생했습니다" 에러로 이어졌다(2026-09-10 sintong.kr/app 실사용자
  /// 재현 확인).
  ///
  /// [해결] 웹(kIsWeb)에서는 `isKakaoTalkInstalled()` 분기 자체를 건너뛰고
  /// 항상 `loginWithKakaoAccount()`(카카오 JS-SDK 팝업 방식,
  /// `CommonConstants.webAccountLoginRedirectUri = 'JS-SDK'`로 고정된
  /// redirectUri 사용)만 호출한다. 네이티브(Android/iOS) 앱은 기존 동작을
  /// 그대로 유지한다(이미 정상 동작 확인됨 — 건드리지 않음).
  static Future<SocialAuthResult?> signInWithKakao() async {
    if (kIsWeb) {
      try {
        final token = await UserApi.instance.loginWithKakaoAccount();
        return SocialAuthResult('kakao', token.accessToken);
      } on KakaoClientException catch (e) {
        // [임시 디버그 - 웹 카카오 로그인 원인 조사] 실제 예외 내용이
        // login_screen.dart의 범용 catch에 삼켜져 콘솔에 전혀 남지 않아,
        // 원인 규명을 위해 브라우저 콘솔에 직접 출력한다(원인 확정 후 제거 예정).
        debugPrint(
          '[SocialAuthService][WEB-DEBUG] KakaoClientException reason=${e.reason} msg=${e.msg}',
        );
        if (e.reason == ClientErrorCause.cancelled) return null; // 사용자가 취소
        rethrow;
      } catch (e, st) {
        // [임시 디버그] KakaoClientException이 아닌 그 외 모든 예외
        // (PlatformException, DioException, TimeoutException 등)의 실제
        // 타입과 메시지를 확인하기 위한 임시 로깅.
        debugPrint('[SocialAuthService][WEB-DEBUG] type=${e.runtimeType} error=$e');
        debugPrint('[SocialAuthService][WEB-DEBUG] stack=$st');
        rethrow;
      }
    }

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
