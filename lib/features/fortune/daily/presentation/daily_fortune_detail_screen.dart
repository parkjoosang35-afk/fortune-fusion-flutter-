import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../application/daily_fortune_provider.dart';

/// 03단계 §3.3 홈 탭 - DailyFortuneDetailScreen
class DailyFortuneDetailScreen extends StatelessWidget {
  const DailyFortuneDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DailyFortuneProvider>();
    final today = provider.today;

    return Scaffold(
      appBar: AppBar(title: const Text('오늘의 운세')),
      body: SafeArea(
        child: provider.isLoading || today == null
            ? const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Column(children: [SkeletonCard(), SizedBox(height: AppSpacing.lg), SkeletonCard()]),
              )
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      gradient: AppColors.mysticGradient,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${today.date.month}월 ${today.date.day}일의 운세',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          today.summaryText,
                          style: const TextStyle(color: AppColors.onDeepSpace, fontSize: 17, height: 1.5),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Row(
                          children: [
                            _luckyChip(Icons.palette_rounded, '행운의 색', today.luckyColor),
                            const SizedBox(width: AppSpacing.md),
                            _luckyChip(Icons.pin_rounded, '행운의 숫자', '${today.luckyNumber}'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text('세부 운세', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.md),
                  ...today.categoryScores.entries.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _ScoreBar(label: e.key, score: e.value),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _luckyChip(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.cardSmall),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
                  Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  final String label;
  final int score;

  const _ScoreBar({required this.label, required this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.cardSmall)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: Theme.of(context).textTheme.titleMedium),
              Text('$score점', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 8,
              backgroundColor: AppColors.divider,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
