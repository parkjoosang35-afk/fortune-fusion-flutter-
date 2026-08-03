import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/luckybag_product_model.dart';

/// 03단계 §9.2 도메인특화카드 - LuckyBagCard(복주머니카드)
/// 설계원칙: 신규 원자 단위를 늘리지 않고 기존 core/widgets의 AppCard 조합으로 구성.
/// (AmuletCard와 동일한 설계원칙 적용 - 03§9.2)
/// 사용 화면: LuckyBagShopScreen(상점)
class LuckyBagCard extends StatelessWidget {
  final LuckyBagProductModel product;
  final VoidCallback? onTap;
  final Widget? trailing; // 가격/개봉버튼 등 화면별 가변 영역

  const LuckyBagCard({
    super.key,
    required this.product,
    this.onTap,
    this.trailing,
  });

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
                  color: AppColors.secondary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.cardSmall),
                ),
                child: Text(
                  product.iconEmoji,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
              const Spacer(),
              if (product.seasonName != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    product.seasonName!,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            product.name,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '${product.pricePoint}개',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.secondaryDark,
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
