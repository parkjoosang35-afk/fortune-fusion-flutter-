import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_unified_style.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../application/wish_castle_config_provider.dart';
import '../../application/wish_post_provider.dart';
import '../../domain/wish_post_model.dart';

/// [소원성(Wish Castle) 확장] "소원의 여정" 타임라인 바텀시트.
///
/// [설계] 신규 히스토리 API/원자단위를 추가하지 않고(03§9.2 과설계 방지), 이미
/// 클라이언트가 보유한 데이터만으로 여정을 재구성한다:
/// - 소원 등록(createdAt)
/// - 촛불 레벨 마일스톤(0~post.candleLevel, wish_config 임계값 기준 계산값 표기)
/// - 응원 댓글들(loadComments로 이미 로드되는 값, 시간순 이벤트로 표시)
/// - 최종 단계 도달(achievedAt, 있는 경우)
/// 정확한 시각 정보가 없는 마일스톤은 "달성됨"으로만 표기하고 날짜는 생략한다
/// (없는 데이터를 임의로 만들어내지 않는다는 원칙).
Future<void> showWishJourneySheet(BuildContext context, WishPostModel post) {
  return showAppBottomSheet<void>(
    context,
    title: '소원의 여정',
    child: _WishJourneyBody(post: post),
  );
}

class _WishJourneyBody extends StatelessWidget {
  final WishPostModel post;
  const _WishJourneyBody({required this.post});

  @override
  Widget build(BuildContext context) {
    final config = context.watch<WishCastleConfigProvider>();
    final comments = context.watch<WishPostProvider>().commentsOf(post.id);
    final thresholds = config.candleLevelThresholds;

    final items = <_JourneyItem>[
      _JourneyItem(
        icon: '🌱',
        title: '소원을 남겼어요',
        subtitle:
            '${post.createdAt.year}.${post.createdAt.month}.${post.createdAt.day}',
        achieved: true,
      ),
      for (var level = 1; level <= WishPostModel.maxCandleLevel; level++)
        _JourneyItem(
          icon: wishCandleLevelOf(level).emoji,
          title: '${wishCandleLevelOf(level).name}으로 성장',
          subtitle: level <= thresholds.length
              ? '복주머니 ${thresholds[level - 1]}개 누적 달성'
              : null,
          achieved: post.candleLevel >= level,
        ),
      ...comments.map(
        (c) => _JourneyItem(
          icon: '💬',
          title: '${c.authorNickname}님의 응원',
          subtitle: c.content,
          achieved: true,
          isComment: true,
        ),
      ),
      if (post.achievedAt != null)
        _JourneyItem(
          icon: '🌟',
          title: '가장 밝은 불꽃에 도달했어요',
          subtitle:
              '${post.achievedAt!.year}.${post.achievedAt!.month}.${post.achievedAt!.day}',
          achieved: true,
        ),
    ];

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.65,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < items.length; i++)
              _JourneyRow(item: items[i], isLast: i == items.length - 1),
          ],
        ),
      ),
    );
  }
}

class _JourneyItem {
  final String icon;
  final String title;
  final String? subtitle;
  final bool achieved;
  final bool isComment;

  const _JourneyItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.achieved,
    this.isComment = false,
  });
}

class _JourneyRow extends StatelessWidget {
  final _JourneyItem item;
  final bool isLast;
  const _JourneyRow({required this.item, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final dim = !item.achieved;
    return Padding(
      padding: const EdgeInsets.only(bottom: UnifiedTokens.spaceMd),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: dim
                      ? UnifiedColors.chipInactiveBg
                      : UnifiedColors.cardAllMenu,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Opacity(
                  opacity: dim ? 0.35 : 1.0,
                  child: Text(item.icon, style: const TextStyle(fontSize: 14)),
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: item.subtitle != null ? 34 : 20,
                  color: UnifiedColors.border,
                ),
            ],
          ),
          const SizedBox(width: UnifiedTokens.spaceSm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: UnifiedText.bodyStrong(
                      color: dim
                          ? UnifiedColors.textCaption
                          : UnifiedColors.textPrimary,
                    ),
                  ),
                  if (item.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle!,
                      maxLines: item.isComment ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: UnifiedText.bodySmall(
                        color: UnifiedColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
