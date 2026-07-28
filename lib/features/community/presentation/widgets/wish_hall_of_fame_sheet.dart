import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../application/wish_post_provider.dart';

/// [소원성(Wish Castle) 확장] "소원성 명예의 전당" 전체보기 바텀시트.
///
/// community_screen의 `_HallOfFameStrip`(클라이언트 파생 집계, 상위 5명)은 그대로
/// 유지하고, 이 시트는 서버 집계 버전(관리자가 CMS에서 수동 선정한 성취 후기 +
/// 응원 누적 top 10 랭킹)을 추가로 보여준다. 신규 화면을 별도로 만들지 않고
/// 바텀시트로 구성해 미니멀 원칙(화면을 늘리지 않음)을 지킨다.
Future<void> showWishHallOfFameSheet(BuildContext context) {
  // 열릴 때마다 최신 데이터를 1회 로드(가벼운 GET 1회, 무해).
  context.read<WishPostProvider>().loadHallOfFame();
  return showAppBottomSheet<void>(
    context,
    title: '소원성 명예의 전당',
    child: const _HallOfFameSheetBody(),
  );
}

class _HallOfFameSheetBody extends StatelessWidget {
  const _HallOfFameSheetBody();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WishPostProvider>();

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child:
          provider.isLoadingHallOfFame &&
              provider.featuredReviews.isEmpty &&
              provider.hallOfFameRanking.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🌟 이룬 소원들의 이야기',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (provider.featuredReviews.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                      ),
                      child: Text(
                        '아직 선정된 후기가 없어요.',
                        style: TextStyle(color: AppColors.textHintOf(context)),
                      ),
                    )
                  else
                    ...provider.featuredReviews.map(
                      (r) => _FeaturedReviewCard(review: r),
                    ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    '🏆 응원 누적 랭킹',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (provider.hallOfFameRanking.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                      ),
                      child: Text(
                        '아직 랭킹 데이터가 없어요.',
                        style: TextStyle(color: AppColors.textHintOf(context)),
                      ),
                    )
                  else
                    ...provider.hallOfFameRanking.asMap().entries.map(
                      (e) => _RankingRow(rank: e.key + 1, entry: e.value),
                    ),
                ],
              ),
            ),
    );
  }
}

class _FeaturedReviewCard extends StatelessWidget {
  final Map<String, dynamic> review;
  const _FeaturedReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final nickname = review['authorNickname'] as String? ?? '익명';
    final content = review['content'] as String? ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.cardSmall),
        border: Border.all(color: AppColors.goldGlowBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🌟', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 4),
              Text(
                nickname,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(content, style: const TextStyle(fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }
}

class _RankingRow extends StatelessWidget {
  final int rank;
  final Map<String, dynamic> entry;
  const _RankingRow({required this.rank, required this.entry});

  static const _medals = ['🥇', '🥈', '🥉'];

  @override
  Widget build(BuildContext context) {
    final nickname = entry['nickname'] as String? ?? '익명';
    final totalSupport = (entry['totalSupport'] as num?)?.toInt() ?? 0;
    final wishCount = (entry['wishCount'] as num?)?.toInt() ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Text(
            rank <= 3 ? _medals[rank - 1] : '$rank',
            style: const TextStyle(fontSize: 15),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              nickname,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Text(
            '소원 $wishCount개',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondaryOf(context),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '❤️ $totalSupport',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
