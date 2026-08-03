import 'package:flutter/material.dart';
import '../../theme/app_unified_style.dart';
import '../premium_card.dart';

class LuckyGridItem {
  const LuckyGridItem({
    required this.label,
    required this.value,
    this.isLocked = false,
  });
  final String label;
  final String value;
  final bool isLocked;
}

/// 재사용 위젯 ⑤ LuckElementsGrid — 결과 화면 섹션11(오늘의 행운 요소).
///
/// 배경 #F6F5FA, radius16, padding14, 2x3 미니 카드 그리드.
/// 미니 카드: 배경 #FFFFFF, 테두리 #ECECEF 1px, radius12, padding10,
/// 라벨(Caption12) + 값(BodyStrong14). [item.isLocked]가 true면
/// 값 대신 자물쇠 아이콘("잠김")을 보여준다(§5 "행운 요소 일부").
class LuckElementsGrid extends StatelessWidget {
  const LuckElementsGrid({super.key, required this.title, required this.items});

  final String title;
  final List<LuckyGridItem> items;

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
          Text(title, style: UnifiedText.title()),
          const SizedBox(height: UnifiedTokens.spaceMd),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: UnifiedTokens.spaceSm,
            crossAxisSpacing: UnifiedTokens.spaceSm,
            childAspectRatio: 1.15,
            children: items.map((e) => _MiniCard(item: e)).toList(),
          ),
        ],
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({required this.item});
  final LuckyGridItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: UnifiedColors.bg,
        border: Border.all(color: UnifiedColors.border, width: 1),
        borderRadius: BorderRadius.circular(UnifiedTokens.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(item.label, style: UnifiedText.caption()),
          const SizedBox(height: 4),
          if (item.isLocked)
            Icon(
              Icons.lock_outline_rounded,
              size: UnifiedTokens.iconSm,
              color: UnifiedColors.textCaption,
            )
          else
            Text(
              item.value,
              style: UnifiedText.bodyStrong(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}
