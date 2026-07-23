import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../application/luckybag_provider.dart';
import '../../domain/luckybag_product_model.dart';
import '../../domain/luckybag_reward_model.dart';

/// 06§4.9 `GET /v1/luckybags/:id/probabilities` 대응 - 확률 공개 바텀시트
/// 투명성/법적 요건(06§4.9 설명 참조) - 등급별 확률(%)을 그대로 노출한다.
Future<void> showLuckyBagProbabilitySheet(
  BuildContext context, {
  required LuckyBagProductModel product,
}) {
  // 화면 진입 시 이미 loadProbabilities를 호출했다는 전제(호출측에서 선행 로드).
  return showAppBottomSheet<void>(
    context,
    title: '${product.name} 확률 공개',
    child: Consumer<LuckyBagProvider>(
      builder: (context, provider, _) {
        if (provider.isProbabilitiesLoading) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final pools = List<LuckyBagRewardPoolModel>.from(provider.probabilities)
          ..sort((a, b) => b.grade.sortOrder.compareTo(a.grade.sortOrder));

        if (pools.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Text('확률 정보를 불러오지 못했어요.'),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final pool in pools) _ProbabilityRow(pool: pool),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              '※ 확률은 등급 그룹 합계 100% 기준으로 공개되며, 실제 지급 내역과 일치합니다.',
              style: TextStyle(fontSize: 11, color: AppColors.textHint),
            ),
          ],
        );
      },
    ),
  );
}

class _ProbabilityRow extends StatelessWidget {
  final LuckyBagRewardPoolModel pool;
  const _ProbabilityRow({required this.pool});

  Color get _gradeColor {
    switch (pool.grade.code) {
      case 'best':
        return AppColors.secondaryDark;
      case 'rare':
        return AppColors.info;
      case 'common':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _gradeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(
              pool.grade.name,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _gradeColor,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              pool.rewardLabel,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Text(
            '${pool.probability.toStringAsFixed(pool.probability.truncateToDouble() == pool.probability ? 0 : 1)}%',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
