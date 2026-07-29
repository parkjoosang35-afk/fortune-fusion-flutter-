import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// [Fortune Fusion UI 리뉴얼 프롬프트] §2-4 HeroFortuneCard - 홈 히어로용
///
/// 홈 화면 최상단에 노출되는 대형 히어로 카드. 우주 코스믹 그라디언트 배경 위에
/// 인사말 + 메인 카피 + CTA 버튼을 배치한다.
class HeroFortuneCard extends StatelessWidget {
  const HeroFortuneCard({
    super.key,
    this.greeting = '안녕하세요,',
    this.titleLine1 = '오늘 당신의 운명은',
    this.titleLine2 = '어떤 이야기를 들려줄까요?',
    this.ctaLabel = '오늘의 운세 보기',
    this.onCtaTap,
  });

  final String greeting;
  final String titleLine1;
  final String titleLine2;
  final String ctaLabel;
  final VoidCallback? onCtaTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 220,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: AppColors.gradientCosmic,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Stack(
        children: [
          // 상단 우측 초승달 아이콘 (은은한 오파시티)
          Positioned(
            top: 0,
            right: 0,
            child: Icon(
              Icons.nightlight_round,
              size: 96,
              color: AppColors.accentPurple.withValues(alpha: 0.3),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: AppColors.cosmicTextSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    titleLine1,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.cosmicTextPrimary,
                      height: 1.3,
                    ),
                  ),
                  Text(
                    titleLine2,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accentPurple,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: _CtaButton(label: ctaLabel, onTap: onCtaTap),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CtaButton extends StatelessWidget {
  const _CtaButton({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm + 2,
            ),
            decoration: BoxDecoration(
              gradient: AppColors.gradientGold,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.bgPrimary,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                const Icon(
                  Icons.arrow_forward,
                  size: 16,
                  color: AppColors.bgPrimary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
