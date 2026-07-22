import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../application/tarot_provider.dart';

/// 03단계 §3.3 - TarotHistoryScreen (히스토리형 패턴)
class TarotHistoryScreen extends StatefulWidget {
  const TarotHistoryScreen({super.key});

  @override
  State<TarotHistoryScreen> createState() => _TarotHistoryScreenState();
}

class _TarotHistoryScreenState extends State<TarotHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<TarotProvider>().loadHistory(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final history = context.watch<TarotProvider>().history;

    return Scaffold(
      appBar: AppBar(title: const Text('타로 히스토리')),
      body: SafeArea(
        child: history.isEmpty
            ? const AppEmptyState(
                icon: Icons.style_outlined,
                title: '아직 타로 기록이 없어요',
                description: 'AI 타로를 뽑아보세요',
              )
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: history.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) {
                  final item = history[index];
                  return InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    onTap: () => Navigator.of(
                      context,
                    ).pushNamed('/ai-fortune/tarot/result', arguments: item.id),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.style_rounded,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.question,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${item.createdAt.year}.${item.createdAt.month}.${item.createdAt.day}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.textHint,
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
