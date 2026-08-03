import 'package:flutter/material.dart';
import '../../theme/app_unified_style.dart';
import '../premium_card.dart';
import 'lock_overlay_badge.dart';

class TimelineCardSlot {
  const TimelineCardSlot({required this.label, required this.body});
  final String label;
  final String body;
}

/// 재사용 위젯 ③ TimelineCard — 결과 화면 섹션3(시간대별 흐름 카드).
///
/// 배경 #F6F5FA, radius16, padding14. 제목 + 4구간(오전/오후/저녁/밤),
/// 구간 라벨 Caption12, 구간 본문 BodySmall13.
class TimelineCard extends StatelessWidget {
  const TimelineCard({
    super.key,
    required this.title,
    required this.slots,
    this.isLocked = false,
  });

  final String title;
  final List<TimelineCardSlot> slots;
  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      backgroundColor: UnifiedColors.cardSection,
      borderColor: Colors.transparent,
      showShadow: false,
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
      padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isLocked) ...[
            const LockOverlayBadge.badge(),
            const SizedBox(height: UnifiedTokens.spaceSm),
          ],
          Text(title, style: UnifiedText.title()),
          const SizedBox(height: UnifiedTokens.spaceSm),
          if (isLocked)
            Text(
              slots.isNotEmpty ? slots.first.body : '',
              style: UnifiedText.bodySmall(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          else
            Column(
              children: [
                for (int i = 0; i < slots.length; i++) ...[
                  if (i > 0) const SizedBox(height: UnifiedTokens.spaceSm),
                  _SlotRow(slot: slots[i]),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({required this.slot});
  final TimelineCardSlot slot;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 32,
          child: Text(slot.label, style: UnifiedText.caption()),
        ),
        const SizedBox(width: UnifiedTokens.spaceSm),
        Expanded(child: Text(slot.body, style: UnifiedText.bodySmall())),
      ],
    );
  }
}
