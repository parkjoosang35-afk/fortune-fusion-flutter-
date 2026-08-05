import 'package:flutter/material.dart';

import '../../data/models/wish_item_model.dart';
import '../theme/wish_room_theme.dart';

/// [소원방 Riverpod 실험판] 소원 작성 화면의 추천 카테고리 칩 그룹.
class CategoryChipGroup extends StatelessWidget {
  final WishCategory? selected;
  final ValueChanged<WishCategory> onSelected;

  const CategoryChipGroup({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  static const _recommended = [
    WishCategory.health,
    WishCategory.wealth,
    WishCategory.exam,
    WishCategory.love,
    WishCategory.family,
    WishCategory.achievement,
    WishCategory.healing,
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: WishRoomSpacing.sm,
      runSpacing: WishRoomSpacing.sm,
      children: _recommended.map((category) {
        final isSelected = category == selected;
        return GestureDetector(
          onTap: () => onSelected(category),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(
              horizontal: WishRoomSpacing.md,
              vertical: WishRoomSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? WishRoomColors.gold.withValues(alpha: 0.85)
                  : WishRoomColors.surfaceCard,
              borderRadius: BorderRadius.circular(WishRoomRadius.pill),
              border: Border.all(
                color: isSelected
                    ? WishRoomColors.gold
                    : WishRoomColors.surfaceCardBorder,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(category.emoji, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: WishRoomSpacing.xs),
                Text(
                  category.label,
                  style: WishRoomTextStyles.bodySm.copyWith(
                    color: isSelected
                        ? WishRoomColors.backgroundDeep
                        : WishRoomColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
