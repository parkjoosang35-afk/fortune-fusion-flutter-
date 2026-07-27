import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/community_post_provider.dart';
import '../domain/community_post_model.dart';
import '../domain/wish_post_model.dart' show ReportTargetType;
import 'widgets/community_report_sheet.dart';

/// 02§12/06§4.12 리워드 커뮤니티 - PostDetailScreen(상세+좋아요+댓글+신고)
class CommunityPostDetailScreen extends StatefulWidget {
  final CommunityPostModel post;
  const CommunityPostDetailScreen({super.key, required this.post});

  @override
  State<CommunityPostDetailScreen> createState() =>
      _CommunityPostDetailScreenState();
}

class _CommunityPostDetailScreenState extends State<CommunityPostDetailScreen> {
  final _commentController = TextEditingController();
  bool _isSubmittingComment = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<CommunityPostProvider>().loadComments(widget.post.id),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  CommunityPostModel _latestPost(CommunityPostProvider provider) {
    return provider.posts.firstWhere(
      (p) => p.id == widget.post.id,
      orElse: () => widget.post,
    );
  }

  Future<void> _submitComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;
    setState(() => _isSubmittingComment = true);
    final ok = await context.read<CommunityPostProvider>().addComment(
      widget.post.id,
      content,
    );
    if (!mounted) return;
    setState(() => _isSubmittingComment = false);
    if (ok) _commentController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommunityPostProvider>();
    final post = _latestPost(provider);
    final comments = provider.commentsOf(post.id);
    final isLoadingComments = provider.isLoadingCommentsOf(post.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(post.boardName),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'report') {
                showCommunityReportSheet(
                  context,
                  targetType: ReportTargetType.communityPost,
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
                  _PostContentCard(post: post),
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

class _PostContentCard extends StatelessWidget {
  final CommunityPostModel post;
  const _PostContentCard({required this.post});

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
          Text(post.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Text(
                post.authorNickname,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${post.createdAt.month}.${post.createdAt.day}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(post.content, style: const TextStyle(fontSize: 15, height: 1.6)),
          const SizedBox(height: AppSpacing.md),
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () =>
                context.read<CommunityPostProvider>().toggleLike(post.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    post.isLikedByMe
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    size: 18,
                    color: post.isLikedByMe
                        ? AppColors.error
                        : AppColors.textHint,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '좋아요 ${post.likeCount}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final CommunityCommentModel comment;
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
