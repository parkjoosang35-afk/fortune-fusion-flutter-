import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/load_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_toast.dart';
import '../application/compatibility_provider.dart';
import '../domain/compatibility_model.dart';

/// 07단계 결과형 패턴 - CompatibilityResultScreen
class CompatibilityResultScreen extends StatelessWidget {
  const CompatibilityResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CompatibilityProvider>();
    final state = provider.state;

    return Scaffold(
      appBar: AppBar(
        title: const Text('궁합 결과'),
        actions: [
          if (state.isSuccess)
            IconButton(
              icon: Icon(
                state.data!.isSaved
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                color: state.data!.isSaved ? AppColors.secondary : null,
              ),
              onPressed: () async {
                final saved = await provider.toggleSave(state.data!.id);
                if (context.mounted) {
                  AppToast.show(
                    context,
                    saved ? '보관함에 저장되었습니다.' : '보관함에서 제거되었습니다.',
                  );
                }
              },
            ),
          if (state.isSuccess)
            IconButton(
              icon: const Icon(Icons.share_outlined),
              onPressed: () async {
                final url = await provider.generateShareLink(state.data!.id);
                if (context.mounted) {
                  AppToast.show(
                    context,
                    url != null ? '공유 링크가 생성되었습니다: $url' : '공유 링크 생성에 실패했습니다.',
                    isError: url == null,
                  );
                }
              },
            ),
        ],
      ),
      body: SafeArea(
        child: switch (state.status) {
          LoadStatus.loading => const _CompatLoading(),
          LoadStatus.error => AppErrorState(
            message: state.errorMessage ?? '분석에 실패했습니다.',
            onRetry: () => provider.retry(),
          ),
          LoadStatus.success => _CompatibilityResultBody(result: state.data!),
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
                        ).pushNamed('/ai-fortune/compatibility/history'),
                        icon: const Icon(
                          Icons.bookmark_outline_rounded,
                          size: 18,
                        ),
                        label: const Text('보관함 보기'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.of(
                          context,
                        ).pushNamed('/ai-fortune/compatibility/input'),
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

class _CompatLoading extends StatelessWidget {
  const _CompatLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.mysticGradient),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_rounded, color: AppColors.secondary, size: 64),
            SizedBox(height: 24),
            Text(
              '두 사람의 인연을 분석하고 있어요...',
              style: TextStyle(color: Colors.white, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompatibilityResultBody extends StatelessWidget {
  final CompatibilityResultModel result;
  const _CompatibilityResultBody({required this.result});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            gradient: AppColors.mysticGradient,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  result.type.label,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${result.nameA} ❤ ${result.nameB}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                      value: result.score / 100,
                      strokeWidth: 8,
                      backgroundColor: Colors.white24,
                      color: AppColors.secondary,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${result.score}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Text(
                        '점',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                result.summary,
                style: const TextStyle(
                  color: AppColors.onDeepSpace,
                  fontSize: 14,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('주제별 분석', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        ...result.topicResults.entries.map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(AppRadius.cardSmall),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.key, style: Theme.of(context).textTheme.titleMedium),
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
