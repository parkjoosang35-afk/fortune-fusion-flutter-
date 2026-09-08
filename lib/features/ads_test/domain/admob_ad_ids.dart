import 'package:flutter/foundation.dart';

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
}
