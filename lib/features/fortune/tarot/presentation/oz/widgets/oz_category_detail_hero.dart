import 'package:flutter/material.dart';
import '../../../domain/tarot_category_model.dart';
import '../oz_category_illustrations.dart';
import '../oz_theme.dart';

/// [타로 오즈 리스킨 · 화면03 CATEGORY DETAIL] 카테고리 히어로 배너.
/// CSS 대응: .oz-cat-detail-hero / .oz-cat-detail-hero-bg /
/// .oz-cat-detail-hero-scrim / .oz-cat-detail-hero-content /
/// .oz-cat-detail-tag / .oz-cat-detail-title / .oz-cat-detail-desc.
class OzCategoryDetailHero extends StatelessWidget {
  final TarotCategoryMeta category;
  const OzCategoryDetailHero({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final image = OzCategoryIllustrations.imageFor(category);
    return ClipRRect(
      borderRadius: BorderRadius.circular(OzTokens.radiusXl),
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          border: Border.all(color: OzColors.borderSoft),
          boxShadow: OzColors.cardElevation(),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(image, fit: BoxFit.cover),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF1A0F3D).withValues(alpha: 0.2),
                    const Color(0xFF1A0F3D).withValues(alpha: 0.65),
                    OzColors.bgDeep.withValues(alpha: 0.95),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    category.group.label.toUpperCase(),
                    style: OzTypography.monoLabel(
                      fontSize: 10,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    category.label,
                    style: OzTypography.hero(fontSize: 26, color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    category.moodCopy,
                    style: OzTypography.italicBody(fontSize: 12.5),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
