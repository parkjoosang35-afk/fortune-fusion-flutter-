import 'package:flutter/material.dart';
import '../../../domain/tarot_category_model.dart';
import '../oz_category_illustrations.dart';
import '../oz_theme.dart';

/// [타로 오즈 리스킨 · 화면02 THEME LIST] 그룹 히어로 배너.
/// CSS 대응: .oz-theme-hero / .oz-theme-hero-bg / .oz-theme-hero-scrim /
/// .oz-theme-hero-content / .oz-theme-hero-icon / .oz-theme-hero-name /
/// .oz-theme-hero-subtitle / .oz-theme-hero-count.
class OzThemeHero extends StatelessWidget {
  final TarotCategoryGroup group;
  final int count;
  const OzThemeHero({super.key, required this.group, required this.count});

  @override
  Widget build(BuildContext context) {
    final image = OzCategoryIllustrations.themeHero[group]!;
    final icon = OzCategoryIllustrations.groupIcon[group]!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        OzTokens.spaceLg,
        OzTokens.spaceMd,
        OzTokens.spaceLg,
        OzTokens.spaceLg,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(OzTokens.radiusXl),
        child: Container(
          height: 180,
          decoration: BoxDecoration(
            border: Border.all(color: OzColors.borderStrong),
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
                      OzColors.bgMid.withValues(alpha: 0.35),
                      OzColors.bgMid.withValues(alpha: 0.55),
                      OzColors.bgDeep.withValues(alpha: 0.92),
                    ],
                    stops: const [0.0, 0.5, 1.0],
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
                    Text(icon, style: const TextStyle(fontSize: 24)),
                    const SizedBox(height: 4),
                    Text(
                      group.label,
                      style: OzTypography.hero(
                        fontSize: 24,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      group.moodCopy,
                      style: OzTypography.body(
                        fontSize: 12.5,
                        color: OzColors.fg.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$count개 카테고리',
                      style: OzTypography.monoLabel(
                        fontSize: 10,
                        letterSpacing: 3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
