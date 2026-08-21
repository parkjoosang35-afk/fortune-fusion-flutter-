import 'package:flutter/material.dart';
import '../../../domain/tarot_category_model.dart';
import '../oz_theme.dart';

/// [타로 오즈 리스킨 · 화면02 THEME LIST] 서브 카테고리 세로 리스트 행.
/// CSS 대응: .oz-sublist-row / .oz-sublist-num / .oz-sublist-icon /
/// .oz-sublist-body / .oz-sublist-name / .oz-sublist-lock /
/// .oz-sublist-desc / .oz-sublist-chevron.
class OzSublistRow extends StatelessWidget {
  final int index;
  final TarotCategoryMeta category;
  final VoidCallback onTap;
  const OzSublistRow({
    super.key,
    required this.index,
    required this.category,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(OzTokens.radiusMd),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: OzColors.cardSoft,
          borderRadius: BorderRadius.circular(OzTokens.radiusMd),
          border: Border.all(color: OzColors.borderSoft),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: Text(
                index.toString().padLeft(2, '0'),
                textAlign: TextAlign.center,
                style: OzTypography.monoLabel(
                  fontSize: 10,
                  color: OzColors.gold.withValues(alpha: 0.55),
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0x14F5D98A),
                borderRadius: BorderRadius.circular(OzTokens.radiusSm),
                border: Border.all(color: const Color(0x29F5D98A)),
              ),
              child: Text(category.emoji, style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          category.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: OzTypography.cardName(fontSize: 14),
                        ),
                      ),
                      if (category.isPremium) ...[
                        const SizedBox(width: 6),
                        const Text('🔒', style: TextStyle(fontSize: 11)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    category.moodCopy,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: OzTypography.body(fontSize: 11.5, color: OzColors.faint),
                  ),
                ],
              ),
            ),
            Text(
              '›',
              style: OzTypography.monoLabel(
                fontSize: 18,
                color: OzColors.fg.withValues(alpha: 0.4),
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
