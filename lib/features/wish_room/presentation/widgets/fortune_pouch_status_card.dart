import 'package:flutter/material.dart';

import '../../data/models/fortune_pouch_status_model.dart';
import '../theme/wish_room_theme.dart';
import 'wish_room_animations.dart';

/// [소원방 Riverpod 실험판] 복주머니 보유/오늘 사용 현황 카드.
///
/// [UI 전면 개선] 정적 Container에 은은한 숨쉬는 글로우(BreathingGlow)를
/// 추가하고, 개수 텍스트가 바뀔 때(치성으로 복주머니가 소비/충전될 때)
/// 위로 슬라이드되며 전환되도록(AnimatedCountText) 보강했다. 진입 시에는
/// 살짝 페이드인되도록 FadeSlideIn으로 감쌌다. 내부 데이터 로직/필드는
/// 전혀 변경하지 않았다.
class FortunePouchStatusCard extends StatelessWidget {
  final FortunePouchStatus status;

  const FortunePouchStatusCard({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return FadeSlideIn(
      delay: const Duration(milliseconds: 180),
      child: BreathingGlow(
        glowColor: WishRoomColors.gold,
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
                    period: Duration(seconds: 3),
                    maxAngle: 0.08,
                    child: Text('👝', style: TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(width: WishRoomSpacing.xs),
                  Text('보유 복주머니', style: WishRoomTextStyles.caption),
                ],
              ),
              const SizedBox(height: WishRoomSpacing.xs),
              AnimatedCountText(
                text: '${status.totalCount}개',
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
        ),
      ),
    );
  }
}
