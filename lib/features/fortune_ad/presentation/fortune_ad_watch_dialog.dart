import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../../ads_test/domain/admob_ad_ids.dart';
import '../../mypage/presentation/theme/mypage_minimal_theme.dart';
import '../../mypage/presentation/theme/mypage_dashed_border.dart';
import '../../mypage/presentation/theme/mypage_success_celebration.dart';
import '../application/fortune_ad_provider.dart';
import '../domain/fortune_ad_model.dart';

/// [신통방통 복주머니 광고 적립 시스템] 광고 시청 팝업 결과.
enum FortuneAdWatchOutcome {
  /// 끝까지 시청 + 서버 지급 성공.
  granted,

  /// 중간에 닫음(스킵) — 서버에 지급 요청을 아예 보내지 않는다(보상 없음).
  cancelled,

  /// 서버 지급 요청은 보냈으나 실패(자격 재검증 실패/네트워크 오류 등).
  failed,
}

class FortuneAdWatchResult {
  final FortuneAdWatchOutcome outcome;
  final int? grantedAmount;
  final int? balanceAfter;
  final String? errorMessage;

  const FortuneAdWatchResult._(
    this.outcome, {
    this.grantedAmount,
    this.balanceAfter,
    this.errorMessage,
  });

  factory FortuneAdWatchResult.granted(int amount, int? balance) =>
      FortuneAdWatchResult._(
        FortuneAdWatchOutcome.granted,
        grantedAmount: amount,
        balanceAfter: balance,
      );
  factory FortuneAdWatchResult.cancelled() =>
      const FortuneAdWatchResult._(FortuneAdWatchOutcome.cancelled);
  factory FortuneAdWatchResult.failed(String message) => FortuneAdWatchResult._(
    FortuneAdWatchOutcome.failed,
    errorMessage: message,
  );
}

/// [신통방통 복주머니 광고 적립 시스템] 광고 시청 팝업 —
/// 시작(자격확인) → 시청중(진행률/남은시간/보상, 중간종료시 보상없음) →
/// 완료(서버검증) → 지급애니메이션("복주머니가 열렸습니다! +N") 순으로 진행한다.
///
/// 서버 최종 지급 원칙: 이 다이얼로그는 시청 진행률만 표시할 뿐, 실제 지급은
/// 전적으로 서버(`POST /api/ads/{adId}/complete`)가 결정한다 — 클라이언트가
/// "다 봤다"고 판단해도 서버가 자격 재검증에서 거부하면 지급되지 않는다.
///
/// [마이페이지 리뉴얼 · DEV 2026-11-06 §S04] 디자인 핸드오프
/// `design_handoff_mypage_minimal.zip` README §4 "S02 / S04 광고 바텀시트"
/// 스펙으로 전면 리스킨. 기존 `UnifiedColors`/`UnifiedText`(다크 테마,
/// `Dialog` 카드) → `MyPageColors`/`MyPageTextStyles`(한지/부적 라이트
/// 테마) 기반 **바텀시트 형태**(`showModalBottomSheet`, S02와 동일한 톤)로
/// 교체했을 뿐, 상태 머신(`_Stage`: starting/watching/verifying/granted/
/// error)·서버 세션 발급(`startWatch`)·AdMob SDK 로드/표시·
/// `onUserEarnedReward` 콜백 처리(절대 지급량으로 신뢰하지 않음)·서버 최종
/// 검증(`completeWatch`) 등 기능 로직은 단 한 줄도 바꾸지 않았다(S01/S02와
/// 동일한 "로직은 그대로, 스킨만 교체" 원칙).
class FortuneAdWatchDialog extends StatefulWidget {
  final FortuneAdModel ad;
  const FortuneAdWatchDialog({super.key, required this.ad});

  static Future<FortuneAdWatchResult> show(
    BuildContext context, {
    required FortuneAdModel ad,
  }) async {
    // README §S02/S04: dim rgba(30,18,10,.45), 시트 radius 30 30 0 0.
    final result = await showModalBottomSheet<FortuneAdWatchResult>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: MyPageColors.surface,
      barrierColor: const Color(0x731E120A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(MyPageRadius.sheet),
        ),
      ),
      builder: (_) => FortuneAdWatchDialog(ad: ad),
    );
    return result ?? FortuneAdWatchResult.cancelled();
  }

  @override
  State<FortuneAdWatchDialog> createState() => _FortuneAdWatchDialogState();
}

enum _Stage { starting, watching, verifying, granted, error }

class _FortuneAdWatchDialogState extends State<FortuneAdWatchDialog> {
  _Stage _stage = _Stage.starting;
  String? _sessionId;
  int _totalSeconds = 15;
  int _remaining = 15;
  int? _grantedAmount;
  int? _balanceAfter;
  String? _errorMessage;
  VideoPlayerController? _videoController;
  bool _closed = false;

  bool get _isAdmob => widget.ad.adType == 'admob';

  /// [애드몹 실제 연동] AdMob SDK의 `onUserEarnedReward` 콜백이 호출됐는지만
  /// 기록한다 — 이 콜백이 전달하는 [RewardItem.amount]는 절대 사용하지
  /// 않는다. 실제 지급 개수는 오직 서버(`/complete` 응답의
  /// `FortuneAd.rewardAmount`, 즉 admin_web에서 관리자가 설정한 값)만이
  /// 결정한다는 원칙(사장님이 명시적으로 강조하신 사항)을 지키기 위함이다.
  /// 이 플래그는 "광고를 끝까지 봤다"는 사실 여부만 서버 호출 여부를
  /// 판단하는 데 쓰인다.
  bool _admobRewardEarned = false;

  @override
  void initState() {
    super.initState();
    _totalSeconds = widget.ad.watchSeconds;
    _remaining = _totalSeconds;
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final provider = context.read<FortuneAdProvider>();
    final result = await provider.startWatch(widget.ad);
    if (!mounted) return;
    if (!result.success) {
      setState(() {
        _stage = _Stage.error;
        _errorMessage = result.errorMessage ?? '지금은 시청할 수 없습니다.';
      });
      return;
    }
    final session = result.data!;
    _sessionId = session.sessionId;
    _totalSeconds = session.watchSeconds;
    _remaining = _totalSeconds;

    if (_isAdmob) {
      setState(() => _stage = _Stage.watching);
      _loadAndShowAdmobRewardedAd();
      return;
    }

    if (widget.ad.adType == 'video' && (widget.ad.videoUrl ?? '').isNotEmpty) {
      _videoController =
          VideoPlayerController.networkUrl(Uri.parse(widget.ad.videoUrl!))
            ..initialize().then((_) {
              if (!mounted) return;
              _videoController!.play();
            });
    }

    setState(() => _stage = _Stage.watching);
    _tick();
  }

  /// [애드몹 실제 연동] 서버가 세션(PENDING 로그)을 발급해 준 뒤에만 실제
  /// AdMob 보상형 광고를 로드/표시한다 — 즉 자격 검증(일일한도 등)은
  /// 여전히 기존과 동일하게 서버가 먼저 통과시켜야 광고 자체가 뜬다.
  /// 광고 재생 자체는 AdMob SDK의 전체화면 오버레이가 담당하고, 이
  /// 다이얼로그는 그 뒤에서 대기하다가 광고가 닫히는 시점에 결과를 반영한다.
  void _loadAndShowAdmobRewardedAd() {
    if (!AdmobAdIds.isSupportedPlatform) {
      setState(() {
        _stage = _Stage.error;
        _errorMessage = '이 플랫폼(Web 등)에서는 애드몹 보상형 광고를 지원하지 않아요.';
      });
      return;
    }
    RewardedAd.load(
      adUnitId: AdmobAdIds.rewardedUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              if (!mounted) return;
              if (_admobRewardEarned) {
                // 끝까지 시청 완료 — 기존과 동일하게 서버 /complete를
                // 호출해 최종 지급 여부·개수를 서버에 맡긴다.
                _complete();
              } else {
                // 중간에 닫음(스킵) — 지급 요청 자체를 보내지 않는다
                // (기존 이미지/영상 광고의 "중간 종료 시 보상 없음"과 동일한
                // 정책, PENDING 세션은 그대로 남아 자연히 미지급 처리된다).
                _closeAsCancelled();
              }
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              if (kDebugMode) {
                debugPrint('[FortuneAdWatchDialog] 애드몹 표시 실패 -> $error');
              }
              if (!mounted) return;
              setState(() {
                _stage = _Stage.error;
                _errorMessage = '광고 표시에 실패했어요. 잠시 후 다시 시도해주세요.';
              });
            },
          );
          ad.show(
            onUserEarnedReward: (ad, reward) {
              // reward.amount는 AdMob 콘솔의 리워드 설정값일 뿐 실제 지급과
              // 무관하다 — 여기서는 "끝까지 봤다"는 사실만 기록한다.
              _admobRewardEarned = true;
            },
          );
        },
        onAdFailedToLoad: (error) {
          if (kDebugMode) {
            debugPrint('[FortuneAdWatchDialog] 애드몹 로드 실패 -> $error');
          }
          if (!mounted) return;
          setState(() {
            _stage = _Stage.error;
            _errorMessage = '지금은 광고를 불러올 수 없어요. 잠시 후 다시 시도해주세요.';
          });
        },
      ),
    );
  }

  void _tick() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted || _stage != _Stage.watching) return;
      setState(() {
        _remaining = _remaining > 0 ? _remaining - 1 : 0;
      });
      if (_remaining > 0) {
        _tick();
      } else {
        _complete();
      }
    });
  }

  Future<void> _complete() async {
    if (_sessionId == null || _closed) return;
    setState(() => _stage = _Stage.verifying);
    final provider = context.read<FortuneAdProvider>();
    final result = await provider.completeWatch(
      adId: widget.ad.id,
      sessionId: _sessionId!,
      watchSeconds: _totalSeconds,
    );
    if (!mounted) return;
    if (!result.success) {
      setState(() {
        _stage = _Stage.error;
        _errorMessage = result.errorMessage ?? '보상 지급에 실패했습니다.';
      });
      return;
    }
    // [핵심 원칙] 지급 개수는 오직 이 서버 응답(result.data!.rewardAmount,
    // admin_web에서 관리자가 FortuneAd.rewardAmount로 설정한 값)만 신뢰한다.
    // AdMob 콘솔에 등록된 "1 복주머니" 같은 리워드 설정값은 여기서 절대
    // 참조하지 않는다(AdMob 리워드 설정 ≠ 실제 지급량 원칙).
    final reward = result.data!;
    // 시청 다이얼로그 캐시(오늘 N/M회 표시)도 서버 최신 상태로 즉시 재조회.
    unawaited(provider.refreshStatus(widget.ad));
    setState(() {
      _stage = _Stage.granted;
      _grantedAmount = reward.rewardAmount;
      _balanceAfter = reward.balance;
    });
  }

  void _closeAsCancelled() {
    if (_closed) return;
    _closed = true;
    Navigator.of(context).pop(FortuneAdWatchResult.cancelled());
  }

  void _closeAsGranted() {
    if (_closed) return;
    _closed = true;
    Navigator.of(
      context,
    ).pop(FortuneAdWatchResult.granted(_grantedAmount ?? 0, _balanceAfter));
  }

  void _closeAsFailed() {
    if (_closed) return;
    _closed = true;
    Navigator.of(
      context,
    ).pop(FortuneAdWatchResult.failed(_errorMessage ?? '처리 중 오류가 발생했습니다.'));
  }

  @override
  Widget build(BuildContext context) {
    // README §S02/S04: 시트 padding `12 24 40`. starting/verifying/granted/
    // error 단계는 내용 높이에 맞춰 자연스럽게 커지되(SingleChildScrollView로
    // 긴 에러 메시지·큰 textScale 대비), watching 단계만 광고 영역(150px) +
    // 진행률 UI가 들어갈 고정 공간이 필요해 기존 420px 높이 컨테이너를
    // 그대로 유지한다.
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: MyPageSpacing.sp6,
          right: MyPageSpacing.sp6,
          top: MyPageSpacing.sp3,
          bottom: 40 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _stage == _Stage.watching
            ? SizedBox(height: 420, child: _buildBody())
            : ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: SingleChildScrollView(child: _buildBody()),
              ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_stage) {
      case _Stage.starting:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: MyPageSpacing.sp8),
          child: Center(
            child: CircularProgressIndicator(color: MyPageColors.red),
          ),
        );
      case _Stage.watching:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHandle(),
            Expanded(
              child: _WatchingView(
                ad: widget.ad,
                videoController: _videoController,
                remaining: _remaining,
                total: _totalSeconds,
                onClose: _closeAsCancelled,
              ),
            ),
          ],
        );
      case _Stage.verifying:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: MyPageSpacing.sp8),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: MyPageColors.red),
                SizedBox(height: MyPageSpacing.sp3),
                Text(
                  '서버에서 시청 결과를 확인하고 있어요...',
                  style: MyPageTextStyles.caption,
                ),
              ],
            ),
          ),
        );
      case _Stage.granted:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MyPageSuccessCelebration(
              title: '복주머니가 열렸습니다!',
              subtitle: '+${_grantedAmount ?? 0}개가 담겼어요',
            ),
            _buildDoneButton('확인', _closeAsGranted),
          ],
        );
      case _Stage.error:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: MyPageSpacing.sp6),
              child: Icon(
                Icons.error_outline_rounded,
                color: MyPageColors.red2,
                size: 48,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: MyPageSpacing.sp2,
              ),
              child: Text(
                _errorMessage ?? '오류가 발생했습니다.',
                textAlign: TextAlign.center,
                style: MyPageTextStyles.body,
              ),
            ),
            _buildDoneButton('확인', _closeAsFailed),
          ],
        );
    }
  }

  // README §S02/S04: 그랩바 40×4.
  Widget _buildHandle() {
    return Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.only(bottom: MyPageSpacing.sp3),
      decoration: BoxDecoration(
        color: MyPageColors.hair,
        borderRadius: BorderRadius.circular(MyPageRadius.pill),
      ),
    );
  }

  Widget _buildDoneButton(String label, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.only(top: MyPageSpacing.sp2),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: MyPageColors.red,
            foregroundColor: const Color(0xFFFBF1DE),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(MyPageRadius.pill),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _WatchingView extends StatelessWidget {
  final FortuneAdModel ad;
  final VideoPlayerController? videoController;
  final int remaining;
  final int total;
  final VoidCallback onClose;

  const _WatchingView({
    required this.ad,
    required this.videoController,
    required this.remaining,
    required this.total,
    required this.onClose,
  });

  /// [애드몹 실제 연동] admob 타입은 이 다이얼로그가 배경일 뿐, 실제 광고는
  /// AdMob SDK가 별도의 전체화면 오버레이로 그 위에 띄운다. 따라서 여기서는
  /// 기존 이미지/영상 광고처럼 남은 시간을 세거나 "N초 후 +M개 지급"을
  /// 표시하면 안 된다(admob 모드에서는 `_tick()`이 아예 호출되지 않으므로
  /// remaining/total이 갱신되지 않아 화면에 멈춘 숫자가 보이는 버그가 생김).
  /// 대신 광고를 불러오는 중이라는 간단한 안내만 보여준다.
  bool get _isAdmob => ad.adType == 'admob';

  @override
  Widget build(BuildContext context) {
    if (_isAdmob) {
      return _buildAdmobWaitingView();
    }
    final progress = total == 0 ? 1.0 : 1 - (remaining / total);
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // README §S04: 제목 "광고 보고 / 복주머니 받기" 21px/800 2줄,
            // 리드 "광고를 끝까지 보면 복주머니 3개가 담겨요".
            const Text(
              '광고 보고\n복주머니 받기',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: MyPageFonts.ui,
                fontWeight: FontWeight.w800,
                fontSize: 21,
                height: 1.3,
                color: MyPageColors.ink,
              ),
            ),
            const SizedBox(height: MyPageSpacing.sp2),
            Text(
              '광고를 끝까지 보면 복주머니 ${ad.rewardAmount}개가 담겨요',
              textAlign: TextAlign.center,
              style: MyPageTextStyles.body,
            ),
            const SizedBox(height: MyPageSpacing.sp4),
            // README §S04: 광고 영역 150px, radius 16, 1px dashed, 하단 3px
            // 빨강 진행바 — S02와 동일한 공용 위젯 재사용.
            Expanded(
              child: MyPageDashedBorderBox(
                radius: MyPageRadius.btn,
                height: 150,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(
                        MyPageRadius.btn - 1,
                      ),
                      child: Center(child: _buildContent()),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(MyPageRadius.btn - 1),
                        ),
                        child: SizedBox(
                          height: 3,
                          child: LinearProgressIndicator(
                            value: progress.clamp(0.0, 1.0),
                            minHeight: 3,
                            backgroundColor: Colors.transparent,
                            color: MyPageColors.red,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: MyPageSpacing.sp3),
            // README §S04: CTA가 "광고 재생 중…"으로 바뀌는 동안의 상태 안내.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(MyPageSpacing.sp3),
              decoration: BoxDecoration(
                color: MyPageColors.redSoft,
                borderRadius: BorderRadius.circular(MyPageRadius.btn),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(MyPageColors.red),
                    ),
                  ),
                  const SizedBox(width: MyPageSpacing.sp2),
                  Flexible(
                    child: Text(
                      '광고 재생 중... $remaining초 후 +${ad.rewardAmount}개 자동 지급',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: MyPageTextStyles.caption.copyWith(
                        color: MyPageColors.redDeep,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        Positioned(
          top: 0,
          right: 0,
          child: SizedBox(
            width: 36,
            height: 36,
            child: IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded, color: MyPageColors.ink3),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: '중간에 닫으면 보상이 지급되지 않아요',
            ),
          ),
        ),
      ],
    );
  }

  /// [애드몹 실제 연동] 광고 로드~표시 사이의 짧은 대기 화면. 카운트다운/진행률
  /// 표시 없이, 실제 지급 여부와 개수는 전적으로 광고 시청 완료 후 서버가
  /// 결정한다는 것만 짧게 안내한다. 이 화면 위로 AdMob 전체화면 광고가 곧
  /// 덮이므로 디자인은 최소한으로 유지한다.
  Widget _buildAdmobWaitingView() {
    return Stack(
      children: [
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: MyPageColors.red),
              const SizedBox(height: MyPageSpacing.sp4),
              Text(
                ad.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: MyPageTextStyles.cardTitle,
              ),
              const SizedBox(height: MyPageSpacing.sp2),
              Text(
                '광고를 불러오고 있어요...\n끝까지 시청하면 복주머니가 지급돼요',
                textAlign: TextAlign.center,
                style: MyPageTextStyles.caption,
              ),
            ],
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: SizedBox(
            width: 36,
            height: 36,
            child: IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded, color: MyPageColors.ink3),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: '중간에 닫으면 보상이 지급되지 않아요',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (ad.adType == 'video' &&
        videoController != null &&
        videoController!.value.isInitialized) {
      return AspectRatio(
        aspectRatio: videoController!.value.aspectRatio,
        child: VideoPlayer(videoController!),
      );
    }
    if (ad.adType == 'image' && (ad.imageUrl ?? '').isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(MyPageRadius.btn - 1),
        child: Image.network(
          ad.imageUrl!,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _fallbackIcon(),
        ),
      );
    }
    return _fallbackIcon();
  }

  Widget _fallbackIcon() {
    return const Icon(
      Icons.smart_display_rounded,
      color: MyPageColors.red,
      size: 56,
    );
  }
}
