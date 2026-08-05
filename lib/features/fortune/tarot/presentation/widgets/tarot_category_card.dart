import 'package:flutter/material.dart';
import '../../domain/tarot_category_model.dart';
import '../theme/tarot_colors.dart';
import '../theme/tarot_text_styles.dart';
import '../theme/tarot_tokens.dart';

/// [타로 섹션 전면 개편 §3/§9] 65개 카테고리 전체에서 공유하는 카드 위젯.
///
/// 홈(①)의 인기/신규 섹션과 허브(②)의 그룹 그리드 양쪽에서 동일하게
/// 사용한다 - "카드 하나를 잘 만들고 데이터만 갈아끼운다"는 원칙으로
/// 65개 카테고리마다 별도 위젯을 만들지 않는다. 카테고리별 차별화는
/// [TarotCategoryMeta.accentColor]/[emoji]/[isPremium]/[isNew] 값만으로
/// 만들어진다.
class TarotCategoryCard extends StatelessWidget {
  final TarotCategoryMeta category;
  final VoidCallback onTap;
  final bool compact;

  const TarotCategoryCard({
    super.key,
    required this.category,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = category.accentColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(TarotTokens.radiusLg),
      child: Container(
        width: compact ? 148 : double.infinity,
        padding: const EdgeInsets.all(TarotTokens.spaceLg),
        decoration: BoxDecoration(
          color: TarotColors.surfaceCard,
          borderRadius: BorderRadius.circular(TarotTokens.radiusLg),
          border: Border.all(
            color: category.glowColor.withValues(alpha: 0.35),
            width: TarotTokens.cardBorderWidth,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.16),
              blurRadius: 18,
              spreadRadius: -4,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(alpha: 0.18),
                  ),
                  child: Text(
                    category.emoji,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
                const Spacer(),
                if (category.isPremium)
                  _MiniBadge(label: 'PREMIUM', color: TarotColors.starlightGold)
                else if (category.isNew)
                  _MiniBadge(label: 'NEW', color: TarotColors.pinkGlow),
              ],
            ),
            const SizedBox(height: TarotTokens.spaceMd),
            Text(
              category.label,
              style: TarotTextStyles.categoryTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              category.moodCopy,
              style: TarotTextStyles.moodCopy,
              maxLines: compact ? 2 : 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(TarotTokens.radiusPill),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TarotTextStyles.caption.copyWith(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
