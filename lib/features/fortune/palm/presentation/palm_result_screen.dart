import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/load_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_toast.dart';
import '../application/palm_provider.dart';
import '../domain/palm_model.dart';

class PalmResultScreen extends StatefulWidget {
  final String? resultId;
  const PalmResultScreen({super.key, this.resultId});

  @override
  State<PalmResultScreen> createState() => _PalmResultScreenState();
}

class _PalmResultScreenState extends State<PalmResultScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.resultId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<PalmProvider>().selectFromHistory(widget.resultId!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PalmProvider>();
    final state = provider.state;

    return Scaffold(
      appBar: AppBar(
        title: const Text('손금 결과'),
        actions: [
          if (state.isSuccess)
            IconButton(
              icon: const Icon(Icons.share_outlined),
              onPressed: () => AppToast.show(context, '공유 링크가 복사되었습니다.'),
            ),
        ],
      ),
      body: SafeArea(
        child: switch (state.status) {
          LoadStatus.loading => const Center(
            child: CircularProgressIndicator(),
          ),
          LoadStatus.error => AppErrorState(
            message: state.errorMessage ?? '분석에 실패했습니다.',
            onRetry: () => provider.retry(),
          ),
          LoadStatus.success => _PalmResultBody(result: state.data!),
          LoadStatus.initial => const AppErrorState(message: '입력 정보가 없습니다.'),
        },
      ),
      bottomNavigationBar: state.isSuccess
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(
                          context,
                        ).pushNamed('/ai-fortune/palm/history'),
                        icon: const Icon(Icons.history_rounded, size: 18),
                        label: const Text('히스토리'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.of(
                          context,
                        ).pushNamed('/ai-fortune/palm/capture'),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('다시 분석'),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}

class _PalmResultBody extends StatelessWidget {
  final PalmResultModel result;
  const _PalmResultBody({required this.result});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: AppColors.mysticGradient,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '종합 손금 해석',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                result.summary,
                style: const TextStyle(
                  color: AppColors.onDeepSpace,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('주요 손금선', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        ...result.lines.entries.map(
          (e) => _LineTile(name: e.key, text: e.value),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('주제별 해석', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        ...result.topicResults.entries
            .where((e) => e.key != '종합')
            .map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.cardSmall),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.key,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        e.value,
                        style: const TextStyle(fontSize: 13, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

class _LineTile extends StatelessWidget {
  final String name;
  final String text;
  const _LineTile({required this.name, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.cardSmall),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text(
                name,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontSize: 13, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
