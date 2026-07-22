import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/consultation_provider.dart';

/// 03단계 §3.3 / 07단계 - ConsultationTypeScreen (선택형 패턴)
/// 상담 유형(사주상담/타로상담/일반상담) 선택 → 채팅 화면으로 이동
class ConsultationTypeScreen extends StatelessWidget {
  const ConsultationTypeScreen({super.key});

  static const _types = [
    ('saju', Icons.auto_stories_rounded, '사주상담', 'AI가 나의 사주를 바탕으로 대화해드려요'),
    ('tarot', Icons.style_rounded, '타로상담', '고민을 말하면 타로의 의미로 답해드려요'),
    ('general', Icons.chat_bubble_rounded, '일반상담', '무엇이든 편하게 물어보세요'),
  ];

  void _start(BuildContext context, String type) {
    context.read<ConsultationProvider>().startSession(type);
    Navigator.of(context).pushNamed('/ai-fortune/consultation/chat');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 상담')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('어떤 상담을 받아보고 싶으신가요?', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'AI 상담사와 실시간으로 대화하며 궁금한 점을 물어보세요',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.xl),
              ..._types.map((t) {
                final (type, icon, label, desc) = t;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    onTap: () => _start(context, type),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.card)),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: const BoxDecoration(color: AppColors.primaryContainer, shape: BoxShape.circle),
                            child: Icon(icon, color: AppColors.primary, size: 24),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(label, style: Theme.of(context).textTheme.titleMedium),
                                const SizedBox(height: 2),
                                Text(desc, style: Theme.of(context).textTheme.bodySmall),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
