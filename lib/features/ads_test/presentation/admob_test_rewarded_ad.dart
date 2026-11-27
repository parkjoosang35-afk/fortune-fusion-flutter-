import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../domain/admob_ad_ids.dart';

/// [애드몹 테스트 연동] 구글 공식 테스트 Ad Unit ID로 보상형(리워드) 광고를
/// 로드/표시하는 헬퍼.
///
/// 기존 "복주머니 광고 보고 충전" 실서비스 플로우([FortuneAdWatchDialog],
/// admin_web `/api/ads` 연동, 서버가 최종 지급을 결정)는 전혀 건드리지 않고,
/// 이 클래스는 순수하게 "애드몹 SDK가 정상적으로 리워드 광고를 로드하고
/// 재생하는지"만 확인하는 별도 QA 진입점이다. 여기서 표시되는 보상은
/// 실제 복주머니 잔액에 반영되지 않는다(테스트 전용, [SettingsScreen]의
/// "애드몹 테스트" 섹션에서만 호출됨).
class AdmobTestRewardedAd {
  AdmobTestRewardedAd._();

  static bool _isLoading = false;

  /// 테스트 리워드 광고를 로드 후 즉시 표시한다. 결과는 [onResult]로
  /// 콜백된다(rewarded=true면 끝까지 시청해 보상 콜백까지 도달, false면
  /// 로드 실패/중도 종료).
  static Future<void> loadAndShow(
    BuildContext context, {
    required void Function(bool rewarded, String message) onResult,
  }) async {
    if (!AdmobAdIds.isSupportedPlatform) {
      onResult(false, '이 플랫폼(Web 등)에서는 애드몹 테스트 광고를 지원하지 않아요.');
      return;
    }
    if (_isLoading) return;
    _isLoading = true;

    await RewardedAd.load(
      adUnitId: AdmobAdIds.rewardedUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _isLoading = false;
          bool rewarded = false;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              onResult(
                rewarded,
                rewarded
                    ? '테스트 리워드 광고 시청 완료! (테스트용 — 실제 지급 없음)'
                    : '광고를 끝까지 보지 않아 보상이 지급되지 않았어요. (테스트)',
              );
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              if (kDebugMode) {
                debugPrint('[AdmobTestRewardedAd] 표시 실패 -> $error');
              }
              onResult(false, '테스트 광고 표시에 실패했어요: $error');
            },
          );
          ad.show(
            onUserEarnedReward: (ad, reward) {
              rewarded = true;
            },
          );
        },
        onAdFailedToLoad: (error) {
          _isLoading = false;
          if (kDebugMode) {
            debugPrint('[AdmobTestRewardedAd] 로드 실패 -> $error');
          }
          onResult(false, '테스트 광고 로드에 실패했어요: $error');
        },
      ),
    );
  }
}
