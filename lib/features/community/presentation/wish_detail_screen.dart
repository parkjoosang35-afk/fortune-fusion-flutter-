import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_unified_style.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/luck_pouch_toast.dart';
import '../../wallet/application/wallet_provider.dart';
import '../../wallet/presentation/widgets/send_bok_sheet.dart';
import '../application/wish_post_provider.dart';
import '../domain/wish_post_model.dart';
import 'community_screen.dart' show WishCandleBadge;
import 'widgets/send_bokju_sheet.dart';
import 'widgets/wish_journey_sheet.dart';
import 'widgets/wish_milestone_dialog.dart';
import 'widgets/wish_report_sheet.dart';
import 'widgets/wish_review_sheet.dart';

/// [재화 구조 정리 - 재연결] cheer/empathize/highlight/expose_boost 4개 유료
/// 액션 공용 실행 헬퍼 - 확인 다이얼로그 → API 호출 → 지갑 새로고침 → 공용
/// 차감 토스트까지의 반복 흐름을 한 곳에 모은다(send_bokju_sheet.dart와 동일 패턴).
Future<void> _runWishSpendAction(
  BuildContext context, {
  required String title,
  required String message,
  required Future<WishSpendActionResult?> Function() action,
  required String toastReason,
}) async {
  final confirmed = await showAppConfirmDialog(
    context,
    title: title,
    message: message,
  );
  if (!confirmed || !context.mounted) return;

  final provider = context.read<WishPostProvider>();
  final result = await action();
  if (!context.mounted) return;

  if (result == null) {
    final errMsg = provider.lastWishActionError ?? '처리에 실패했습니다.';
    if (errMsg.contains('부족')) {
      LuckPouchToastController.instance.showInsufficient();
    } else {
      AppToast.show(context, errMsg, isError: true);
    }
    return;
  }

  await context.read<WalletProvider>().load();
  if (!context.mounted) return;
  LuckPouchToastController.instance.showSpend(result.amountSpent, toastReason);
}

/// 03단계 §7.7 WishFeedScreen 연계 상세화면 - 소원 상세 + 댓글(comments L-4)
class WishDetailScreen extends StatefulWidget {
  final WishPostModel post;
  const WishDetailScreen({super.key, required this.post});

  @override
  State<WishDetailScreen> createState() => _WishDetailScreenState();
}

class _WishDetailScreenState extends State<WishDetailScreen> {
  final _commentController = TextEditingController();
  bool _isSubmittingComment = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WishPostProvider>().loadComments(widget.post.id);
      // [소원성(Wish Castle) 확장] 최종단계(레벨4) 특별 연출 - 아직 노출한 적이
      // 없는 경우에만 1회 재생(내부에서 isMilestoneShown/isMaxLevel 이중 검사).
      WishMilestoneDialog.showIfNeeded(context, widget.post);
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  WishPostModel _latestPost(WishPostProvider provider) {
    return provider.posts.firstWhere(
      (p) => p.id == widget.post.id,
      orElse: () => widget.post,
    );
  }

  Future<void> _submitComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;
    setState(() => _isSubmittingComment = true);
    // [3단계 - 복주머니 커뮤니티 적립 연동] 성공 시 서버가 지급한
    // bokjuAwarded(int)를 받는다. null이면 실패.
    final bokjuAwarded = await context.read<WishPostProvider>().addComment(
      widget.post.id,
      content,
    );
    if (!mounted) return;
    setState(() => _isSubmittingComment = false);
    if (bokjuAwarded != null) {
      _commentController.clear();
      if (bokjuAwarded > 0 && mounted) {
        AppToast.show(context, '댓글 등록 완료! +$bokjuAwarded 복주머니');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WishPostProvider>();
    final post = _latestPost(provider);
    final comments = provider.commentsOf(post.id);
    final isLoadingComments = provider.isLoadingCommentsOf(post.id);

    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      appBar: AppBar(
        backgroundColor: UnifiedColors.bg,
        elevation: 0,
        title: Text('소원 상세', style: UnifiedText.titleLarge()),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'report') {
                showWishReportSheet(
                  context,
                  targetType: ReportTargetType.wish,
                  targetId: post.id,
                );
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'report', child: Text('신고하기')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(UnifiedTokens.screenPadding),
                children: [
                  _WishContentCard(post: post),
                  const SizedBox(height: UnifiedTokens.spaceXl),
                  Text('댓글 ${post.commentCount}', style: UnifiedText.title()),
                  const SizedBox(height: UnifiedTokens.spaceMd),
                  if (isLoadingComments)
                    const Center(child: CircularProgressIndicator())
                  else if (comments.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: UnifiedTokens.spaceXl,
                      ),
                      child: Center(
                        child: Text(
                          '첫 댓글을 남겨보세요',
                          style: UnifiedText.caption(),
                        ),
                      ),
                    )
                  else
                    ...comments.map((c) => _CommentTile(comment: c)),
                ],
              ),
            ),
            _CommentInputBar(
              controller: _commentController,
              isSubmitting: _isSubmittingComment,
              onSubmit: _submitComment,
            ),
          ],
        ),
      ),
    );
  }
}

class _WishContentCard extends StatelessWidget {
  final WishPostModel post;
  const _WishContentCard({required this.post});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
      decoration: BoxDecoration(
        color: UnifiedColors.cardSection,
        borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: UnifiedColors.cardAllMenu,
                child: Icon(
                  Icons.person_outline_rounded,
                  size: 16,
                  color: UnifiedColors.textPrimary,
                ),
              ),
              const SizedBox(width: UnifiedTokens.spaceSm),
              Text(
                post.isAnonymous ? '익명' : post.authorNickname,
                style: UnifiedText.bodyStrong(),
              ),
              const Spacer(),
              Text(
                '${post.createdAt.month}.${post.createdAt.day}',
                style: UnifiedText.caption(),
              ),
            ],
          ),
          const SizedBox(height: UnifiedTokens.spaceSm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: UnifiedColors.cardAllMenu,
              borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
            ),
            child: Text(post.category, style: UnifiedText.chipLabel()),
          ),
          const SizedBox(height: UnifiedTokens.spaceMd),
          Text(
            post.content,
            style: UnifiedText.body(color: UnifiedColors.textPrimary),
          ),
          const SizedBox(height: UnifiedTokens.spaceMd),
          // [소원성(Wish Castle) 확장] 촛불 레벨/진행바 - 미니멀 원칙에 따라
          // 한 줄 배지 형태로만 표시(화려한 연출은 별도 다이얼로그에서만 재생).
          Row(
            children: [
              Expanded(child: WishCandleBadge(post: post)),
              TextButton.icon(
                onPressed: () => showWishJourneySheet(context, post),
                icon: Icon(
                  Icons.timeline_rounded,
                  size: UnifiedTokens.iconSm,
                  color: UnifiedColors.textCaption,
                ),
                label: Text('소원의 여정', style: UnifiedText.caption()),
                style: TextButton.styleFrom(
                  foregroundColor: UnifiedColors.textCaption,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
              ),
            ],
          ),
          const SizedBox(height: UnifiedTokens.spaceMd),
          Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
                onTap: () =>
                    context.read<WishPostProvider>().toggleSupport(post.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        post.isSupportedByMe
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 18,
                        color: post.isSupportedByMe
                            ? UnifiedColors.black
                            : UnifiedColors.textCaption,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '행운 보내기 ${post.supportCount}',
                        style: UnifiedText.caption(),
                      ),
                    ],
                  ),
                ),
              ),
              // [Phase22-3 - 황금률 출구버튼] 익명 게시물/내 게시물은 대상이
              // 불명확하거나 무의미하므로 버튼을 노출하지 않는다.
              if (!post.isAnonymous && !post.isMine) ...[
                const SizedBox(width: UnifiedTokens.spaceMd),
                InkWell(
                  borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
                  onTap: () => showSendBokSheet(
                    context,
                    recipientNickname: post.authorNickname,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.volunteer_activism_outlined,
                          size: 18,
                          color: UnifiedColors.textPrimary,
                        ),
                        const SizedBox(width: 4),
                        Text('복 나누기', style: UnifiedText.caption()),
                      ],
                    ),
                  ),
                ),
              ],
              // [재화 구조 정리 - 재연결] 복주머니 보내기 - 선택한 개수만큼 실제
              // 지갑에서 차감된다. 익명/본인 게시물 여부와 무관하게 항상 노출한다.
              // 최종 레벨 도달 시에는 이미 다 자란 상태이므로 숨겨서 불필요한
              // 상호작용을 막는다.
              if (!post.isMaxLevel) ...[
                const SizedBox(width: UnifiedTokens.spaceMd),
                InkWell(
                  borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
                  onTap: () => showSendBokjuSheet(context, wishId: post.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.auto_awesome_outlined,
                          size: 18,
                          color: UnifiedColors.textPrimary,
                        ),
                        const SizedBox(width: 4),
                        Text('복주머니 보내기', style: UnifiedText.caption()),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                // [소원성(Wish Castle) 확장] 성취 후기 작성 - 최종레벨(가장 밝은
                // 불꽃) 도달 소원에서만 노출(서버도 candleLevel<4면 400 거부).
                const SizedBox(width: UnifiedTokens.spaceMd),
                InkWell(
                  borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
                  onTap: () => showWishReviewSheet(context, wishId: post.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit_note_outlined,
                          size: 18,
                          color: UnifiedColors.textPrimary,
                        ),
                        const SizedBox(width: 4),
                        Text('성취 후기 남기기', style: UnifiedText.caption()),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          // [재화 구조 정리 - 재연결] 글 강조(highlight)/노출 강화(expose_boost) -
          // 본인 소원에만 노출한다(서버도 403으로 가드).
          if (post.isMine) ...[
            const SizedBox(height: UnifiedTokens.spaceSm),
            Row(
              children: [
                _OwnerActionChip(
                  icon: Icons.star_outline_rounded,
                  label: post.isHighlighted ? '강조 중' : '글 강조',
                  active: post.isHighlighted,
                  onTap: post.isHighlighted
                      ? null
                      : () => _runWishSpendAction(
                          context,
                          title: '글 강조',
                          message: '복주머니를 사용해 이 소원을 24시간 동안 강조 표시할까요?',
                          action: () => context
                              .read<WishPostProvider>()
                              .highlightWish(post.id),
                          toastReason: '글 강조',
                        ),
                ),
                const SizedBox(width: UnifiedTokens.spaceMd),
                _OwnerActionChip(
                  icon: Icons.trending_up_rounded,
                  label: post.isBoosted ? '노출 중' : '노출 강화',
                  active: post.isBoosted,
                  onTap: post.isBoosted
                      ? null
                      : () => _runWishSpendAction(
                          context,
                          title: '노출 강화',
                          message: '복주머니를 사용해 이 소원을 24시간 동안 피드 상단에 노출할까요?',
                          action: () => context
                              .read<WishPostProvider>()
                              .exposeBoostWish(post.id),
                          toastReason: '노출 강화',
                        ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// [재화 구조 정리 - 재연결] 글 강조/노출 강화 진입 버튼 - 활성화 상태면
/// 비활성 스타일(체크 아이콘 + 탭 불가)로 전환해 중복 구매를 막는다.
class _OwnerActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;
  const _OwnerActionChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? UnifiedColors.neon.withValues(alpha: 0.35)
              : UnifiedColors.cardAllMenu,
          borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active ? Icons.check_circle_rounded : icon,
              size: 15,
              color: active
                  ? UnifiedColors.textPrimary
                  : UnifiedColors.textCaption,
            ),
            const SizedBox(width: 4),
            Text(label, style: UnifiedText.chipLabel()),
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final WishCommentModel comment;
  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: UnifiedTokens.spaceSm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: UnifiedColors.cardAllMenu,
            child: Icon(
              Icons.person_outline_rounded,
              size: 14,
              color: UnifiedColors.textPrimary,
            ),
          ),
          const SizedBox(width: UnifiedTokens.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(comment.authorNickname, style: UnifiedText.bodyStrong()),
                const SizedBox(height: 2),
                Text(
                  comment.content,
                  style: UnifiedText.body(color: UnifiedColors.textPrimary),
                ),
                const SizedBox(height: 4),
                // [재화 구조 정리 - 재연결] 댓글 응원(cheer)/공감(empathize) -
                // 복주머니를 소비하는 유료 반응(토글 아님, 누를 때마다 1씩 증가).
                Row(
                  children: [
                    _ReactionButton(
                      icon: Icons.celebration_outlined,
                      count: comment.cheerCount,
                      onTap: () => _runWishSpendAction(
                        context,
                        title: '댓글 응원',
                        message: '복주머니를 사용해 이 댓글을 응원할까요?',
                        action: () => context
                            .read<WishPostProvider>()
                            .cheerComment(comment.wishId, comment.id),
                        toastReason: '댓글 응원',
                      ),
                    ),
                    const SizedBox(width: UnifiedTokens.spaceMd),
                    _ReactionButton(
                      icon: Icons.favorite_outline_rounded,
                      count: comment.empathizeCount,
                      onTap: () => _runWishSpendAction(
                        context,
                        title: '댓글 공감',
                        message: '복주머니를 사용해 이 댓글에 공감을 표시할까요?',
                        action: () => context
                            .read<WishPostProvider>()
                            .empathizeComment(comment.wishId, comment.id),
                        toastReason: '댓글 공감',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// [재화 구조 정리 - 재연결] 댓글 응원/공감 카운트 버튼(최소 스타일 - 아이콘 + 숫자).
class _ReactionButton extends StatelessWidget {
  final IconData icon;
  final int count;
  final VoidCallback onTap;
  const _ReactionButton({
    required this.icon,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: UnifiedColors.textCaption),
            const SizedBox(width: 3),
            Text('$count', style: UnifiedText.caption()),
          ],
        ),
      ),
    );
  }
}

class _CommentInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  const _CommentInputBar({
    required this.controller,
    required this.isSubmitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: UnifiedTokens.spaceLg,
        right: UnifiedTokens.spaceSm,
        top: UnifiedTokens.spaceSm,
        bottom: UnifiedTokens.spaceSm + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: UnifiedColors.bg,
        border: Border(top: BorderSide(color: UnifiedColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: '댓글을 입력해 주세요',
                isDense: true,
              ),
              onSubmitted: (_) => onSubmit(),
            ),
          ),
          IconButton(
            onPressed: isSubmitting ? null : onSubmit,
            icon: isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.send_rounded, color: UnifiedColors.textPrimary),
          ),
        ],
      ),
    );
  }
}
