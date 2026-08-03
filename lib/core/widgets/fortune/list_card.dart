import 'package:flutter/material.dart';
import '../../theme/app_unified_style.dart';
import '../premium_card.dart';
import 'lock_overlay_badge.dart';

/// 재사용 위젯 ④ ListCard — 결과 화면 섹션9(피해야 할 것)/섹션10(추천 행동)
/// 카드에서 공통 사용. 배경 #F6F5FA, radius16, padding14.
/// 각 항목: 라인 아이콘(iconSize.md16) + Body14.
class ListCard extends StatelessWidget {
  const ListCard({
    super.key,
    required this.title,
    required this.items,
    required this.icon,
    this.isLocked = false,
  });

  final String title;
  final List<String> items;
  final IconData icon;
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
            Row(
              children: [
                Icon(
                  icon,
                  size: UnifiedTokens.iconMd,
                  color: UnifiedColors.textSecondary,
                ),
                const SizedBox(width: UnifiedTokens.spaceSm),
                Expanded(
                  child: Text(
                    items.isNotEmpty ? items.first : '',
                    style: UnifiedText.body(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            )
          else
            Column(
              children: [
                for (int i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(height: UnifiedTokens.spaceSm),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        icon,
                        size: UnifiedTokens.iconMd,
                        color: UnifiedColors.textSecondary,
                      ),
                      const SizedBox(width: UnifiedTokens.spaceSm),
                      Expanded(
                        child: Text(items[i], style: UnifiedText.body()),
                      ),
                    ],
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}
