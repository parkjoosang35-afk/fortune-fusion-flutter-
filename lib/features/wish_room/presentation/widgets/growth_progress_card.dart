import 'package:flutter/material.dart';

import '../../data/models/wish_item_model.dart';
import '../theme/wish_room_theme.dart';

/// [소원 성장 시스템] 대표 소원의 정성 누적치/성장 단계/다음 단계까지의
/// 진행률을 보여주는 카드. 메인 화면과 히스토리 화면에서 공통으로 쓴다.
///
/// 애니메이션: 진행률 바는 growthProgress 값이 바뀔 때마다 AnimatedContainer
/// 로 폭이 스무스하게 늘어난다(치성 직후 "정성이 쌓이는" 체감 포인트).
class GrowthProgressCard extends StatelessWidget {
  final WishItem wish;

  const GrowthProgressCard({super.key, required this.wish});

  @override
  Widget build(BuildContext context) {
    final stage = wish.growthStage;
    final progress = wish.growthProgress;
    final nextLabel = stage.nextThreshold == null
        ? '최고 단계에 도달했어요'
        : '다음 단계까지 ${stage.nextThreshold! - wish.growthPoint}';

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
              Text(stage.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: WishRoomSpacing.xs),
              Expanded(
                child: Text(
                  '${wish.title} · ${stage.label}',
                  style: WishRoomTextStyles.bodyMd.copyWith(
                    color: WishRoomColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: WishRoomSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(WishRoomRadius.pill),
            child: SizedBox(
              height: 8,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      const ColoredBox(color: WishRoomColors.surfaceCardBorder),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOutCubic,
                        width: constraints.maxWidth * progress,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              WishRoomColors.gold,
                              WishRoomColors.goldSoft,
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: WishRoomSpacing.xs),
          Text(nextLabel, style: WishRoomTextStyles.caption),
        ],
      ),
    );
  }
}
