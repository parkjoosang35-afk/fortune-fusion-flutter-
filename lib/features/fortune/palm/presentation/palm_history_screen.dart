import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../application/palm_provider.dart';

class PalmHistoryScreen extends StatefulWidget {
  const PalmHistoryScreen({super.key});

  @override
  State<PalmHistoryScreen> createState() => _PalmHistoryScreenState();
}

class _PalmHistoryScreenState extends State<PalmHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<PalmProvider>().loadHistory(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final history = context.watch<PalmProvider>().history;

    return Scaffold(
      appBar: AppBar(title: const Text('손금 히스토리')),
      body: SafeArea(
        child: history.isEmpty
            ? const AppEmptyState(
                icon: Icons.back_hand_outlined,
                title: '아직 분석 기록이 없어요',
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
                    ).pushNamed('/ai-fortune/palm/result', arguments: item.id),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.back_hand_rounded,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              '${item.createdAt.year}.${item.createdAt.month}.${item.createdAt.day} 손금 분석',
                              style: Theme.of(context).textTheme.titleMedium,
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
