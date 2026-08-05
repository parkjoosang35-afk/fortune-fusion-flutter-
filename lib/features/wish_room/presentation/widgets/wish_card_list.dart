import 'package:flutter/material.dart';

import '../../data/models/wish_item_model.dart';
import '../theme/wish_room_theme.dart';
import 'wish_card.dart';

/// [소원방 Riverpod 실험판] 대표 소원 카드 1~3개를 가로로 나열.
/// wishes가 비어 있으면 "첫 소원을 빌어보세요" 안내 카드로 대체한다(빈 상태 UI).
class WishCardList extends StatelessWidget {
  final List<WishItem> wishes;
  final void Function(WishItem wish)? onWishTap;
  final VoidCallback? onEmptyCtaTap;

  const WishCardList({
    super.key,
    required this.wishes,
    this.onWishTap,
    this.onEmptyCtaTap,
  });

  @override
  Widget build(BuildContext context) {
    if (wishes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: WishRoomSpacing.md),
        child: GestureDetector(
          onTap: onEmptyCtaTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(WishRoomSpacing.lg),
            decoration: BoxDecoration(
              color: WishRoomColors.surfaceCard,
              borderRadius: BorderRadius.circular(WishRoomRadius.md),
              border: Border.all(
                color: WishRoomColors.surfaceCardBorder,
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              children: [
                Text('아직 이 방엔 소원이 없어요', style: WishRoomTextStyles.bodyMd),
                const SizedBox(height: WishRoomSpacing.xs),
                Text(
                  '첫 소원을 빌어, 방에 첫 빛을 밝혀보세요',
                  style: WishRoomTextStyles.caption,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final callback = onWishTap;
    return SizedBox(
      height: 152,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: WishRoomSpacing.md),
        children: wishes
            .map(
              (w) => WishCard(
                wish: w,
                onTap: callback == null ? null : () => callback(w),
              ),
            )
            .toList(),
      ),
    );
  }
}
