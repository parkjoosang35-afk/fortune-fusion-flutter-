import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../application/face_provider.dart';

class FaceHistoryScreen extends StatefulWidget {
  const FaceHistoryScreen({super.key});

  @override
  State<FaceHistoryScreen> createState() => _FaceHistoryScreenState();
}

class _FaceHistoryScreenState extends State<FaceHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<FaceProvider>().loadHistory());
  }

  @override
  Widget build(BuildContext context) {
    final history = context.watch<FaceProvider>().history;

    return Scaffold(
      appBar: AppBar(title: const Text('관상 히스토리')),
      body: SafeArea(
        child: history.isEmpty
            ? const AppEmptyState(icon: Icons.face_retouching_natural_outlined, title: '아직 분석 기록이 없어요')
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: history.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) {
                  final item = history[index];
                  return InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    onTap: () => Navigator.of(context).pushNamed('/ai-fortune/face/result', arguments: item.id),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.card)),
                      child: Row(
                        children: [
                          const Icon(Icons.face_retouching_natural_rounded, color: AppColors.primary),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              '${item.createdAt.year}.${item.createdAt.month}.${item.createdAt.day} 관상 분석',
                              style: Theme.of(context).textTheme.titleMedium,
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
