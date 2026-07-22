import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/load_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_toast.dart';
import '../application/tarot_provider.dart';
import '../domain/tarot_model.dart';

/// 07단계 결과형 패턴 - TarotResultScreen
/// AppBar(공유아이콘) + 질문 + 카드(들) + 포지션별 해석 + ActionBar
class TarotResultScreen extends StatefulWidget {
  final String? resultId;
  const TarotResultScreen({super.key, this.resultId});

  @override
  State<TarotResultScreen> createState() => _TarotResultScreenState();
}

class _TarotResultScreenState extends State<TarotResultScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.resultId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<TarotProvider>().selectFromHistory(widget.resultId!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TarotProvider>();
    final state = provider.state;

    return Scaffold(
      appBar: AppBar(
        title: const Text('타로 결과'),
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
            message: state.errorMessage ?? '타로 리딩에 실패했습니다.',
            onRetry: () => provider.retry(),
          ),
          LoadStatus.success => _TarotResultBody(result: state.data!),
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
                        ).pushNamed('/ai-fortune/tarot/history'),
                        icon: const Icon(Icons.history_rounded, size: 18),
                        label: const Text('히스토리'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.of(
                          context,
                        ).pushNamed('/ai-fortune/tarot/question'),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('다시 뽑기'),
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

class _TarotResultBody extends StatelessWidget {
  final TarotResultModel result;
  const _TarotResultBody({required this.result});

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
                '질문',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 6),
              Text(
                result.question,
                style: const TextStyle(
                  color: AppColors.onDeepSpace,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        ...result.positions.map((p) => _PositionCard(position: p)),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('총평', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(
                result.summary,
                style: const TextStyle(fontSize: 14, height: 1.6),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PositionCard extends StatelessWidget {
  final TarotSpreadPosition position;
  const _PositionCard({required this.position});

  @override
  Widget build(BuildContext context) {
    final card = position.card;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 84,
              decoration: BoxDecoration(
                gradient: AppColors.mysticGradient,
                borderRadius: BorderRadius.circular(AppRadius.cardSmall),
              ),
              child: Transform.rotate(
                angle: card.isReversed ? 3.14159 : 0,
                child: const Center(
                  child: Icon(
                    Icons.auto_awesome,
                    color: AppColors.secondary,
                    size: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Text(
                          position.label,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${card.nameKr}${card.isReversed ? ' (역방향)' : ''}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    position.interpretation,
                    style: const TextStyle(fontSize: 13, height: 1.5),
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
