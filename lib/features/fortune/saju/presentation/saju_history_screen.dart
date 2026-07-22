import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../application/saju_provider.dart';

/// 03단계 §3.3 - SajuHistoryScreen (히스토리형 패턴)
class SajuHistoryScreen extends StatefulWidget {
  const SajuHistoryScreen({super.key});

  @override
  State<SajuHistoryScreen> createState() => _SajuHistoryScreenState();
}

class _SajuHistoryScreenState extends State<SajuHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<SajuProvider>().loadHistory());
  }

  @override
  Widget build(BuildContext context) {
    final history = context.watch<SajuProvider>().history;

    return Scaffold(
      appBar: AppBar(title: const Text('사주 히스토리')),
      body: SafeArea(
        child: history.isEmpty
            ? const AppEmptyState(icon: Icons.auto_stories_outlined, title: '아직 분석 기록이 없어요', description: 'AI 사주를 분석해보세요')
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: history.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) {
                  final item = history[index];
                  return InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    onTap: () => Navigator.of(context).pushNamed('/ai-fortune/saju/result', arguments: item.id),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.card)),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_stories_rounded, color: AppColors.primary),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${item.pillars.year} ${item.pillars.month} ${item.pillars.day}',
                                    style: Theme.of(context).textTheme.titleMedium),
                                Text(
                                  '${item.createdAt.year}.${item.createdAt.month}.${item.createdAt.day}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
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
