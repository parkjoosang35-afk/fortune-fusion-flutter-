import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/ads_test/domain/admob_ad_ids.dart';

/// [애드몹 테스트/실제 ID 자동 전환 검증] ADMOB_USE_REAL_IDS dart-define을
/// 주지 않은 기본 상태에서는 반드시 구글 공식 테스트 ID만 사용되어야 하고,
/// 실제 ID(사장님이 전달한 신통방통 계정 값)는 코드에 정확히 반영되어 있되
/// 스위치를 켜지 않는 한 현재 사용되지 않아야 한다는 안전장치를 검증한다.
void main() {
  test('기본값(dart-define 없음)에서는 항상 테스트 Ad Unit ID를 사용한다', () {
    expect(AdmobAdIds.useRealAds, isFalse);
    expect(
      AdmobAdIds.rewardedUnitId,
      'ca-app-pub-3940256099942544/5224354917',
    );
    expect(AdmobAdIds.bannerUnitId, 'ca-app-pub-3940256099942544/6300978111');
    expect(
      AdmobAdIds.interstitialUnitId,
      'ca-app-pub-3940256099942544/1033173712',
    );
  });

  test('App ID는 항상 사장님의 실제 신통방통 App ID를 가리킨다', () {
    expect(AdmobAdIds.androidAppId, 'ca-app-pub-2370852566371234~8570397726');
  });
}
