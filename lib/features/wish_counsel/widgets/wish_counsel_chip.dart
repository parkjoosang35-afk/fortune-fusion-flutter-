import 'package:flutter/material.dart';

import '../theme/wish_counsel_colors.dart';
import '../theme/wish_counsel_text_styles.dart';

/// 범용 Chip — `04_DESIGN_TOKENS.md` §5-4.
class WishCounselChip extends StatelessWidget {
  const WishCounselChip({
    super.key,
    required this.label,
    this.active = false,
    this.glyph,
    this.activeColor = WishCounselColors.card,
    this.activeGlow,
    this.onTap,
  });

  final String label;
  final bool active;
  final String? glyph;
  final Color activeColor;
  final Color? activeGlow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final glow = activeGlow ?? WishCounselColors.fg;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: active ? activeColor : WishCounselColors.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? glow : WishCounselColors.line,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (glyph != null) ...[
              Text(
                glyph!,
                style: TextStyle(fontSize: 13, color: active ? glow : WishCounselColors.fg2),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: WishCounselText.caption(
                color: active ? glow : WishCounselColors.fg2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
