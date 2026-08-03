import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_unified_style.dart';
import '../application/pass_provider.dart';
import 'pass_time_format.dart';

/// [프리패스 단순화 - 쿠팡파트너스 전용] §6/§7/§8 실시간 카운트다운 공통 위젯.
///
/// - §6: HH:MM:SS 형식으로 1초마다 자동 감소.
/// - §7: 은은한 Glow 펄스 + 숫자가 바뀔 때 부드러운 Fade 전환.
/// - §8: 활성→비활성으로 전환되는 순간(만료) [onExpired] 콜백을 1회 호출한다.
///   ([OpenPassState.fromModel]이 expiresAt 기준으로 매 호출마다 실시간
///   재계산하므로, 여기서는 1초 Timer로 rebuild만 트리거하면 만료 순간을
///   정확히 감지할 수 있다 — 별도 서버 폴링 불필요.)
///
/// 활성 상태가 아니면 아무것도 그리지 않는다(SizedBox.shrink) — 화면은 이
/// 위젯이 사라지는 것 자체로 "프리패스 받기" 화면으로 자연스럽게 복귀한다.
class PassCountdownBadge extends StatefulWidget {
  const PassCountdownBadge({
    super.key,
    this.onExpired,
    this.dense = false,
  });

  /// 활성 → 비활성(만료) 전환 순간 1회 호출.
  final VoidCallback? onExpired;

  /// true이면 홈 상단바처럼 얇은 한 줄 버전으로 렌더링한다.
  final bool dense;

  @override
  State<PassCountdownBadge> createState() => _PassCountdownBadgeState();
}

class _PassCountdownBadgeState extends State<PassCountdownBadge>
    with SingleTickerProviderStateMixin {
  Timer? _ticker;
  bool _wasActive = false;
  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pass = context.watch<PassProvider>();
    final state = pass.openPassState;
    final isActive = state.isActive;

    if (_wasActive && !isActive) {
      // §8: 방금 막 만료됨 — 다음 프레임에 콜백(빌드 중 setState/네비게이션
      // 유발 방지를 위해 addPostFrameCallback으로 지연 호출).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onExpired?.call();
      });
    }
    _wasActive = isActive;

    if (!isActive) return const SizedBox.shrink();

    final label = formatPassHms(state.remaining);

    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        final glow = 0.25 + (_glowController.value * 0.35);
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: widget.dense
                ? UnifiedTokens.spaceMd
                : UnifiedTokens.spaceLg,
            vertical: widget.dense ? 6 : UnifiedTokens.spaceSm,
          ),
          decoration: BoxDecoration(
            color: UnifiedColors.black,
            borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
            boxShadow: [
              BoxShadow(
                color: UnifiedColors.neon.withValues(alpha: glow),
                blurRadius: 16,
                spreadRadius: 1,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock_open_rounded,
            size: widget.dense ? UnifiedTokens.iconSm : UnifiedTokens.iconMd,
            color: UnifiedColors.neon,
          ),
          const SizedBox(width: 6),
          Text(
            '프리패스 이용중',
            style: TextStyle(
              fontFamily: UnifiedText.family,
              fontSize: widget.dense ? 11 : 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '·',
            style: TextStyle(
              fontSize: widget.dense ? 11 : 13,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(width: 6),
          // §7: 숫자가 바뀔 때마다 부드럽게 Fade 전환.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, anim) =>
                FadeTransition(opacity: anim, child: child),
            child: Text(
              label,
              key: ValueKey(label),
              style: TextStyle(
                fontFamily: UnifiedText.family,
                fontSize: widget.dense ? 12 : 14,
                fontWeight: FontWeight.w700,
                color: UnifiedColors.neon,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Text(
            ' 남음',
            style: TextStyle(
              fontSize: widget.dense ? 11 : 13,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
