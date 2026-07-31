import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// [Fortune Fusion 디자인 우선 리디자인 프롬프트] §6-C 칩(카테고리) 스타일
///
/// 화이트/연보라 배경, 얇은 보더, 활성 상태는 진한 색 채움.
/// 선택 시 빠른 컬러 전환 애니메이션을 포함한다.
class PremiumChip extends StatelessWidget {
  const PremiumChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.premiumMainPurple
              : AppColors.premiumBgSection,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? AppColors.premiumMainPurple
                : AppColors.premiumLightBorder,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 15,
                color: selected ? Colors.white : AppColors.premiumMainPurple,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: AppTypography.smallLabel.copyWith(
                color: selected ? Colors.white : AppColors.premiumTextPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
