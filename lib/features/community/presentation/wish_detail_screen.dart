import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../wallet/presentation/widgets/send_bok_sheet.dart';
import '../application/wish_post_provider.dart';
import '../domain/wish_post_model.dart';
import 'widgets/wish_report_sheet.dart';

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
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<WishPostProvider>().loadComments(widget.post.id),
    );
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
    final ok = await context.read<WishPostProvider>().addComment(
      widget.post.id,
      content,
    );
    if (!mounted) return;
    setState(() => _isSubmittingComment = false);
    if (ok) _commentController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WishPostProvider>();
    final post = _latestPost(provider);
    final comments = provider.commentsOf(post.id);
    final isLoadingComments = provider.isLoadingCommentsOf(post.id);

    return Scaffold(
      appBar: AppBar(
        title: const Text('소원 상세'),
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
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  _WishContentCard(post: post),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    '댓글 ${post.commentCount}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (isLoadingComments)
                    const Center(child: CircularProgressIndicator())
                  else if (comments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                      child: Center(
                        child: Text(
                          '첫 댓글을 남겨보세요',
                          style: TextStyle(color: AppColors.textHint),
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
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.primaryContainer,
                child: Icon(Icons.person, size: 16, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                post.isAnonymous ? '익명' : post.authorNickname,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              Text(
                '${post.createdAt.month}.${post.createdAt.day}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              post.category,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(post.content, style: const TextStyle(fontSize: 15, height: 1.6)),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(999),
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
                            ? AppColors.error
                            : AppColors.textHint,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '행운 보내기 ${post.supportCount}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              // [Phase22-3 - 황금률 출구버튼] 익명 게시물/내 게시물은 대상이
              // 불명확하거나 무의미하므로 버튼을 노출하지 않는다.
              if (!post.isAnonymous && !post.isMine) ...[
                const SizedBox(width: AppSpacing.md),
                InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => showSendBokSheet(
                    context,
                    recipientNickname: post.authorNickname,
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.volunteer_activism_rounded,
                          size: 18,
                          color: AppColors.secondary,
                        ),
                        SizedBox(width: 4),
                        Text('복 나누기', style: TextStyle(fontSize: 12.5)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
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
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 12,
            backgroundColor: AppColors.primaryContainer,
            child: Icon(Icons.person, size: 14, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comment.authorNickname,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  comment.content,
                  style: const TextStyle(fontSize: 13.5, height: 1.4),
                ),
              ],
            ),
          ),
        ],
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
        left: AppSpacing.lg,
        right: AppSpacing.sm,
        top: AppSpacing.sm,
        bottom: AppSpacing.sm + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        border: Border(top: BorderSide(color: AppColors.divider)),
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
                : const Icon(Icons.send_rounded, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}
