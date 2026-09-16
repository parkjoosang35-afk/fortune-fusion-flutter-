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
///
/// [광고 로드 실패 처리] dev-spec.md §7 항목10 "재시도 / 오늘 소진 처리 /
/// 소용량 리트라이" 중 "재시도"를 채택. 최초 로드 실패 시 1회 자동
/// 재시도하고, 그마저도 실패하면 사용자가 "다시 시도"/"그만두기"를 직접
/// 선택하는 UI로 전환한다(예전처럼 900ms 후 조용히 그리드로 튕기지 않음 —
/// 사용자가 왜 상자가 안 열리는지 이해할 새도 없이 사라지는 문제 방지).
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
  bool _autoRetried = false;
  bool _showRetryActions = false;

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
          _handleLoadFailure();
        },
      ),
    );
  }

  /// 최초 실패 시 1회 자동 재시도(짧은 지연 후 조용히 다시 로드). 재시도도
  /// 실패하면 사용자가 직접 선택할 수 있는 액션 버튼을 보여준다.
  void _handleLoadFailure() {
    if (!_autoRetried) {
      _autoRetried = true;
      setState(() {
        _admobLoading = true;
        _errorMessage = '광고를 다시 불러오고 있어요';
      });
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (!mounted) return;
        _loadAndShowAdmobRewardedAd();
      });
      return;
    }
    setState(() {
      _admobLoading = false;
      _showRetryActions = true;
      _errorMessage = '지금은 광고를 불러올 수 없어요.';
    });
  }

  void _retryManually() {
    setState(() {
      _showRetryActions = false;
      _admobLoading = true;
      _errorMessage = null;
      _autoRetried = false; // 사용자가 직접 누른 재시도는 다시 1회 자동재시도 허용
    });
    _loadAndShowAdmobRewardedAd();
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
              if (_showRetryActions) ...[
                const SizedBox(height: LuckyBoxTokens.sp5),
                _RetryActions(
                  onRetry: _retryManually,
                  onGiveUp: widget.onFailed,
                ),
              ] else ...[
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
            ],
          ),
        ),
      ),
    );
  }
}

/// 자동 재시도까지 모두 실패했을 때 사용자에게 보여주는 선택 UI.
/// "다시 시도" 탭 시 광고 로드를 재시도하고, "그만두기" 탭 시
/// [PouchAdOverlay.onFailed]를 호출해 그리드로 되돌린다(보상 없음).
class _RetryActions extends StatelessWidget {
  final VoidCallback onRetry;
  final VoidCallback onGiveUp;

  const _RetryActions({required this.onRetry, required this.onGiveUp});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onGiveUp,
            style: OutlinedButton.styleFrom(
              foregroundColor: LuckyBoxTokens.fgSecondary,
              side: BorderSide(color: LuckyBoxTokens.line),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(LuckyBoxTokens.rPill),
              ),
              padding: const EdgeInsets.symmetric(
                vertical: LuckyBoxTokens.sp3,
              ),
            ),
            child: const Text('그만두기'),
          ),
        ),
        const SizedBox(width: LuckyBoxTokens.sp3),
        Expanded(
          child: ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: LuckyBoxTokens.ctaPrimaryBg,
              foregroundColor: LuckyBoxTokens.ctaPrimaryFg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(LuckyBoxTokens.rPill),
              ),
              padding: const EdgeInsets.symmetric(
                vertical: LuckyBoxTokens.sp3,
              ),
              elevation: 0,
            ),
            child: const Text('다시 시도'),
          ),
        ),
      ],
    );
  }
}
