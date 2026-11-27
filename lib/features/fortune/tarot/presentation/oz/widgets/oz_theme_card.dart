import 'package:flutter/material.dart';
import '../../../domain/tarot_category_model.dart';
import '../oz_category_illustrations.dart';
import '../oz_theme.dart';

/// [타로 오즈 리스킨 · 화면01 HOME] "테마별로 둘러보기" 6그룹 카드.
/// CSS 대응: .oz-theme-card / .oz-theme-card-bg / .oz-theme-card-scrim /
/// .oz-theme-lock / .oz-theme-card-text / .oz-theme-card-name /
/// .oz-theme-card-count.
class OzThemeCard extends StatelessWidget {
  final TarotCategoryGroup group;
  final int count;
  final VoidCallback onTap;
  const OzThemeCard({
    super.key,
    required this.group,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final image = OzCategoryIllustrations.themeHero[group]!;
    final isSpecial = group == TarotCategoryGroup.special;
    return InkWell(
      borderRadius: BorderRadius.circular(OzTokens.radiusLg),
      onTap: onTap,
      child: Container(
        height: 140,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(OzTokens.radiusLg),
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
                    OzColors.bgMid.withValues(alpha: 0),
                    OzColors.bgMid.withValues(alpha: 0.65),
                    OzColors.bgDeep.withValues(alpha: 0.95),
                  ],
                  stops: const [0.4, 0.75, 1.0],
                ),
              ),
            ),
            if (isSpecial)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: OzColors.bgDeep.withValues(alpha: 0.6),
                    border: Border.all(color: OzColors.borderStrong),
                  ),
                  child: const Text('🔒', style: TextStyle(fontSize: 12)),
                ),
              ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    group.label,
                    style: OzTypography.sectionTitle(
                      fontSize: 15,
                      weight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$count개 카테고리',
                    style: OzTypography.monoLabel(
                      fontSize: 10,
                      letterSpacing: 1.6,
                    ),
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
