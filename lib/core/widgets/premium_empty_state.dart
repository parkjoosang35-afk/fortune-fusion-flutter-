import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'premium_card.dart';
import 'premium_graphics.dart';

/// [Fortune Fusion 서브 디자인 통일 마스터 프롬프트] §3 빈 상태(empty state) 규칙
///
/// 절대 텅 빈 흰 화면으로 두지 않는다 — 연라벤더 카드 + 작은 그래픽 행복머니
/// (반달/별빛) + 짧은 감성 카피 + (선택) CTA로 항상 "디자인이 완성된" 느낌을 준다.
class PremiumEmptyState extends StatelessWidget {
  const PremiumEmptyState({
    super.key,
    required this.emoji,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String emoji;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      backgroundColor: AppColors.premiumBgSubtle,
      borderColor: AppColors.premiumCardBorder,
      showShadow: false,
      child: Column(
        children: [
          SizedBox(
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Positioned(top: 0, right: 40, child: SparkleDot(size: 10)),
                const Positioned(bottom: 4, left: 36, child: SparkleDot(size: 7)),
                const FloatingMoon(size: 30),
                Positioned(
                  bottom: 0,
                  child: Text(emoji, style: const TextStyle(fontSize: 26)),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.cardTitle.copyWith(fontSize: 15),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: AppTypography.caption,
            ),
          ],
          if (actionLabel != null) ...[
            const SizedBox(height: AppSpacing.md),
            GestureDetector(
              onTap: onAction,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.premiumNeonLime,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  actionLabel!,
                  style: AppTypography.smallLabel.copyWith(
                    color: AppColors.premiumNeonLimeOnColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
