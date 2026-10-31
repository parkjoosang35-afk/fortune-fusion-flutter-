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
    // [반응형 화면 규격 통일 지시서] 라벨 Text가 Flexible/Expanded 없이
    // Row(mainAxisSize: min)에 놓여 있어, 버튼은 fullWidth로 전체 폭을
    // 차지해도 내부 Row는 "자신의 콘텐츠 고유 크기"로 레이아웃된다 —
    // 즉 버튼이 넓어도 Row 자체는 그 폭 제약을 자동으로 물려받지 않아,
    // 긴 라벨 + 좁은 화면 + 큰 텍스트스케일(예: 320x568@1.5 이상) 조합에서
    // RenderFlex 오버플로가 발생했다(free_pass_gate_screen.dart의 "지금
    // 프리패스 열어보기" 버튼에서 실측). 공용 위젯이라 여러 화면이 함께
    // 쓰므로, Flexible + ellipsis로 감싸 공간이 부족할 때만 말줄임표로
    // 축약되게 한다 — 라벨이 짧아 한 줄에 들어가는 기존 모든 버튼의
    // 모양/정렬/색상은 전혀 달라지지 않는다.
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
        Flexible(
          child: Text(
            widget.label,
            style: AppTypography.bodyStrong.copyWith(
              color: _isDarkBg ? Colors.white : AppColors.premiumDeepNavy,
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            textAlign: TextAlign.center,
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
