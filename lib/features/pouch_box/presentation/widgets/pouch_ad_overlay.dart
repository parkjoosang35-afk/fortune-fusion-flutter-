import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../../../theme/lucky_box_tokens.dart';
import '../../../ads_test/domain/admob_ad_ids.dart';

/// [행운상자 - 복주머니 탭 신규 기능] dev-spec.md §3-2 Ad Overlay.
/// 5초 카운트다운(스킵 불가) — 뒷 그리드를 어둡게 깔고 그 위에 이 오버레이를
/// 표시한다. 실제 구현은 `google_mobile_ads` RewardedAd(최소 5초)를
/// 사용하고, Web처럼 AdMob SDK가 동작하지 않는 플랫폼에서는 5초 카운트다운
/// 시뮬레이션으로 대체한다(§Web 미지원 원칙, fortune_ad_watch_dialog.dart와
/// 동일한 폴백 패턴).
///
/// [절대 원칙] 스킵 불가 — 닫기/뒤로가기 버튼을 아예 두지 않는다. AdMob
/// 광고를 중간에 닫아버린 경우(onUserEarnedReward 콜백 미도달)만 예외적으로
/// `onCancelled()`를 호출해 그리드로 되돌린다(보상 없음, fortune_ad와 동일
/// 정책).
class PouchAdOverlay extends StatefulWidget {
  final void Function(int watchSeconds) onCompleted;
  final VoidCallback onCancelled;
  final VoidCallback onFailed;

  const PouchAdOverlay({
    super.key,
    required this.onCompleted,
    required this.onCancelled,
    required this.onFailed,
  });

  @override
  State<PouchAdOverlay> createState() => _PouchAdOverlayState();
}

class _PouchAdOverlayState extends State<PouchAdOverlay> {
  static const int _seconds = 5;
  int _remaining = _seconds;
  bool _admobLoading = true;
  String? _errorMessage;

  bool get _isAdmob => AdmobAdIds.isSupportedPlatform;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  void _start() {
    if (_isAdmob) {
      _loadAndShowAdmobRewardedAd();
    } else {
      _tickSimulated();
    }
  }

  void _tickSimulated() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        _remaining = _remaining > 0 ? _remaining - 1 : 0;
      });
      if (_remaining > 0) {
        _tickSimulated();
      } else {
        widget.onCompleted(_seconds);
      }
    });
  }

  void _loadAndShowAdmobRewardedAd() {
    RewardedAd.load(
      adUnitId: AdmobAdIds.rewardedUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() => _admobLoading = false);
          bool rewarded = false;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              if (!mounted) return;
              if (rewarded) {
                widget.onCompleted(_seconds);
              } else {
                widget.onCancelled();
              }
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              if (kDebugMode) {
                debugPrint('[PouchAdOverlay] 애드몹 표시 실패 -> $error');
              }
              if (!mounted) return;
              widget.onFailed();
            },
          );
          ad.show(
            onUserEarnedReward: (ad, reward) {
              rewarded = true;
            },
          );
        },
        onAdFailedToLoad: (error) {
          if (kDebugMode) {
            debugPrint('[PouchAdOverlay] 애드몹 로드 실패 -> $error');
          }
          if (!mounted) return;
          setState(() {
            _errorMessage = '지금은 광고를 불러올 수 없어요. 잠시 후 다시 시도해주세요.';
          });
          Future.delayed(const Duration(milliseconds: 900), () {
            if (mounted) widget.onFailed();
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1E1932).withValues(alpha: 0.72),
      child: Center(
        child: Container(
          width: 260,
          padding: const EdgeInsets.symmetric(
            horizontal: LuckyBoxTokens.sp6,
            vertical: LuckyBoxTokens.sp8,
          ),
          decoration: BoxDecoration(
            color: LuckyBoxTokens.bgBase,
            borderRadius: BorderRadius.circular(LuckyBoxTokens.rCard),
            boxShadow: LuckyBoxTokens.blackShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: LuckyBoxTokens.sp2,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: LuckyBoxTokens.fgPrimary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'AD',
                      style: TextStyle(
                        fontFamily: LuckyBoxTokens.fontMono,
                        fontSize: 11,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  if (!_isAdmob)
                    Text('$_remaining', style: LuckyBoxTokens.monoLabel),
                ],
              ),
              const SizedBox(height: LuckyBoxTokens.sp6),
              const Text('🧧', style: TextStyle(fontSize: 44)),
              const SizedBox(height: LuckyBoxTokens.sp4),
              Text(
                _errorMessage ?? '잠시 후 복주머니를 열 수 있어요',
                textAlign: TextAlign.center,
                style: LuckyBoxTokens.bodyText.copyWith(
                  color: LuckyBoxTokens.fgSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: LuckyBoxTokens.sp6),
              ClipRRect(
                borderRadius: BorderRadius.circular(LuckyBoxTokens.rPill),
                child: LinearProgressIndicator(
                  value: _isAdmob
                      ? (_admobLoading ? null : 1.0)
                      : (1 - _remaining / _seconds),
                  minHeight: 5,
                  backgroundColor: LuckyBoxTokens.bgSofter,
                  color: LuckyBoxTokens.accentGlow,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
