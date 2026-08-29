import 'package:flutter/material.dart';
import '../../../domain/tarot_category_model.dart';
import '../oz_category_illustrations.dart';
import '../oz_theme.dart';

/// [타로 오즈 리스킨 · 화면01 HOME] 인기/신규 카테고리 카드.
/// CSS 대응: .oz-cat-card / .oz-cat-illust / .oz-cat-name / .oz-cat-desc /
/// .oz-cat-newbadge.
///
/// 4열 그리드(또는 가로 스크롤)에 쓰이는 컴팩트 카드. 전용 일러스트가
/// 있으면 그 이미지를, 없으면 그룹 테마 이미지로 폴백한다
/// ([OzCategoryIllustrations.imageFor]).
class OzCategoryCard extends StatelessWidget {
  final TarotCategoryMeta category;
  final VoidCallback onTap;
  const OzCategoryCard({
    super.key,
    required this.category,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final image = OzCategoryIllustrations.imageFor(category);
    return InkWell(
      borderRadius: BorderRadius.circular(OzTokens.radiusMd),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 10, 6, 12),
        decoration: BoxDecoration(
          color: OzColors.card,
          borderRadius: BorderRadius.circular(OzTokens.radiusMd),
          border: Border.all(color: OzColors.borderSoft),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(OzTokens.radiusSm),
                  child: Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      border: Border.all(color: OzColors.borderStrong),
                    ),
                    child: Image.asset(image, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  category.label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OzTypography.cardName(fontSize: 11.5),
                ),
                const SizedBox(height: 3),
                Text(
                  category.moodCopy,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: OzTypography.body(
                    fontSize: 9.5,
                    color: OzColors.faint,
                  ),
                ),
              ],
            ),
            if (category.isNew)
              Positioned(
                top: -4,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    gradient: OzColors.roseGradient,
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                        color: OzColors.roseDeep.withValues(alpha: 0.4),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    'NEW',
                    style: OzTypography.monoLabel(
                      fontSize: 7.5,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
