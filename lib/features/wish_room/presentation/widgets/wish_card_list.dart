import 'package:flutter/material.dart';

import '../../data/models/wish_item_model.dart';
import '../theme/wish_room_theme.dart';
import 'wish_card.dart';
import 'wish_room_animations.dart';

/// [소원방 Riverpod 실험판] 대표 소원 카드 1~3개를 가로로 나열.
/// wishes가 비어 있으면 "첫 소원을 빌어보세요" 안내 카드로 대체한다(빈 상태 UI).
///
/// [UI 전면 개선] 각 카드가 순차적으로(staggered) 페이드+슬라이드 등장하도록
/// FadeSlideIn을 카드별로 다른 delay로 적용했다. 빈 상태 안내 카드에도
/// 탭 피드백(TapBounce)과 은은한 글로우를 추가해 "여기를 눌러보세요"라는
/// 유도감을 강화했다.
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
        child: FadeSlideIn(
          child: BreathingGlow(
            glowColor: WishRoomColors.goldSoft,
            minAlpha: 0.04,
            maxAlpha: 0.16,
            child: TapBounce(
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
                    const GentleWiggle(
                      child: Text('🕯️', style: TextStyle(fontSize: 28)),
                    ),
                    const SizedBox(height: WishRoomSpacing.sm),
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
        children: [
          for (var i = 0; i < wishes.length; i++)
            FadeSlideIn(
              key: ValueKey('wish_card_entry_${wishes[i].id}'),
              delay: Duration(milliseconds: 80 * i),
              offsetY: 10,
              child: WishCard(
                wish: wishes[i],
                onTap: callback == null ? null : () => callback(wishes[i]),
              ),
            ),
        ],
      ),
    );
  }
}
