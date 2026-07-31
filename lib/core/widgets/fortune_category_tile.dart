import 'package:flutter/material.dart';
import '../theme/app_unified_style.dart';
import 'premium_card.dart';

/// [서브 디자인 통일 확산 프롬프트] §2 운세 탭 대표 카테고리 강조 카드 표준.
///
/// 사주/궁합/타로/관상/손금/테마운세 등 모든 운세 카테고리 진입 화면이
/// UI를 다시 만들지 않고 아이콘/라벨/잠금 상태 데이터만 넘겨 재사용하는
/// 표준 카드. 하위 카테고리(서브 항목)는 이 위젯이 아니라 기존 `PremiumChip`을
/// 그대로 재사용한다(§2 "하위카테고리는 칩/미니카드").
///
/// 스펙: 대표카테고리카드 배경 #F0EEFB/#F3F1F9, radius14~16, padding12~14,
/// 그림자 금지, 아이콘 라인스타일 통일(iconSize.lg=20 기본).
class FortuneCategoryTile extends StatelessWidget {
  const FortuneCategoryTile({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    this.locked = false,
    required this.onTap,
    this.backgroundColor,
    this.iconColor,
    this.height,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final bool locked;
  final VoidCallback onTap;
  final Color? backgroundColor;
  final Color? iconColor;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: PremiumCard(
        backgroundColor: backgroundColor ?? UnifiedColors.cardAllMenu,
        borderColor: Colors.transparent,
        showShadow: false,
        borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
        padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: UnifiedTokens.iconCircleLg,
                  height: UnifiedTokens.iconCircleLg,
                  decoration: const BoxDecoration(
                    color: UnifiedColors.bg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: UnifiedTokens.iconLg,
                    color: iconColor ?? UnifiedColors.textPrimary,
                  ),
                ),
                const Spacer(),
                if (locked)
                  Icon(
                    Icons.lock_outline_rounded,
                    size: UnifiedTokens.iconMd,
                    color: UnifiedColors.textCaption,
                  ),
              ],
            ),
            const SizedBox(height: UnifiedTokens.spaceSm),
            Text(label, style: UnifiedText.bodyStrong()),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: UnifiedText.caption(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
