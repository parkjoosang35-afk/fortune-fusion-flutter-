import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// [애드몹 테스트 연동] Google 공식 "테스트용" App ID / Ad Unit ID 모음.
///
/// 아래 값들은 실제 서비스 계정과 무관하게 구글이 공개 배포한 고정 테스트
/// ID다(https://developers.google.com/admob/android/test-ads,
/// https://developers.google.com/admob/ios/test-ads). 테스트 ID로는 항상
/// "Test Ad"라는 라벨이 붙은 샘플 광고만 노출되며, 무의미한 노출/클릭이
/// 실제 수익이나 계정 정지로 이어지지 않는다.
///
/// [운영 전환 시] 사장님의 실제 애드몹 계정에서 발급한 App ID/Ad Unit ID로
/// 아래 값만 교체하면 된다(다른 코드는 수정할 필요 없음). AndroidManifest.xml의
/// `com.google.android.gms.ads.APPLICATION_ID` meta-data도 함께 교체해야
/// 한다(그 값이 실제 초기화에 사용되는 App ID다).
///
/// [Web 미지원] google_mobile_ads는 Android/iOS 전용이라 Web 플랫폼에서는
/// SDK 자체가 동작하지 않는다. 모든 사용처에서 `kIsWeb` 체크 후 빈 위젯/no-op
/// 처리로 안전하게 우회한다.
class AdmobAdIds {
  AdmobAdIds._();

  /// AndroidManifest.xml의 APPLICATION_ID와 동일한 값(참고용 상수).
  static const String androidAppId = 'ca-app-pub-3940256099942544~3347511713';

  /// 배너 광고 테스트 Ad Unit ID (Android).
  static const String androidBannerTestId =
      'ca-app-pub-3940256099942544/6300978111';

  /// 전면(인터스티셜) 광고 테스트 Ad Unit ID (Android).
  static const String androidInterstitialTestId =
      'ca-app-pub-3940256099942544/1033173712';

  /// 보상형(리워드) 광고 테스트 Ad Unit ID (Android).
  static const String androidRewardedTestId =
      'ca-app-pub-3940256099942544/5224354917';

  /// 현재 플랫폼에서 애드몹 SDK를 사용할 수 있는지 여부.
  /// Web은 지원하지 않으므로 항상 false, Android/iOS만 true.
  static bool get isSupportedPlatform =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android);

  static String get bannerUnitId => androidBannerTestId;
  static String get interstitialUnitId => androidInterstitialTestId;
  static String get rewardedUnitId => androidRewardedTestId;

  /// [애드몹 실서비스 전환 준비 - 4번] 개발/QA용 "테스트 기기" 광고 ID 목록.
  ///
  /// [배경] 실제 AdMob 계정으로 전환한 뒤 개발자 본인 기기로 실제 광고를
  /// 반복 클릭/시청하면 "무효 트래픽(invalid traffic)"으로 감지되어 최악의
  /// 경우 AdMob 계정 자체가 정지될 수 있다. 이를 방지하려면 QA에 사용하는
  /// 기기의 광고 ID(Advertising ID)를 여기 등록해 두면, 그 기기에서는 실제
  /// 광고 대신 "Test Ad" 라벨이 붙은 안전한 테스트 광고만 노출된다.
  ///
  /// [등록 방법] 앱을 실제 AdMob App ID로 실행하면, 콘솔 로그에
  /// "Use RequestConfiguration.Builder().setTestDeviceIds(Arrays.asList("XXXX"))"
  /// 형태로 기기 ID가 출력된다. 그 ID를 아래 리스트에 추가하면 된다.
  ///
  /// [현재 상태] 아직 실제 AdMob 계정으로 전환하지 않아 비워둔 상태다.
  /// 테스트 ID(androidRewardedTestId 등)로 광고를 띄우는 동안에는 이 설정이
  /// 필요 없다(테스트 ID는 원래부터 항상 테스트 광고만 노출한다). 실제
  /// Ad Unit ID로 교체하기 직전에 QA 기기 ID를 채워 넣을 것.
  static const List<String> testDeviceIds = <String>[];

  /// 앱 시작 시 1회 호출해 [testDeviceIds]를 SDK에 반영한다. 테스트 기기가
  /// 비어 있으면(운영 전환 전) 아무 효과가 없으므로 항상 호출해도 안전하다.
  static void applyRequestConfiguration() {
    if (!isSupportedPlatform) return;
    MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(testDeviceIds: testDeviceIds),
    );
  }
}
