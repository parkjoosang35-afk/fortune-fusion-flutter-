import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_unified_style.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_toast.dart';
import '../../wallet/application/wallet_provider.dart';
import '../application/pass_provider.dart';
import '../domain/pass_model.dart';
import '../../ad_banner/presentation/ad_script_view.dart';
import 'pass_time_format.dart';

/// [프리패스 단순화 - 쿠팡파트너스 전용] §3/§4/§5/§7 신규 통합 바텀시트.
///
/// admin_web "CMS 쿠팡파트너스 배너(positionCode=open_pass)"가 곧 프리패스
/// 광고이므로, 화면은 정책 목록 중 passType=='ad' 단 하나만 사용한다
/// (§10 "프리패스는 쿠팡 파트너스 광고 전용 기능으로 운영").
///
/// 흐름(§4): "쿠팡 방문하기" 탭 1회 → 외부 브라우저에서 쿠팡 파트너스 광고 확인
/// → 앱으로 복귀 감지([WidgetsBindingObserver.didChangeAppLifecycleState]) →
/// 관리자가 설정한 대기시간(4/10초) 카운트다운 → 자동 지급([PassProvider.claimAd])
/// — 재탭 없이 자동으로 완료된다. 앱 라이프사이클 감지가 되지 않는 환경(웹 브라우저
/// 탭 전환 등)을 대비해, 복귀 대기 화면에 수동 확인 버튼도 함께 둔다(이중 안전장치).
Future<void> showCoupangPassSheet(
  BuildContext context, {
  String? categoryTitle,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: UnifiedColors.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _CoupangPassSheet(categoryTitle: categoryTitle),
  );
}

enum _Phase { idle, waitingReturn, counting, success }

class _CoupangPassSheet extends StatefulWidget {
  const _CoupangPassSheet({this.categoryTitle});

  final String? categoryTitle;

  @override
  State<_CoupangPassSheet> createState() => _CoupangPassSheetState();
}

class _CoupangPassSheetState extends State<_CoupangPassSheet>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  _Phase _phase = _Phase.idle;
  int _secondsLeft = 0;
  Timer? _countdownTimer;
  bool _launchedAd = false;
  bool _claiming = false;
  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    // §9: 시트를 열 때마다 admin_web 최신 데이터(광고 이미지/링크/이용시간/
    // 대기시간)를 다시 조회해, 관리자가 방금 수정한 값이 즉시 반영되게 한다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<PassProvider>().load();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    _glowController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // §4: 쿠팡 방문 후 앱으로 복귀하는 순간을 자동 감지한다.
    if (state == AppLifecycleState.resumed &&
        _launchedAd &&
        _phase == _Phase.waitingReturn) {
      final policy = _adPolicy;
      if (policy != null) _startCountdown(policy);
    }
  }

  PassPolicyModel? get _adPolicy {
    final pass = context.read<PassProvider>();
    for (final p in pass.policies) {
      if (p.passType == PassType.ad) return p;
    }
    return null;
  }

  Future<void> _handleVisit(PassPolicyModel policy) async {
    if (policy.linkUrl == null || policy.linkUrl!.isEmpty) {
      AppToast.show(context, '아직 쿠팡 파트너스 광고가 설정되지 않았어요.', isError: true);
      return;
    }
    final uri = Uri.tryParse(policy.linkUrl!);
    if (uri == null) {
      AppToast.show(context, '광고 링크가 올바르지 않아요.', isError: true);
      return;
    }
    setState(() {
      _phase = _Phase.waitingReturn;
      _launchedAd = true;
    });
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _startCountdown(PassPolicyModel policy) {
    if (_phase == _Phase.counting || _phase == _Phase.success) return;
    setState(() {
      _phase = _Phase.counting;
      _secondsLeft = policy.adWaitSeconds;
    });
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        timer.cancel();
        _claimPass(policy);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _claimPass(PassPolicyModel policy) async {
    if (_claiming) return;
    _claiming = true;
    final pass = context.read<PassProvider>();
    final ok = await pass.claimAd(policyId: policy.id);
    if (!mounted) return;

    if (ok) {
      await context.read<WalletProvider>().load();
      if (!mounted) return;
      setState(() => _phase = _Phase.success);
      await Future.delayed(const Duration(milliseconds: 1400));
      if (mounted) Navigator.of(context).pop();
    } else {
      _claiming = false;
      setState(() => _phase = _Phase.idle);
      AppToast.show(
        context,
        pass.lastError ?? '프리패스 발급에 실패했습니다. 다시 시도해주세요.',
        isError: true,
      );
    }
  }

  void _showHelp() {
    showAppInfoDialog(
      context,
      title: '프리패스 안내',
      message: '쿠팡 파트너스 활동을 통해 일정 수수료를 지급받는 제휴 광고예요.\n'
          '쿠팡 방문 후 앱으로 돌아오면 잠시 후 자동으로 프리패스가 지급됩니다.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final pass = context.watch<PassProvider>();
    final policy = () {
      for (final p in pass.policies) {
        if (p.passType == PassType.ad) return p;
      }
      return null;
    }();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: UnifiedTokens.spaceXl,
          right: UnifiedTokens.spaceXl,
          top: UnifiedTokens.spaceMd,
          bottom: UnifiedTokens.spaceXl + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHandle(),
            _buildHeaderRow(),
            const SizedBox(height: UnifiedTokens.spaceXs),
            if (policy == null)
              _buildEmptyState(pass.isLoading)
            else if (_phase == _Phase.success)
              _SuccessCelebration(durationLabel: formatPassDuration(policy.durationMin))
            else
              _buildContent(policy),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        margin: const EdgeInsets.only(bottom: UnifiedTokens.spaceLg),
        decoration: BoxDecoration(
          color: UnifiedColors.border,
          borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
        ),
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Row(
      children: [
        IconButton(
          onPressed: _showHelp,
          icon: const Icon(Icons.help_outline_rounded, color: UnifiedColors.textCaption),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          iconSize: UnifiedTokens.iconLg,
        ),
        const Spacer(),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded, color: UnifiedColors.textCaption),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          iconSize: UnifiedTokens.iconLg,
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isLoading) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: UnifiedTokens.spaceXxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('프리패스가 필요해요', style: UnifiedText.title()),
          const SizedBox(height: UnifiedTokens.spaceSm),
          if (isLoading)
            const Center(child: CircularProgressIndicator())
          else
            Text('아직 프리패스 광고가 준비되지 않았어요. 잠시 후 다시 시도해주세요.', style: UnifiedText.body()),
        ],
      ),
    );
  }

  Widget _buildContent(PassPolicyModel policy) {
    final durationLabel = formatPassDuration(policy.durationMin);
    final isCounting = _phase == _Phase.counting;
    final isWaitingReturn = _phase == _Phase.waitingReturn;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.categoryTitle != null
              ? '"${widget.categoryTitle}"는 프리패스로 열람할 수 있어요'
              : '프리패스가 필요해요',
          style: UnifiedText.title(),
        ),
        const SizedBox(height: UnifiedTokens.spaceXs),
        Text(
          '쿠팡 파트너스 광고를 확인하면 $durationLabel 동안\n모든 콘텐츠를 무료로 이용할 수 있어요.',
          style: UnifiedText.body(),
        ),
        const SizedBox(height: UnifiedTokens.spaceLg),

        // 광고 이미지/스크립트 영역
        ClipRRect(
          borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
          child: _buildAdMedia(policy),
        ),
        const SizedBox(height: UnifiedTokens.spaceMd),

        // "쿠팡 방문하기" 버튼
        InkWell(
          onTap: isCounting || _claiming ? null : () => _handleVisit(policy),
          borderRadius: BorderRadius.circular(UnifiedTokens.radiusSm),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: UnifiedTokens.spaceSm),
            child: Row(
              children: [
                const Icon(Icons.open_in_new_rounded, size: UnifiedTokens.iconMd, color: UnifiedColors.textPrimary),
                const SizedBox(width: UnifiedTokens.spaceSm),
                Text('쿠팡 방문하기', style: UnifiedText.bodyStrong()),
              ],
            ),
          ),
        ),
        Text('파트너스 활동을 통해 일정액의 수수료를 지급받을 수 있어요', style: UnifiedText.caption()),
        const SizedBox(height: UnifiedTokens.spaceLg),

        // 대기/카운트다운 상태 안내
        if (isWaitingReturn) _buildWaitingBanner(policy),
        if (isCounting) _buildCountingBanner(),

        // 이용시간 뱃지
        _buildDurationPill(durationLabel),
        const SizedBox(height: UnifiedTokens.spaceLg),

        // 메인 CTA
        _buildMainCta(policy, durationLabel),

        const SizedBox(height: UnifiedTokens.spaceSm),
        Center(
          child: TextButton(
            onPressed: (isCounting || _claiming) ? null : () => Navigator.of(context).pop(),
            child: Text('나중에 할게요', style: UnifiedText.caption()),
          ),
        ),
      ],
    );
  }

  Widget _buildAdMedia(PassPolicyModel policy) {
    const height = 150.0;
    if (policy.adType == 'script' && policy.adScript != null && policy.adScript!.isNotEmpty) {
      return SizedBox(height: height, width: double.infinity, child: buildAdScriptView(policy.adScript!, height: height));
    }
    if (policy.bannerImageUrl != null && policy.bannerImageUrl!.isNotEmpty) {
      return Image.network(
        policy.bannerImageUrl!,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _adPlaceholder(height),
      );
    }
    return _adPlaceholder(height);
  }

  Widget _adPlaceholder(double height) {
    return Container(
      height: height,
      width: double.infinity,
      color: UnifiedColors.cardBanner,
      alignment: Alignment.center,
      child: const Icon(Icons.local_offer_outlined, size: 36, color: UnifiedColors.textCaption),
    );
  }

  Widget _buildWaitingBanner(PassPolicyModel policy) {
    return Container(
      margin: const EdgeInsets.only(bottom: UnifiedTokens.spaceMd),
      padding: const EdgeInsets.all(UnifiedTokens.spaceMd),
      decoration: BoxDecoration(
        color: UnifiedColors.cardAllMenu,
        borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: UnifiedTokens.spaceSm),
          Expanded(
            child: Text('쿠팡 페이지 확인 중이에요. 앱으로 돌아오면 자동으로 진행돼요.', style: UnifiedText.bodySmall()),
          ),
          TextButton(
            onPressed: () => _startCountdown(policy),
            child: const Text('돌아왔어요'),
          ),
        ],
      ),
    );
  }

  Widget _buildCountingBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: UnifiedTokens.spaceMd),
      padding: const EdgeInsets.all(UnifiedTokens.spaceMd),
      decoration: BoxDecoration(
        color: UnifiedColors.black,
        borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: const AlwaysStoppedAnimation(UnifiedColors.neon),
              value: null,
            ),
          ),
          const SizedBox(width: UnifiedTokens.spaceSm),
          Expanded(
            child: Text(
              '쿠팡 광고 확인 중... $_secondsLeft초 후 자동 지급',
              style: UnifiedText.bodySmall(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationPill(String durationLabel) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: UnifiedTokens.spaceMd, vertical: 6),
      decoration: BoxDecoration(
        color: UnifiedColors.cardAllMenu,
        borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, size: UnifiedTokens.iconSm, color: UnifiedColors.textSecondary),
          const SizedBox(width: 4),
          Text('프리패스 이용시간 · $durationLabel', style: UnifiedText.chipLabel(color: UnifiedColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildMainCta(PassPolicyModel policy, String durationLabel) {
    final isCounting = _phase == _Phase.counting;
    final disabled = isCounting || _claiming;

    String label;
    switch (_phase) {
      case _Phase.idle:
        label = '프리패스 $durationLabel 받기';
        break;
      case _Phase.waitingReturn:
        label = '쿠팡 방문 후 앱으로 돌아와주세요';
        break;
      case _Phase.counting:
        label = '지급 중... $_secondsLeft초';
        break;
      case _Phase.success:
        label = '지급 완료';
        break;
    }

    final onTap = disabled
        ? null
        : () {
            if (_phase == _Phase.waitingReturn) {
              _startCountdown(policy);
            } else {
              _handleVisit(policy);
            }
          };

    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        final glow = disabled ? 0.0 : 0.15 + (_glowController.value * 0.25);
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
            boxShadow: glow > 0
                ? [
                    BoxShadow(
                      color: UnifiedColors.black.withValues(alpha: glow),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: child,
        );
      },
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: UnifiedColors.black,
            disabledBackgroundColor: UnifiedColors.black.withValues(alpha: 0.6),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
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

/// §5/§7 지급 완료 축하 애니메이션 — 체크 아이콘 스케일-인 + 반짝임(sparkle) +
/// 부드러운 Fade. 과하지 않게 900ms 이내로 짧게 재생한다.
class _SuccessCelebration extends StatefulWidget {
  const _SuccessCelebration({required this.durationLabel});

  final String durationLabel;

  @override
  State<_SuccessCelebration> createState() => _SuccessCelebrationState();
}

class _SuccessCelebrationState extends State<_SuccessCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const _sparkles = [
    Offset(-42, -30),
    Offset(38, -34),
    Offset(-46, 22),
    Offset(44, 26),
    Offset(0, -48),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    final fade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: UnifiedTokens.spaceXxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 96,
            height: 96,
            child: Stack(
              alignment: Alignment.center,
              children: [
                ..._sparkles.map(
                  (offset) => AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      final t = Curves.easeOut.transform(_controller.value);
                      return Positioned(
                        left: 48 + offset.dx * t - 7,
                        top: 48 + offset.dy * t - 7,
                        child: Opacity(
                          opacity: (1 - t).clamp(0.0, 1.0),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            size: 14,
                            color: UnifiedColors.neon,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                ScaleTransition(
                  scale: scale,
                  child: FadeTransition(
                    opacity: fade,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: UnifiedColors.black,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_rounded, color: UnifiedColors.neon, size: 40),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: UnifiedTokens.spaceLg),
          FadeTransition(
            opacity: fade,
            child: Text('프리패스가 발급되었어요!', style: UnifiedText.title()),
          ),
          const SizedBox(height: UnifiedTokens.spaceXs),
          FadeTransition(
            opacity: fade,
            child: Text(
              '${widget.durationLabel} 동안 모든 콘텐츠를 자유롭게 이용하세요',
              style: UnifiedText.caption(),
            ),
          ),
        ],
      ),
    );
  }
}
