import 'package:flutter/material.dart';
import '../../theme/app_unified_style.dart';

class ResultActionItem {
  const ResultActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

/// 재사용 위젯 ⑥ ResultBottomActions — 결과 화면 섹션12 상단
/// 하단 CTA 4개 균등 배치(저장/공유/다른 운세/AI 상담).
/// 아이콘(iconSize.lg20) + Caption12.
class ResultBottomActions extends StatelessWidget {
  const ResultBottomActions({super.key, required this.actions});

  final List<ResultActionItem> actions;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: actions
          .map(
            (a) => Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
                onTap: a.onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: UnifiedTokens.spaceSm,
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: UnifiedTokens.iconCircleLg,
                        height: UnifiedTokens.iconCircleLg,
                        decoration: const BoxDecoration(
                          color: UnifiedColors.cardAllMenu,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          a.icon,
                          size: UnifiedTokens.iconLg,
                          color: UnifiedColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: UnifiedTokens.spaceXs),
                      Text(a.label, style: UnifiedText.caption()),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
