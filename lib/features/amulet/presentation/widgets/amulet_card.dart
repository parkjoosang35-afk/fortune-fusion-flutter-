import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/amulet_item_model.dart';

/// 03단계 §9.2 도메인특화카드 - AmuletCard(부적카드)
/// 설계원칙: 신규 원자 단위를 늘리지 않고 기존 core/widgets의 AppCard+Badge+Icon 조합으로 구성.
/// (core/widgets는 feature-agnostic 유지 원칙 - 이 위젯은 feature 레이어에 위치)
/// 사용 화면: AmuletShopScreen(상점), MyAmuletsScreen(보유목록/도감)
class AmuletCard extends StatelessWidget {
  final AmuletItemModel item;
  final VoidCallback? onTap;
  final Widget? trailing; // 상점: 가격, 보유목록: 상태뱃지/CTA 등 화면별 가변 영역
  final bool isEquipped;

  const AmuletCard({
    super.key,
    required this.item,
    this.onTap,
    this.trailing,
    this.isEquipped = false,
  });

  Color get _gradeColor {
    switch (item.grade.code) {
      case 'legendary':
        return AppColors.secondaryDark;
      case 'heroic':
        return AppColors.primary;
      case 'rare':
        return AppColors.info;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _gradeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.cardSmall),
                ),
                child: Text(
                  item.iconEmoji,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
              const Spacer(),
              if (isEquipped)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 20,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            item.name,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _gradeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(
              item.grade.name,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _gradeColor,
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(height: AppSpacing.sm),
            trailing!,
          ],
        ],
      ),
    );
  }
}
