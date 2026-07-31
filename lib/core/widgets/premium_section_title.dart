import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// [Fortune Fusion 서브 디자인 통일 마스터 프롬프트] §3 섹션 타이틀 규칙
///
/// 짧고 명확한 좌측 정렬 타이틀. 필요 시 우측에 "전체보기"류 텍스트 액션을
/// 붙일 수 있다.
class PremiumSectionTitle extends StatelessWidget {
  const PremiumSectionTitle({
    super.key,
    required this.title,
    this.actionLabel,
    this.onActionTap,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: AppTypography.sectionTitle),
        ),
        if (actionLabel != null)
          GestureDetector(
            onTap: onActionTap,
            child: Text(
              actionLabel!,
              style: AppTypography.caption.copyWith(
                color: AppColors.premiumTextSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}
