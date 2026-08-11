import 'package:flutter/material.dart';

import '../theme/wish_room_theme.dart';
import 'wish_room_animations.dart';

/// [소원방 Riverpod 실험판] 연속 기도일수 / 누적 기도횟수 배지.
///
/// [UI 전면 개선] fortune_pouch_status_card와 짝을 이루는 카드이므로 동일한
/// 보강 패턴(BreathingGlow + AnimatedCountText + 진입 FadeSlideIn)을
/// 적용해 두 카드의 시각적 리듬을 통일했다. 🔥 아이콘에는 미세한 흔들림을
/// 줘 "타오르는" 느낌을 강조한다.
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
    return FadeSlideIn(
      delay: const Duration(milliseconds: 220),
      child: BreathingGlow(
        glowColor: const Color(0xFFE8875A),
        child: Container(
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
                  const GentleWiggle(
                    period: Duration(milliseconds: 1600),
                    maxAngle: 0.15,
                    child: Text('🔥', style: TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(width: WishRoomSpacing.xs),
                  Text('연속 기도', style: WishRoomTextStyles.caption),
                ],
              ),
              const SizedBox(height: WishRoomSpacing.xs),
              AnimatedCountText(
                text: '$consecutivePrayerDays일째',
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
        ),
      ),
    );
  }
}
