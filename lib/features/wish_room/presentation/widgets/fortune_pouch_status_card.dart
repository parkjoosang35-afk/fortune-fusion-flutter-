import 'package:flutter/material.dart';

import '../../data/models/fortune_pouch_status_model.dart';
import '../theme/wish_room_theme.dart';

/// [소원방 Riverpod 실험판] 복주머니 보유/오늘 사용 현황 카드.
class FortunePouchStatusCard extends StatelessWidget {
  final FortunePouchStatus status;

  const FortunePouchStatusCard({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(WishRoomSpacing.md),
      decoration: BoxDecoration(
        color: WishRoomColors.surfaceCard,
        borderRadius: BorderRadius.circular(WishRoomRadius.md),
        border: Border.all(color: WishRoomColors.surfaceCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('👝', style: TextStyle(fontSize: 18)),
              const SizedBox(width: WishRoomSpacing.xs),
              Text('보유 복주머니', style: WishRoomTextStyles.caption),
            ],
          ),
          const SizedBox(height: WishRoomSpacing.xs),
          Text(
            '${status.totalCount}개',
            style: WishRoomTextStyles.titleLg.copyWith(
              color: WishRoomColors.goldSoft,
            ),
          ),
          const SizedBox(height: WishRoomSpacing.xs),
          Text(
            status.usedToday > 0
                ? '오늘 ${status.usedToday}개로 정성을 담았어요'
                : '오늘은 아직 정성을 담지 않았어요',
            style: WishRoomTextStyles.caption,
          ),
        ],
      ),
    );
  }
}
