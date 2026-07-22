import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/load_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_toast.dart';
import '../application/face_provider.dart';
import '../domain/face_model.dart';

/// 07단계 결과형 패턴 - FaceResultScreen
class FaceResultScreen extends StatefulWidget {
  final String? resultId;
  const FaceResultScreen({super.key, this.resultId});

  @override
  State<FaceResultScreen> createState() => _FaceResultScreenState();
}

class _FaceResultScreenState extends State<FaceResultScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.resultId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<FaceProvider>().selectFromHistory(widget.resultId!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FaceProvider>();
    final state = provider.state;

    return Scaffold(
      appBar: AppBar(
        title: const Text('관상 결과'),
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
          LoadStatus.success => _FaceResultBody(result: state.data!),
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
                        ).pushNamed('/ai-fortune/face/history'),
                        icon: const Icon(Icons.history_rounded, size: 18),
                        label: const Text('히스토리'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.of(
                          context,
                        ).pushNamed('/ai-fortune/face/capture'),
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

class _FaceResultBody extends StatelessWidget {
  final FaceResultModel result;
  const _FaceResultBody({required this.result});

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
                '종합 관상 해석',
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
        Text('부위별 특징', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        ...result.features.entries.map(
          (e) => _FeatureTile(part: e.key, text: e.value),
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

class _FeatureTile extends StatelessWidget {
  final String part;
  final String text;
  const _FeatureTile({required this.part, required this.text});

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
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Text(
                part,
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
