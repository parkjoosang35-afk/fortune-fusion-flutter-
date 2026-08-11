import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../../../core/theme/app_unified_style.dart';
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
  factory FortuneAdWatchResult.failed(String message) =>
      FortuneAdWatchResult._(FortuneAdWatchOutcome.failed, errorMessage: message);
}

/// [신통방통 복주머니 광고 적립 시스템] 광고 시청 팝업 —
/// 시작(자격확인) → 시청중(진행률/남은시간/보상, 중간종료시 보상없음) →
/// 완료(서버검증) → 지급애니메이션("복주머니가 열렸습니다! +N") 순으로 진행한다.
///
/// 서버 최종 지급 원칙: 이 다이얼로그는 시청 진행률만 표시할 뿐, 실제 지급은
/// 전적으로 서버(`POST /api/ads/{adId}/complete`)가 결정한다 — 클라이언트가
/// "다 봤다"고 판단해도 서버가 자격 재검증에서 거부하면 지급되지 않는다.
class FortuneAdWatchDialog extends StatefulWidget {
  final FortuneAdModel ad;
  const FortuneAdWatchDialog({super.key, required this.ad});

  static Future<FortuneAdWatchResult> show(
    BuildContext context, {
    required FortuneAdModel ad,
  }) async {
    final result = await showDialog<FortuneAdWatchResult>(
      context: context,
      barrierDismissible: false,
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

    if (widget.ad.adType == 'video' &&
        (widget.ad.videoUrl ?? '').isNotEmpty) {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(widget.ad.videoUrl!),
      )..initialize().then((_) {
          if (!mounted) return;
          _videoController!.play();
        });
    }

    setState(() => _stage = _Stage.watching);
    _tick();
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
    Navigator.of(context).pop(
      FortuneAdWatchResult.granted(_grantedAmount ?? 0, _balanceAfter),
    );
  }

  void _closeAsFailed() {
    if (_closed) return;
    _closed = true;
    Navigator.of(context).pop(
      FortuneAdWatchResult.failed(_errorMessage ?? '처리 중 오류가 발생했습니다.'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: UnifiedColors.black,
        insetPadding: const EdgeInsets.all(UnifiedTokens.spaceLg),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
        ),
        child: SizedBox(height: 420, child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    switch (_stage) {
      case _Stage.starting:
        return const Center(
          child: CircularProgressIndicator(color: UnifiedColors.neon),
        );
      case _Stage.watching:
        return _WatchingView(
          ad: widget.ad,
          videoController: _videoController,
          remaining: _remaining,
          total: _totalSeconds,
          onClose: _closeAsCancelled,
        );
      case _Stage.verifying:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: UnifiedColors.neon),
              SizedBox(height: UnifiedTokens.spaceMd),
              Text(
                '서버에서 시청 결과를 확인하고 있어요...',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        );
      case _Stage.granted:
        return _GrantedView(
          amount: _grantedAmount ?? 0,
          onDone: _closeAsGranted,
        );
      case _Stage.error:
        return _ErrorView(
          message: _errorMessage ?? '오류가 발생했습니다.',
          onDone: _closeAsFailed,
        );
    }
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

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 1.0 : 1 - (remaining / total);
    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: Center(
                child: _buildContent(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
              child: Column(
                children: [
                  Text(
                    ad.title,
                    textAlign: TextAlign.center,
                    style: UnifiedText.bodyStrong(color: Colors.white),
                  ),
                  const SizedBox(height: UnifiedTokens.spaceSm),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: const Color(0xFF2A2A2A),
                      color: UnifiedColors.neon,
                    ),
                  ),
                  const SizedBox(height: UnifiedTokens.spaceSm),
                  Text(
                    '$remaining초 후 +${ad.rewardAmount}개 지급 (끝까지 시청해야 지급돼요)',
                    textAlign: TextAlign.center,
                    style: UnifiedText.caption(color: UnifiedColors.neon),
                  ),
                ],
              ),
            ),
          ],
        ),
        Positioned(
          top: UnifiedTokens.spaceSm,
          right: UnifiedTokens.spaceSm,
          child: IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, color: Color(0xFFB8B8B8)),
            tooltip: '중간에 닫으면 보상이 지급되지 않아요',
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
        borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
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
      color: UnifiedColors.neon,
      size: 72,
    );
  }
}

class _GrantedView extends StatelessWidget {
  final int amount;
  final VoidCallback onDone;
  const _GrantedView({required this.amount, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🧧', style: TextStyle(fontSize: 64)),
          const SizedBox(height: UnifiedTokens.spaceMd),
          const Text(
            '복주머니가 열렸습니다!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: UnifiedTokens.spaceSm),
          Text(
            '+$amount개',
            style: const TextStyle(
              color: UnifiedColors.neon,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: UnifiedTokens.spaceXxl),
          ElevatedButton(
            onPressed: onDone,
            style: ElevatedButton.styleFrom(
              backgroundColor: UnifiedColors.neon,
              foregroundColor: UnifiedColors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onDone;
  const _ErrorView({required this.message, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(UnifiedTokens.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
            const SizedBox(height: UnifiedTokens.spaceMd),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: UnifiedTokens.spaceXxl),
            ElevatedButton(
              onPressed: onDone,
              style: ElevatedButton.styleFrom(
                backgroundColor: UnifiedColors.neon,
                foregroundColor: UnifiedColors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text('확인'),
            ),
          ],
        ),
      ),
    );
  }
}
