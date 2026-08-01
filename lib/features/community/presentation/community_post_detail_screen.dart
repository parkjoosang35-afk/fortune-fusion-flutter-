import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_unified_style.dart';
import '../../../core/widgets/app_toast.dart';
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
    // [3단계 - 행복머니 커뮤니티 적립 연동] 성공 시 서버가 지급한
    // rewardPoint(int)를 받는다. null이면 실패.
    final rewardPoint = await context.read<CommunityPostProvider>().addComment(
      widget.post.id,
      content,
    );
    if (!mounted) return;
    setState(() => _isSubmittingComment = false);
    if (rewardPoint != null) {
      _commentController.clear();
      if (rewardPoint > 0 && mounted) {
        AppToast.show(context, '댓글 등록 완료! +$rewardPoint P 획득');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommunityPostProvider>();
    final post = _latestPost(provider);
    final comments = provider.commentsOf(post.id);
    final isLoadingComments = provider.isLoadingCommentsOf(post.id);

    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      appBar: AppBar(
        backgroundColor: UnifiedColors.bg,
        elevation: 0,
        title: Text(post.boardName, style: UnifiedText.titleLarge()),
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
                padding: const EdgeInsets.all(UnifiedTokens.screenPadding),
                children: [
                  _PostContentCard(post: post),
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

class _PostContentCard extends StatelessWidget {
  final CommunityPostModel post;
  const _PostContentCard({required this.post});

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
          Text(post.title, style: UnifiedText.title()),
          const SizedBox(height: UnifiedTokens.spaceSm),
          Row(
            children: [
              Text(post.authorNickname, style: UnifiedText.caption()),
              const SizedBox(width: UnifiedTokens.spaceSm),
              Text(
                '${post.createdAt.month}.${post.createdAt.day}',
                style: UnifiedText.caption(),
              ),
            ],
          ),
          const SizedBox(height: UnifiedTokens.spaceMd),
          Text(
            post.content,
            style: UnifiedText.body(color: UnifiedColors.textPrimary),
          ),
          const SizedBox(height: UnifiedTokens.spaceMd),
          InkWell(
            borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
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
                        ? UnifiedColors.black
                        : UnifiedColors.textCaption,
                  ),
                  const SizedBox(width: 4),
                  Text('좋아요 ${post.likeCount}', style: UnifiedText.caption()),
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
