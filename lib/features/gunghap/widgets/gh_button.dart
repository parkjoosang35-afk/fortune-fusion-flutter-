// ═══════════════════════════════════════════════════════════════
// FILE: gh_button.dart
// [궁합지도 Star Map 디자인 적용] `flutter_starter/.../gh_button.dart`
// 포팅본(거의 그대로, withOpacity → withValues 로 flutter analyze
// 경고 방지).
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import '../theme/gh_tokens.dart';
import '../theme/gh_typography.dart';

enum GHButtonVariant { primary, secondary, ghost, violet, kakao, text }

enum GHButtonSizeT { xl, lg, md, sm }

class GHButton extends StatefulWidget {
  const GHButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = GHButtonVariant.primary,
    this.size = GHButtonSizeT.lg,
    this.leading,
    this.trailing,
    this.expand = true,
  });
  final String label;
  final VoidCallback? onPressed; // null = disabled
  final GHButtonVariant variant;
  final GHButtonSizeT size;
  final Widget? leading, trailing;
  final bool expand;
  @override
  State<GHButton> createState() => _GHButtonState();
}

class _GHButtonState extends State<GHButton> {
  bool _down = false;
  double get _h => switch (widget.size) {
    GHButtonSizeT.xl => GHButtonSize.xl,
    GHButtonSizeT.lg => GHButtonSize.lg,
    GHButtonSizeT.md => GHButtonSize.md,
    GHButtonSizeT.sm => GHButtonSize.sm,
  };
  double get _fs => switch (widget.size) {
    GHButtonSizeT.xl => 17,
    GHButtonSizeT.sm => 13,
    _ => 15.5,
  };

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null;
    BoxDecoration deco;
    Color fg;
    if (disabled) {
      deco = BoxDecoration(
        color: GHColors.gray.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(GHRadius.button),
        border: Border.all(color: GHColors.lineSoft),
      );
      fg = GHColors.gray.withValues(alpha: .5);
    } else {
      switch (widget.variant) {
        case GHButtonVariant.primary:
          deco = BoxDecoration(
            gradient: ghGoldGradient,
            borderRadius: BorderRadius.circular(GHRadius.button),
            boxShadow: widget.size == GHButtonSizeT.xl
                ? GHShadow.xl
                : GHShadow.primary,
            border: widget.size == GHButtonSizeT.xl
                ? Border.all(color: const Color(0x40FFECBE))
                : null,
          );
          fg = GHColors.ink;
        case GHButtonVariant.secondary:
          deco = BoxDecoration(
            color: GHColors.card,
            borderRadius: BorderRadius.circular(GHRadius.button),
            border: Border.all(color: GHColors.divider),
          );
          fg = GHColors.ivory;
        case GHButtonVariant.ghost:
          deco = BoxDecoration(
            borderRadius: BorderRadius.circular(GHRadius.button),
            border: Border.all(color: GHColors.lineSoft),
          );
          fg = GHColors.gray;
        case GHButtonVariant.violet:
          deco = BoxDecoration(
            color: GHColors.violet.withValues(alpha: .16),
            borderRadius: BorderRadius.circular(GHRadius.button),
            border: Border.all(color: GHColors.violet.withValues(alpha: .45)),
          );
          fg = GHColors.violetTextLight;
        case GHButtonVariant.kakao:
          deco = BoxDecoration(
            color: GHColors.kakao,
            borderRadius: BorderRadius.circular(GHRadius.button),
          );
          fg = GHColors.kakaoText;
        case GHButtonVariant.text:
          deco = const BoxDecoration();
          fg = GHColors.gray;
      }
    }
    final h = widget.variant == GHButtonVariant.text ? 40.0 : _h;
    return Semantics(
      button: true,
      enabled: !disabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: disabled ? null : (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _down ? .96 : 1,
          duration: GHMotion.press,
          child: Container(
            constraints: BoxConstraints(minHeight: h),
            width: widget.expand ? double.infinity : null,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: deco,
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.leading != null) ...[
                  IconTheme(
                    data: IconThemeData(color: fg, size: 16),
                    child: widget.leading!,
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: GHText.button(size: _fs, color: fg),
                  ),
                ),
                if (widget.trailing != null) ...[
                  const SizedBox(width: 6),
                  widget.trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Price pill used inside "상세 궁합 보고서 확인하기 [❖ N]"
class GHPricePill extends StatelessWidget {
  const GHPricePill(this.required, {super.key});
  final int required;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: GHColors.ink.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      '❖ $required',
      style: GHText.ui(size: 12, weight: FontWeight.w700, color: GHColors.ink),
    ),
  );
}
