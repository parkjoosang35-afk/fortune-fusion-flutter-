import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// [Fortune Fusion 디자인 우선 리디자인 프롬프트] §6-B 버튼 스타일
///
/// Primary CTA: Deep Navy→Main Purple 그라디언트 배경, 화이트 텍스트,
///   높이 48~54, 라운드 pill, 약간의 그림자.
/// Secondary CTA: 화이트 배경, 연보라 보더, 진한 회색/보라 텍스트, 라운드 18+.
enum PremiumButtonVariant { primary, secondary }

class PremiumButton extends StatefulWidget {
  const PremiumButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = PremiumButtonVariant.primary,
    this.icon,
    this.fullWidth = true,
    this.height = 52,
  });

  const PremiumButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.fullWidth = true,
    this.height = 52,
  }) : variant = PremiumButtonVariant.secondary;

  final String label;
  final VoidCallback? onPressed;
  final PremiumButtonVariant variant;
  final IconData? icon;
  final bool fullWidth;
  final double height;

  @override
  State<PremiumButton> createState() => _PremiumButtonState();
}

class _PremiumButtonState extends State<PremiumButton> {
  bool _pressed = false;

  bool get _isPrimary => widget.variant == PremiumButtonVariant.primary;

  void _setPressed(bool value) {
    if (widget.onPressed == null) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(
            widget.icon,
            size: 18,
            color: _isPrimary ? Colors.white : AppColors.premiumMainPurple,
          ),
          const SizedBox(width: 8),
        ],
        Text(
          widget.label,
          style: AppTypography.bodyStrong.copyWith(
            color: _isPrimary ? Colors.white : AppColors.premiumDeepNavy,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );

    final decoration = _isPrimary
        ? BoxDecoration(
            gradient: AppColors.premiumCtaGradient,
            borderRadius: BorderRadius.circular(widget.height / 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.premiumMainPurple.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          )
        : BoxDecoration(
            color: AppColors.premiumBgSection,
            borderRadius: BorderRadius.circular(widget.height / 2),
            border: Border.all(
              color: AppColors.premiumSoftLavender,
              width: 1.4,
            ),
          );

    final button = AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: AnimatedOpacity(
        opacity: widget.onPressed == null ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          height: widget.height,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: decoration,
          alignment: Alignment.center,
          child: content,
        ),
      ),
    );

    final tappable = GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onPressed,
      child: button,
    );

    return widget.fullWidth
        ? SizedBox(width: double.infinity, child: tappable)
        : tappable;
  }
}
