import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// [Fortune Fusion 서브 디자인 통일 마스터 프롬프트] §3 칩 규칙(v2)
///
/// 기준 시안 반영: 선택 시 네온 옐로우그린(premiumNeonLime) 채움 + 다크 텍스트,
/// 비선택 시 연회색(premiumInactiveGrey) 채움 + 보더 없음. 선택 전환 시
/// AnimatedContainer로 컬러가 부드럽게 바뀐다.
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.premiumNeonLime
              : AppColors.premiumInactiveGrey,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 15,
                color: selected
                    ? AppColors.premiumNeonLimeOnColor
                    : AppColors.premiumInactiveGreyText,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: AppTypography.smallLabel.copyWith(
                color: selected
                    ? AppColors.premiumNeonLimeOnColor
                    : AppColors.premiumInactiveGreyText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
