import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/cosmic_card.dart';

/// [Fortune Fusion UI 리뉴얼 프롬프트] §5 FortuneHubScreen - 운세 탭
/// 7개 카테고리 카드(오늘의운세/사주/타로/관상/손금/궁합/AI상담)를 세로 리스트로
/// 배치하고 각 카드에 비용 뱃지(무료/포인트)를 함께 표시한다.
///
/// [주의] 이 화면은 신규 Presentation이며, 라우팅 대상(각 기능 입력 화면)은
/// 기존 app_router.dart의 라우트를 그대로 재사용한다.
class FortuneHubScreen extends StatelessWidget {
  const FortuneHubScreen({super.key});

  static const _items = [
    (
      '오늘의 운세',
      '매일 새로운 종합운을 확인해보세요',
      Icons.wb_twilight_rounded,
      AppColors.accentBlue,
      '무료',
      '/home/daily-fortune-detail',
    ),
    (
      '사주',
      'AI가 분석하는 나의 사주 명식',
      Icons.auto_stories_rounded,
      AppColors.accentGold,
      '500P',
      '/ai-fortune/saju/input',
    ),
    (
      '타로',
      '78장의 카드가 전하는 오늘의 메시지',
      Icons.style_rounded,
      AppColors.accentPurple,
      '300P',
      '/ai-fortune/tarot/question',
    ),
    (
      '관상',
      '사진으로 보는 AI 관상 분석',
      Icons.face_retouching_natural_rounded,
      AppColors.accentPink,
      '500P',
      '/ai-fortune/face/capture',
    ),
    (
      '손금',
      '손바닥 속에 숨겨진 나의 운명',
      Icons.back_hand_rounded,
      AppColors.accentMint,
      '500P',
      '/ai-fortune/palm/capture',
    ),
    (
      '궁합',
      '두 사람의 인연과 케미를 확인해요',
      Icons.favorite_rounded,
      AppColors.accentPink,
      '500P',
      '/ai-fortune/compatibility/input',
    ),
    (
      'AI 상담',
      '실시간 AI 운세 상담사와 대화하기',
      Icons.chat_bubble_rounded,
      AppColors.accentBlue,
      '1,000P',
      '/ai-fortune/consultation/type',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        title: const Text(
          '운세',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.cosmicTextPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: _items.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, index) {
            final (title, desc, icon, color, cost, route) = _items[index];
            final isFree = cost == '무료';
            return CosmicCard(
              showGlow: false,
              onTap: () => Navigator.of(context).pushNamed(route),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.cosmicTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          desc,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.cosmicTextTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isFree
                          ? AppColors.accentMint.withValues(alpha: 0.15)
                          : AppColors.accentGold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      cost,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isFree
                            ? AppColors.accentMint
                            : AppColors.accentGold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
