import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// [Fortune Fusion 서브 디자인 통일 마스터 프롬프트] §3 버튼 규칙(v2)
///
/// Primary CTA: Deep Navy→Main Purple 그라디언트(홈 히어로 등 기존 화면 유지).
/// Black CTA: 순수 블랙 배경 + 화이트 텍스트 — 기준 시안의 메인 액션 버튼
///   ("+ 오늘의 운세보기" 등). 서브 허브 화면들의 대표 CTA로 사용.
/// Secondary CTA: 화이트 배경, 연보라 보더, 진한 회색/보라 텍스트.
enum PremiumButtonVariant { primary, black, secondary }

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

  const PremiumButton.black({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.fullWidth = true,
    this.height = 52,
  }) : variant = PremiumButtonVariant.black;

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

  bool get _isSecondary => widget.variant == PremiumButtonVariant.secondary;
  bool get _isDarkBg => !_isSecondary; // primary/black 모두 화이트 텍스트

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
            color: _isDarkBg ? Colors.white : AppColors.premiumMainPurple,
          ),
          const SizedBox(width: 8),
        ],
        Text(
          widget.label,
          style: AppTypography.bodyStrong.copyWith(
            color: _isDarkBg ? Colors.white : AppColors.premiumDeepNavy,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );

    final BoxDecoration decoration;
    switch (widget.variant) {
      case PremiumButtonVariant.primary:
        decoration = BoxDecoration(
          gradient: AppColors.premiumCtaGradient,
          borderRadius: BorderRadius.circular(widget.height / 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.premiumMainPurple.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        );
      case PremiumButtonVariant.black:
        decoration = BoxDecoration(
          color: AppColors.premiumBlackCta,
          borderRadius: BorderRadius.circular(widget.height / 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        );
      case PremiumButtonVariant.secondary:
        decoration = BoxDecoration(
          color: AppColors.premiumBgSection,
          borderRadius: BorderRadius.circular(widget.height / 2),
          border: Border.all(color: AppColors.premiumSoftLavender, width: 1.4),
        );
    }

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
