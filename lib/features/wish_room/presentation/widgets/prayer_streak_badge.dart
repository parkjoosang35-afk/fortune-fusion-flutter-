import 'package:flutter/material.dart';

import '../theme/wish_room_theme.dart';

/// [소원방 Riverpod 실험판] 연속 기도일수 / 누적 기도횟수 배지.
class PrayerStreakBadge extends StatelessWidget {
  final int consecutivePrayerDays;
  final int totalPrayerCount;

  const PrayerStreakBadge({
    super.key,
    required this.consecutivePrayerDays,
    required this.totalPrayerCount,
  });

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
              const Text('🔥', style: TextStyle(fontSize: 18)),
              const SizedBox(width: WishRoomSpacing.xs),
              Text('연속 기도', style: WishRoomTextStyles.caption),
            ],
          ),
          const SizedBox(height: WishRoomSpacing.xs),
          Text(
            '$consecutivePrayerDays일째',
            style: WishRoomTextStyles.titleLg.copyWith(
              color: WishRoomColors.goldSoft,
            ),
          ),
          const SizedBox(height: WishRoomSpacing.xs),
          Text(
            '누적 $totalPrayerCount회 기도했어요',
            style: WishRoomTextStyles.caption,
          ),
        ],
      ),
    );
  }
}
