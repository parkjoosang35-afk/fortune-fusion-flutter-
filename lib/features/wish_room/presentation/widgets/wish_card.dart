import 'package:flutter/material.dart';

import '../../data/models/wish_item_model.dart';
import '../theme/wish_room_theme.dart';
import 'wish_room_animations.dart';

/// [소원방 Riverpod 실험판] 대표 소원 카드(가로 리스트에 쓰이는 낱장 카드).
///
/// [UI 전면 개선] 탭 시 살짝 눌리는 스케일 피드백(TapBounce)을 추가하고,
/// 대표 소원 배지에는 은은한 펄스 글로우를 줘 "지금 가장 중요한 소원"임을
/// 시각적으로 강조했다. 카드 내부 정보 구조/로직은 변경하지 않았다.
class WishCard extends StatelessWidget {
  final WishItem wish;
  final VoidCallback? onTap;

  const WishCard({super.key, required this.wish, this.onTap});

  String get _statusLabel {
    final lastPrayedAt = wish.lastPrayedAt;
    if (lastPrayedAt == null) return '아직 기도 전이에요';
    final diff = DateTime.now().difference(lastPrayedAt);
    if (diff.inHours < 24) return '오늘 기도했어요';
    return '${diff.inDays}일 전 기도했어요';
  }

  @override
  Widget build(BuildContext context) {
    return TapBounce(
      onTap: onTap,
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(WishRoomSpacing.md),
        margin: const EdgeInsets.only(right: WishRoomSpacing.sm),
        decoration: BoxDecoration(
          color: WishRoomColors.surfaceCard,
          borderRadius: BorderRadius.circular(WishRoomRadius.md),
          border: Border.all(
            color: wish.isRepresentative
                ? WishRoomColors.gold.withValues(alpha: 0.6)
                : WishRoomColors.surfaceCardBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(wish.category.emoji, style: const TextStyle(fontSize: 22)),
                const Spacer(),
                // [슬롯 시스템] 대표 소원만 골드 배지로 구분 표시 — 서브 소원
                // 카드를 탭하면 대표로 승격할 수 있다는 것을 암시한다.
                if (wish.isRepresentative)
                  BreathingGlow(
                    glowColor: WishRoomColors.gold,
                    borderRadius: WishRoomRadius.pill,
                    minAlpha: 0.1,
                    maxAlpha: 0.35,
                    blurRadius: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: WishRoomColors.gold.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(
                          WishRoomRadius.pill,
                        ),
                        border: Border.all(color: WishRoomColors.gold),
                      ),
                      child: Text(
                        '대표',
                        style: WishRoomTextStyles.caption.copyWith(
                          color: WishRoomColors.gold,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: WishRoomSpacing.sm),
            Text(
              wish.title,
              style: WishRoomTextStyles.bodyMd.copyWith(
                color: WishRoomColors.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: WishRoomSpacing.sm),
            Text(_statusLabel, style: WishRoomTextStyles.caption),
          ],
        ),
      ),
    );
  }
}
