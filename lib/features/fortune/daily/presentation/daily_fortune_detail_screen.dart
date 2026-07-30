import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/intro_shell.dart';
import '../application/daily_fortune_provider.dart';

/// 03단계 §3.3 홈 탭 - DailyFortuneDetailScreen
/// [Phase22-2] 로딩 상태에는 SkeletonCard 대신 IntroShell(호명→소환→참여→개안)을
/// 노출하여 "오늘의 운세"를 받아오는 과정에 의례감을 부여한다.
class DailyFortuneDetailScreen extends StatefulWidget {
  const DailyFortuneDetailScreen({super.key});

  @override
  State<DailyFortuneDetailScreen> createState() =>
      _DailyFortuneDetailScreenState();
}

class _DailyFortuneDetailScreenState extends State<DailyFortuneDetailScreen> {
  String? _error;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DailyFortuneProvider>();
    final today = provider.today;

    return Scaffold(
      appBar: AppBar(title: const Text('오늘의 운세')),
      body: SafeArea(
        child: _error != null
            ? _buildError(context)
            : provider.isLoading || today == null
            ? IntroShell<void>(
                task: () => context.read<DailyFortuneProvider>().loadToday(),
                onComplete: (_) {
                  if (!mounted) return;
                  if (context.read<DailyFortuneProvider>().today == null) {
                    setState(() => _error = '운세를 불러오지 못했어요. 잠시 후 다시 시도해주세요.');
                  }
                },
                onError: (_) {
                  if (!mounted) return;
                  setState(() => _error = '운세를 불러오지 못했어요. 잠시 후 다시 시도해주세요.');
                },
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
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          today.summaryText,
                          style: const TextStyle(
                            color: AppColors.onDeepSpace,
                            fontSize: 17,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Row(
                          children: [
                            _luckyChip(
                              Icons.palette_rounded,
                              '행운의 색',
                              today.luckyColor,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            _luckyChip(
                              Icons.pin_rounded,
                              '행운의 숫자',
                              '${today.luckyNumber}',
                            ),
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

  Widget _buildError(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              _error ?? '알 수 없는 오류가 발생했어요.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: () => setState(() => _error = null),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _luckyChip(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm,
          horizontal: AppSpacing.md,
        ),
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
                  Text(
                    label,
                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
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
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadius.cardSmall),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: Theme.of(context).textTheme.titleMedium),
              Text(
                '$score점',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
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
