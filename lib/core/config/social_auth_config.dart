/// [카카오/구글 간편로그인] Firebase/카카오 디벨로퍼스 콘솔에서 발급받은
/// 앱 식별 키 모음.
///
/// [배경] admob_ad_ids.dart와 동일한 패턴으로, 콘솔에서 발급된 고정 값들을
/// 한곳에 모아 관리한다. 이 값들은 "비밀키"가 아니라 클라이언트(앱)에
/// 공개적으로 포함되는 식별자들이다(실제 인증/검증은 서버(admin_web)가
/// 액세스 토큰/ID 토큰을 다시 각 사(구글/카카오) API로 검증하는 방식이라,
/// 이 키들만으로 로그인이 위조되지 않는다).
///
/// [운영 전환 시] 배포용 keystore(release-key.jks)가 바뀌면 SHA-1도 바뀌므로,
/// 구글 Firebase 콘솔 + 카카오 디벨로퍼스 콘솔 양쪽에 새 SHA-1/키 해시를
/// 다시 등록하고 google-services.json도 재다운로드해야 한다.
class SocialAuthConfig {
  SocialAuthConfig._();

  /// 구글 로그인 Web Client ID (Firebase 콘솔 > google-services.json의
  /// oauth_client 중 client_type: 3 항목). google_sign_in 패키지가
  /// 서버 인증용 ID 토큰을 발급받으려면 serverClientId로 이 값이 필요하다.
  static const String googleWebClientId =
      '29545196276-5udpd2jkpdvu2jetj0tjc5bb81e8alg6.apps.googleusercontent.com';

  /// 카카오 네이티브 앱 키(카카오 디벨로퍼스 > 앱 > 플랫폼 키 > 네이티브
  /// 앱 키). kakao_flutter_sdk_user 초기화 및 AndroidManifest.xml의
  /// 리다이렉트 스킴(kakao{네이티브앱키}://oauth)에 사용된다.
  static const String kakaoNativeAppKey = '6372a58baa9ce5d09bcc7edf0d38fc75';
}
