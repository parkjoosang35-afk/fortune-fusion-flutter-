import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_unified_style.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../application/luckybag_provider.dart';
import '../../domain/luckybag_product_model.dart';
import '../../domain/luckybag_reward_model.dart';

/// 06§4.9 `GET /v1/luckybags/:id/probabilities` 대응 - 확률 공개 바텀시트
/// 투명성/법적 요건(06§4.9 설명 참조) - 등급별 확률(%)을 그대로 노출한다.
///
/// [복주머니 디자인 정합성 수정] 옛 다크 팔레트(AppColors) 참조를 제거하고
/// 허브/상점과 동일한 화이트+라벤더 [UnifiedColors]/[UnifiedText] 톤으로
/// 재작성한다.
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
            padding: EdgeInsets.symmetric(vertical: UnifiedTokens.spaceXxl),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final pools = List<LuckyBagRewardPoolModel>.from(provider.probabilities)
          ..sort((a, b) => b.grade.sortOrder.compareTo(a.grade.sortOrder));

        if (pools.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(
              vertical: UnifiedTokens.spaceXxl,
            ),
            child: Text('확률 정보를 불러오지 못했어요.', style: UnifiedText.body()),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final pool in pools) _ProbabilityRow(pool: pool),
            const SizedBox(height: UnifiedTokens.spaceSm),
            Text(
              '※ 확률은 등급 그룹 합계 100% 기준으로 공개되며, 실제 지급 내역과 일치합니다.',
              style: UnifiedText.caption(),
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
        return const Color(0xFFA9772F);
      case 'rare':
        return const Color(0xFF4DA8FF);
      case 'common':
        return const Color(0xFF5FE3B3);
      default:
        return UnifiedColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: UnifiedTokens.spaceMd),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _gradeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
            ),
            child: Text(
              pool.grade.name,
              style: UnifiedText.chipLabel(color: _gradeColor),
            ),
          ),
          const SizedBox(width: UnifiedTokens.spaceMd),
          Expanded(child: Text(pool.rewardLabel, style: UnifiedText.body())),
          Text(
            '${pool.probability.toStringAsFixed(pool.probability.truncateToDouble() == pool.probability ? 0 : 1)}%',
            style: UnifiedText.bodyStrong(),
          ),
        ],
      ),
    );
  }
}
