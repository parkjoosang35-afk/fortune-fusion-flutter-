import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// [Fortune Fusion 디자인 우선 리디자인 프롬프트] §6-D 배지 스타일
///
/// 복주머니=골드, 열림패스=보라/네이비, 완료=민트.
/// 작지만 명확하게, pill 형태로 통일한다.
enum PremiumBadgeType { luckyBag, pass, done }

class PremiumBadge extends StatelessWidget {
  const PremiumBadge({
    super.key,
    required this.label,
    required this.type,
    this.emoji,
  });

  final String label;
  final PremiumBadgeType type;
  final String? emoji;

  ({Color bg, Color fg}) get _colors {
    switch (type) {
      case PremiumBadgeType.luckyBag:
        return (
          bg: AppColors.premiumSoftGold.withValues(alpha: 0.22),
          fg: const Color(0xFFB07C0F),
        );
      case PremiumBadgeType.pass:
        return (
          bg: AppColors.premiumSoftLavender,
          fg: AppColors.premiumDeepNavy,
        );
      case PremiumBadgeType.done:
        return (
          bg: AppColors.premiumMintAccent.withValues(alpha: 0.35),
          fg: const Color(0xFF1B8A6B),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (emoji != null) ...[
            Text(emoji!, style: const TextStyle(fontSize: 11)),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTypography.smallLabel.copyWith(
              color: c.fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
