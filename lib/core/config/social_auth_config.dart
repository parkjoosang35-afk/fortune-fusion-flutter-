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

  /// [웹 소셜로그인 활성화] 카카오 JavaScript 키(카카오 디벨로퍼스 > 앱 >
  /// 플랫폼 키 > JavaScript 키). 네이티브 앱 키와는 별개의 값이며,
  /// kakao_flutter_sdk_common의 `KakaoSdk.appKey`는 웹 플랫폼에서 이 값을
  /// 사용한다(kIsWeb ? javaScriptAppKey : nativeAppKey).
  ///
  /// ⚠️ TODO(운영자 조치 필요): 아래 값은 아직 비어 있다. 카카오 로그인이
  /// 웹(sintong.kr/app)에서 실제로 동작하려면:
  ///   1) 카카오 디벨로퍼스(https://developers.kakao.com) > 내 애플리케이션 >
  ///      앱 설정 > 플랫폼에서 "Web" 플랫폼을 추가하고 사이트 도메인을
  ///      `https://sintong.kr`로 등록한다.
  ///   2) 앱 설정 > 요약 정보에서 "JavaScript 키"를 복사해 아래 상수에
  ///      채워 넣는다(빈 문자열로 두면 웹에서 카카오 로그인 시도 시 카카오
  ///      서버가 "잘못된 클라이언트(client_id 없음)" 오류를 반환한다).
  ///   3) 카카오 로그인 > Redirect URI에 `https://sintong.kr/app/`(또는
  ///      실제 배포 경로)를 등록해야 할 수 있다(카카오계정 로그인 팝업
  ///      완료 후 리다이렉트에 필요).
  static const String kakaoJavaScriptAppKey = '';
}
