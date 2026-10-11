import 'package:flutter/material.dart';

import '../intro_palette.dart';
import '../intro_text_styles.dart';

/// [온보딩 화면 교체 2026-10-11] `Onboarding.html` `.btn-primary` —
/// 그라디언트 배경 + glow pulse(B7, 3.2s) + 광택 스윕(B7', 4.5s, 지연
/// 3s) + press scale(.96).
///
/// [pulse 비활성 옵션] 바텀시트의 「알겠어요」 버튼은 같은 Primary
/// 스타일이지만 pulse 애니메이션이 없다(README "Primary 스타일 (pulse
/// 애니메이션 없음)") — [enablePulse]=false로 재사용한다.
class OnboardingPrimaryButton extends StatefulWidget {
  const OnboardingPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.enablePulse = true,
    this.reduceMotion = false,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onTap;
  final String? icon;
  final bool enablePulse;
  final bool reduceMotion;
  final bool enabled;

  @override
  State<OnboardingPrimaryButton> createState() =>
      _OnboardingPrimaryButtonState();
}

class _OnboardingPrimaryButtonState extends State<OnboardingPrimaryButton>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _shimmerController;
  late final AnimationController _sparkController;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200), // B7.
    );
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500), // B7'.
    );
    // ✧ 아이콘 회전 — "6s"(README 앰비언트 표 마지막 행).
    _sparkController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    if (widget.enablePulse && !widget.reduceMotion) {
      _pulseController.repeat(reverse: true);
      _sparkController.repeat();
      Future.delayed(const Duration(milliseconds: 3000), () {
        if (mounted) _shimmerController.repeat();
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shimmerController.dispose();
    _sparkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: widget.enabled ? (_) => setState(() => _pressed = false) : null,
      onTap: widget.enabled ? widget.onTap : null,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        child: AnimatedBuilder(
          animation: Listenable.merge([_pulseController, _shimmerController]),
          builder: (context, _) {
            final pulseT = widget.enablePulse ? _pulseController.value : 0.0;
            // glowPulse: blur 18↔30, alpha .28↔.5.
            final blur = 18 + pulseT * (30 - 18);
            final alpha = _pressed
                ? 0.6
                : (0.28 + pulseT * (0.5 - 0.28));
            return Container(
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [IntroPalette.glowLight, IntroPalette.primary],
                ),
                boxShadow: [
                  BoxShadow(
                    color: IntroPalette.primary.withValues(alpha: alpha),
                    blurRadius: blur,
                    offset: _pressed ? Offset.zero : const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.55),
                    blurRadius: 0,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.icon != null) ...[
                          RotationTransition(
                            turns: _sparkController,
                            child: Text(
                              widget.icon!,
                              style: IntroTextStyles.btnPrimary(),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(widget.label, style: IntroTextStyles.btnPrimary()),
                      ],
                    ),
                    if (widget.enablePulse) _buildShimmer(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildShimmer() {
    final t = _shimmerController.value;
    final pos = -1.3 + t * 2.6; // -130% → 130%.
    return IgnorePointer(
      child: FractionalTranslation(
        translation: Offset(pos, 0),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.transparent,
                Colors.white.withValues(alpha: 0.55),
                Colors.transparent,
              ],
              stops: const [0.3, 0.5, 0.7],
            ),
          ),
        ),
      ),
    );
  }
}

/// `.btn-ghost` — 반투명 카드 배경 + 테두리 + blur, press scale(.96).
/// 앰비언트 애니메이션 없음(README 앰비언트 표에 ghost 버튼 항목 없음).
class OnboardingGhostButton extends StatefulWidget {
  const OnboardingGhostButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final String? icon;

  @override
  State<OnboardingGhostButton> createState() => _OnboardingGhostButtonState();
}

class _OnboardingGhostButtonState extends State<OnboardingGhostButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: IntroPalette.primaryLight,
            border: Border.all(color: IntroPalette.cardBorder),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Text(
                  widget.icon!,
                  style: IntroTextStyles.btnGhost(color: IntroPalette.primary),
                ),
                const SizedBox(width: 8),
              ],
              Text(widget.label, style: IntroTextStyles.btnGhost()),
            ],
          ),
        ),
      ),
    );
  }
}
