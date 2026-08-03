import 'package:flutter/material.dart';
import '../theme/app_unified_style.dart';
import 'premium_card.dart';

/// [Fortune Fusion 서브 디자인 통일 마스터 프롬프트] §3 빈 상태(empty state) 규칙
///
/// 절대 텅 빈 흰 화면으로 두지 않는다 — 연라벤더 카드 + 작은 그래픽 복주머니
/// (반달/별빛) + 짧은 감성 카피 + (선택) CTA로 항상 "디자인이 완성된" 느낌을 준다.
class PremiumEmptyState extends StatelessWidget {
  const PremiumEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      backgroundColor: UnifiedColors.cardSection,
      borderColor: Colors.transparent,
      showShadow: false,
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
      child: Column(
        children: [
          Container(
            width: UnifiedTokens.iconCircleLg,
            height: UnifiedTokens.iconCircleLg,
            decoration: BoxDecoration(
              color: UnifiedColors.bg,
              borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
            ),
            child: Icon(
              icon,
              size: UnifiedTokens.iconLg,
              color: UnifiedColors.textSecondary,
            ),
          ),
          const SizedBox(height: UnifiedTokens.spaceMd),
          Text(
            title,
            textAlign: TextAlign.center,
            style: UnifiedText.bodyStrong(),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: UnifiedText.caption(),
            ),
          ],
          if (actionLabel != null) ...[
            const SizedBox(height: UnifiedTokens.spaceMd),
            GestureDetector(
              onTap: onAction,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: UnifiedColors.neon,
                  borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
                ),
                child: Text(
                  actionLabel!,
                  style: UnifiedText.chipLabel(color: UnifiedColors.black),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
