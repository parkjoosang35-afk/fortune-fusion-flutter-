import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// [애드몹 App ID/Ad Unit ID 모음 — 테스트/실제 자동 전환]
///
/// [배경 — 왜 자동 전환이 필요한가] 사장님이 실제 애드몹 계정에서 발급받은
/// App ID/Ad Unit ID를 전달해 주셨다. 하지만 개발자가 개발/QA 중에 실제 Ad
/// Unit ID로 광고를 반복 호출(로드/시청)하면 "무효 트래픽(invalid traffic)"
/// 으로 감지되어 최악의 경우 AdMob 계정 자체가 정지될 수 있다(사장님이 직접
/// 강조하신 주의사항). 그래서 이 클래스는 명시적으로 "지금 진짜 배포 빌드를
/// 만드는 중"이라고 알려주지 않는 한 항상 구글 공식 테스트 ID
/// (https://developers.google.com/admob/android/test-ads)를 반환한다.
///
/// [전환 방법] Play 스토어 제출용 최종 릴리즈 APK/AAB를 빌드할 때만 아래
/// 플래그를 명시적으로 켠다:
/// ```
/// flutter build appbundle --release --dart-define=ADMOB_USE_REAL_IDS=true
/// ```
/// 이 플래그를 주지 않는 모든 빌드(웹 프리뷰용 `flutter build web --release`
/// 포함, `flutter run` 디버그 포함)는 기본값(false)이 적용되어 항상 테스트
/// ID로만 동작한다 — 즉 이 샌드박스에서의 일상적인 개발/미리보기 작업은
/// 이 값을 절대 건드리지 않아도 자동으로 안전하다.
///
/// [App ID(Manifest)는 왜 항상 실제 값을 써도 되는가] Google 공식 문서 기준,
/// 실제로 진짜 광고가 노출되는지 여부는 "Ad Unit ID"가 결정하며, App ID
/// 자체(AndroidManifest.xml의 APPLICATION_ID)는 실제 값을 상시 등록해 두어도
/// 문제가 없다(테스트 Ad Unit ID는 어떤 App ID 아래에서도 정상 동작한다).
/// 그래서 AndroidManifest.xml은 실제 App ID로 이미 교체했고, 이 파일에서는
/// Ad Unit ID(배너/전면/보상형) 3개만 조건부로 전환한다.
///
/// [Web 미지원] google_mobile_ads는 Android/iOS 전용이라 Web 플랫폼에서는
/// SDK 자체가 동작하지 않는다. 모든 사용처에서 `kIsWeb` 체크 후 빈 위젯/no-op
/// 처리로 안전하게 우회한다.
class AdmobAdIds {
  AdmobAdIds._();

  // ── 구글 공식 테스트 ID (기본값, 개발/QA/웹프리뷰 전 구간에서 사용) ──
  // 참고: 구글 공식 테스트 App ID는 ca-app-pub-3940256099942544~3347511713
  // 이지만, App ID는 항상 실제 값(_realAppId)만 사용해도 안전하므로(위 클래스
  // 주석 참고) 별도 상수로 두지 않는다.
  static const String _testBannerId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _testInterstitialId =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _testRewardedId =
      'ca-app-pub-3940256099942544/5224354917';

  // ── 사장님 실제 애드몹 계정 ID (신통방통, 2026년 발급) ──
  // ⚠️ 개발자 주의: 이 값들로 직접 광고를 반복 로드/시청하지 말 것(무효
  // 트래픽 → 계정 정지 위험). useRealAds가 true인 최종 릴리즈 빌드에서만
  // 실제로 사용되며, 그 전까지는 코드에만 존재하고 실행되지 않는다.
  static const String _realAppId = 'ca-app-pub-2370852566371234~8570397726';
  static const String _realBannerId =
      'ca-app-pub-2370852566371234/8788433300';
  static const String _realInterstitialId =
      'ca-app-pub-2370852566371234/9001642563';
  static const String _realRewardedId =
      'ca-app-pub-2370852566371234/7225562466';

  /// 실제 광고 ID 사용 여부. 기본 false(테스트 ID). Play 스토어 제출용
  /// 최종 빌드 시 `--dart-define=ADMOB_USE_REAL_IDS=true`를 넘겨야만 true가
  /// 된다(위 클래스 주석 참고).
  static const bool useRealAds = bool.fromEnvironment(
    'ADMOB_USE_REAL_IDS',
    defaultValue: false,
  );

  /// 참고용 상수(AndroidManifest.xml의 APPLICATION_ID와 동일한 실제 값).
  /// Manifest는 항상 실제 App ID를 쓰므로 이 값 자체는 조건 분기가 없다.
  static const String androidAppId = _realAppId;

  /// 현재 플랫폼에서 애드몹 SDK를 사용할 수 있는지 여부.
  /// Web은 지원하지 않으므로 항상 false, Android/iOS만 true.
  static bool get isSupportedPlatform =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android);

  static String get bannerUnitId => useRealAds ? _realBannerId : _testBannerId;
  static String get interstitialUnitId =>
      useRealAds ? _realInterstitialId : _testInterstitialId;
  static String get rewardedUnitId =>
      useRealAds ? _realRewardedId : _testRewardedId;

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
