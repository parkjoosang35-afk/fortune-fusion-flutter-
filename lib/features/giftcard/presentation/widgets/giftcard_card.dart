import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/giftcard_model.dart';

/// 03단계 §9.2 도메인특화카드 - GiftcardCard(상품권카드)
/// LuckyBagCard/AmuletCard와 동일한 설계원칙: 신규 원자단위 없이 AppCard 조합으로 구성.
/// 사용 화면: GiftcardCatalogScreen(상품목록)
class GiftcardCard extends StatelessWidget {
  final GiftcardProductModel product;
  final VoidCallback? onTap;
  final Widget? trailing;

  const GiftcardCard({
    super.key,
    required this.product,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: product.inStock ? onTap : null,
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
                  product.imageEmoji,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: product.inStock
                      ? AppColors.primaryContainer
                      : AppColors.textHint.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  product.inStock ? '재고 ${product.stockCount}' : '품절',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: product.inStock
                        ? AppColors.primary
                        : AppColors.textHint,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            product.brand,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textHint,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
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
            '${product.requiredPoint}개',
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
