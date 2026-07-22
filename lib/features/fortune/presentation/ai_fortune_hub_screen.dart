import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// 03단계 §3.3 AI운세 탭 - AiFortuneHubScreen
/// 6개 AI 기능(사주/타로/관상/손금/궁합/AI상담)으로 진입하는 허브 그리드
class AiFortuneHubScreen extends StatelessWidget {
  const AiFortuneHubScreen({super.key});

  static const _items = [
    (
      Icons.auto_stories_rounded,
      '사주',
      'AI가 분석하는 나의 사주 명식',
      '/ai-fortune/saju/input',
    ),
    (
      Icons.style_rounded,
      '타로',
      '오늘의 질문에 대한 타로 리딩',
      '/ai-fortune/tarot/question',
    ),
    (
      Icons.face_retouching_natural_rounded,
      '관상',
      '사진으로 보는 AI 관상 분석',
      '/ai-fortune/face/capture',
    ),
    (
      Icons.back_hand_rounded,
      '손금',
      '손금으로 알아보는 나의 운명',
      '/ai-fortune/palm/capture',
    ),
    (
      Icons.favorite_rounded,
      '궁합',
      '두 사람의 인연을 분석해요',
      '/ai-fortune/compatibility/input',
    ),
    (
      Icons.chat_bubble_rounded,
      'AI상담',
      '실시간 AI 운세 상담',
      '/ai-fortune/consultation/type',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 운세')),
      body: SafeArea(
        child: GridView.builder(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: _items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: AppSpacing.lg,
            crossAxisSpacing: AppSpacing.lg,
            childAspectRatio: 1.1,
          ),
          itemBuilder: (context, index) {
            final (icon, label, desc, route) = _items[index];
            return InkWell(
              borderRadius: BorderRadius.circular(AppRadius.card),
              onTap: () => Navigator.of(context).pushNamed(route),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: const BoxDecoration(
                        color: AppColors.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: AppColors.primary, size: 24),
                    ),
                    const Spacer(),
                    Text(label, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      desc,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
