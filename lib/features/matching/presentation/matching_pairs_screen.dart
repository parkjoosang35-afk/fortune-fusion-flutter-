import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/load_state.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_toast.dart';
import '../application/matching_provider.dart';
import '../domain/matching_model.dart';

/// 03§5.3 MatchingPairsScreen - 06§4.6 GET /matching/pairs 대응
/// 04A M-3 matching_pairs status(Base: active/unmatched) + Mock단계 pendingAccept 표시
class MatchingPairsScreen extends StatefulWidget {
  const MatchingPairsScreen({super.key});

  @override
  State<MatchingPairsScreen> createState() => _MatchingPairsScreenState();
}

class _MatchingPairsScreenState extends State<MatchingPairsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MatchingProvider>().loadPairs();
    });
  }

  Future<void> _accept(MatchingPairModel pair) async {
    final ok = await context.read<MatchingProvider>().acceptPair(pair.id);
    if (!mounted) return;
    AppToast.show(
      context,
      ok ? '${pair.partnerNickname}님과 매칭이 시작되었습니다.' : '수락에 실패했습니다.',
      isError: !ok,
    );
  }

  Future<void> _end(MatchingPairModel pair) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: '매칭 종료',
      message: '${pair.partnerNickname}님과의 매칭을 종료할까요?',
      confirmLabel: '종료',
      isDanger: true,
    );
    if (!confirmed || !mounted) return;
    final ok = await context.read<MatchingProvider>().endPair(pair.id);
    if (!mounted) return;
    AppToast.show(context, ok ? '매칭이 종료되었습니다.' : '종료에 실패했습니다.', isError: !ok);
  }

  Future<void> _report(MatchingPairModel pair) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('신고하기'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(hintText: '신고 사유를 입력해 주세요'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('신고'),
          ),
        ],
      ),
    );
    if (reason == null || reason.trim().isEmpty || !mounted) return;
    final ok = await context.read<MatchingProvider>().report(
      MatchingReportTargetType.pair,
      pair.id,
      reason,
    );
    if (!mounted) return;
    AppToast.show(
      context,
      ok ? '신고가 접수되었습니다.' : '신고 접수에 실패했습니다.',
      isError: !ok,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MatchingProvider>().pairsState;

    return Scaffold(
      appBar: AppBar(title: const Text('매칭 목록')),
      body: SafeArea(
        child: switch (state.status) {
          LoadStatus.loading when !state.hasData => const Center(
            child: CircularProgressIndicator(),
          ),
          LoadStatus.error => AppErrorState(
            message: state.errorMessage ?? '매칭 목록을 불러오지 못했습니다.',
            onRetry: () => context.read<MatchingProvider>().loadPairs(),
          ),
          _ when (state.data ?? const []).isEmpty => AppEmptyState(
            icon: Icons.favorite_border_rounded,
            title: '아직 매칭된 상대가 없어요',
            description: '추천 대상에게 좋아요를 보내보세요',
            action: OutlinedButton(
              onPressed: () => Navigator.of(
                context,
              ).pushNamed('/ai-fortune/matching/discover'),
              child: const Text('추천 대상 보기'),
            ),
          ),
          _ => RefreshIndicator(
            onRefresh: () => context.read<MatchingProvider>().loadPairs(),
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: state.data!.length,
              itemBuilder: (context, index) {
                final pair = state.data![index];
                return _PairTile(
                  pair: pair,
                  onTap: pair.status == MatchingPairStatus.active
                      ? () => Navigator.of(context).pushNamed(
                          '/ai-fortune/matching/chat',
                          arguments: pair,
                        )
                      : null,
                  onAccept: () => _accept(pair),
                  onEnd: () => _end(pair),
                  onReport: () => _report(pair),
                );
              },
            ),
          ),
        },
      ),
    );
  }
}

class _PairTile extends StatelessWidget {
  final MatchingPairModel pair;
  final VoidCallback? onTap;
  final VoidCallback onAccept;
  final VoidCallback onEnd;
  final VoidCallback onReport;

  const _PairTile({
    required this.pair,
    required this.onTap,
    required this.onAccept,
    required this.onEnd,
    required this.onReport,
  });

  (String, Color) get _statusBadge {
    switch (pair.status) {
      case MatchingPairStatus.pendingAccept:
        return ('수락 대기중', AppColors.warning);
      case MatchingPairStatus.active:
        return ('진행중', AppColors.success);
      case MatchingPairStatus.unmatched:
        return ('종료됨', AppColors.textHint);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (label, color) = _statusBadge;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      pair.partnerEmoji,
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pair.partnerNickname,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          pair.lastMessage ?? '아직 대화가 없어요',
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (pair.status == MatchingPairStatus.pendingAccept)
                    TextButton(onPressed: onAccept, child: const Text('수락')),
                  if (pair.status != MatchingPairStatus.unmatched)
                    TextButton(
                      onPressed: onEnd,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                      ),
                      child: const Text('종료'),
                    ),
                  TextButton(
                    onPressed: onReport,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textHint,
                    ),
                    child: const Text('신고'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
