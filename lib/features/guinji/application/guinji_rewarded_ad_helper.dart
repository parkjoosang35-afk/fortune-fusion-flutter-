import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../ads_test/domain/admob_ad_ids.dart';

/// [귀인지도 스페셜 해설 — 광고 해금 버그수정 2026-09]
///
/// [배경] 사용자 리포트("광고연결 안됨")를 조사한 결과, 관계 상세 화면의
/// "광고 보고 지금 열기" 버튼이 실제로는 AdMob 리워드 광고를 전혀 로드/
/// 표시하지 않고, 곧바로 `POST /guinji/unlocks`(method: 'ad')를 호출하는
/// 것으로 확인됐다 — 광고 자체가 뜨지 않으니 사용자 입장에서는 "광고가
/// 연결되지 않는다"고 느낄 수밖에 없었다.
///
/// [이 클래스의 역할] `FortuneAdWatchDialog`(복주머니 광고 적립)의 검증된
/// AdMob 연동 패턴(로드 → 전체화면 표시 → onUserEarnedReward 콜백으로
/// "끝까지 봤음" 판정)을 귀인지도 해금 흐름 전용으로 재사용 가능하게 뽑아낸
/// 것이다. 귀인지도 unlock API는 시청 세션 발급/서버측 진행률 검증이 없는
/// 단순 구조(광고를 끝까지 봤다는 사실만 클라이언트를 신뢰)이므로, 이
/// 헬퍼는 세션 없이 "로드→표시→보상획득여부" 콜백만 제공한다.
///
/// [Web 미지원] google_mobile_ads는 Android/iOS 전용이라 Web에서는 항상
/// `onResult(false, ...)`로 즉시 실패 처리한다(호출부가 이 경우 안내
/// 문구를 보여주거나, 포인트 결제 방식으로 유도해야 한다).
class GuinjiRewardedAdHelper {
  GuinjiRewardedAdHelper._();

  static bool _isLoading = false;

  /// 리워드 광고를 로드 후 즉시 표시한다.
  /// - [onResult]의 `rewarded=true`: 끝까지 시청 완료(호출부가 이때만
  ///   `GuinjiProvider.unlock(method: 'ad')`를 호출해야 한다).
  /// - `rewarded=false`: 로드 실패/표시 실패/중도 종료(보상 없음, 서버
  ///   unlock API를 호출하지 않는다).
  static Future<void> loadAndShow({
    required void Function(bool rewarded, String? errorMessage) onResult,
  }) async {
    if (!AdmobAdIds.isSupportedPlatform) {
      onResult(false, '이 플랫폼(Web 등)에서는 광고 시청 해금을 지원하지 않아요. 복주머니로 열어주세요.');
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
              if (rewarded) {
                onResult(true, null);
              } else {
                onResult(false, '광고를 끝까지 보지 않아 해금되지 않았어요.');
              }
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              if (kDebugMode) {
                debugPrint('[GuinjiRewardedAdHelper] 표시 실패 -> $error');
              }
              onResult(false, '광고 표시에 실패했어요. 잠시 후 다시 시도해주세요.');
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
            debugPrint('[GuinjiRewardedAdHelper] 로드 실패 -> $error');
          }
          onResult(false, '지금은 광고를 불러올 수 없어요. 잠시 후 다시 시도해주세요.');
        },
      ),
    );
  }
}
