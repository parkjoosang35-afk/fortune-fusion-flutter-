import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_unified_style.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_toast.dart';
import '../application/community_post_provider.dart';
import '../domain/community_post_model.dart';
import 'community_post_detail_screen.dart';

/// 02§12/06§4.12 리워드 커뮤니티 - PostListScreen(게시판별 글목록)
/// [최신/인기] 탭 + FAB 글쓰기(PostWriteScreen 대응 BottomSheet)
class CommunityPostListScreen extends StatefulWidget {
  final CommunityBoardModel board;
  const CommunityPostListScreen({super.key, required this.board});

  @override
  State<CommunityPostListScreen> createState() =>
      _CommunityPostListScreenState();
}

class _CommunityPostListScreenState extends State<CommunityPostListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      context.read<CommunityPostProvider>().loadPosts(
        boardId: widget.board.id,
        sortByPopular: _tabController.index == 1,
      );
    });
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<CommunityPostProvider>().loadPosts(
        boardId: widget.board.id,
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openWriteSheet() async {
    final titleController = TextEditingController();
    final contentController = TextEditingController();

    await showAppBottomSheet(
      context,
      title: '${widget.board.name}에 글쓰기',
      child: StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(hintText: '제목을 입력해 주세요'),
              ),
              const SizedBox(height: UnifiedTokens.spaceMd),
              TextField(
                controller: contentController,
                maxLines: 5,
                decoration: const InputDecoration(hintText: '내용을 입력해 주세요'),
              ),
              const SizedBox(height: UnifiedTokens.spaceMd),
              AppButton(
                label: '등록하기',
                onPressed: () async {
                  // [3단계 - 복주머니 커뮤니티 적립 연동] 성공 시 서버가 지급한
                  // rewardPoint(int)를 받는다. null이면 실패.
                  final rewardPoint = await context
                      .read<CommunityPostProvider>()
                      .createPost(
                        boardId: widget.board.id,
                        title: titleController.text,
                        content: contentController.text,
                      );
                  if (rewardPoint == null) return;
                  if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                  if (rewardPoint > 0 && context.mounted) {
                    AppToast.show(context, '게시글 등록 완료! 복주머니 $rewardPoint개 획득');
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommunityPostProvider>();

    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      appBar: AppBar(
        backgroundColor: UnifiedColors.bg,
        elevation: 0,
        title: Text(widget.board.name, style: UnifiedText.titleLarge()),
        bottom: TabBar(
          controller: _tabController,
          labelColor: UnifiedColors.textPrimary,
          unselectedLabelColor: UnifiedColors.textCaption,
          indicatorColor: UnifiedColors.black,
          labelStyle: UnifiedText.bodyStrong(),
          tabs: const [
            Tab(text: '최신'),
            Tab(text: '인기'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openWriteSheet,
        backgroundColor: UnifiedColors.black,
        child: const Icon(Icons.edit_rounded, color: Colors.white),
      ),
      body: SafeArea(
        child: provider.isLoadingPosts && provider.posts.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : provider.posts.isEmpty
            ? const AppEmptyState(
                icon: Icons.article_outlined,
                title: '아직 게시글이 없어요',
                description: '첫 번째 글을 남겨보세요',
              )
            : RefreshIndicator(
                onRefresh: () =>
                    context.read<CommunityPostProvider>().loadPosts(
                      boardId: widget.board.id,
                      sortByPopular: _tabController.index == 1,
                    ),
                child: ListView.separated(
                  padding: const EdgeInsets.all(UnifiedTokens.screenPadding),
                  itemCount: provider.posts.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: UnifiedTokens.spaceMd),
                  itemBuilder: (context, index) =>
                      _PostTile(post: provider.posts[index]),
                ),
              ),
      ),
    );
  }
}

class _PostTile extends StatelessWidget {
  final CommunityPostModel post;
  const _PostTile({required this.post});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CommunityPostDetailScreen(post: post),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
        decoration: BoxDecoration(
          color: UnifiedColors.cardSection,
          borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (post.isPinned) ...[
                  Icon(
                    Icons.push_pin_rounded,
                    size: 14,
                    color: UnifiedColors.textPrimary,
                  ),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    post.title,
                    style: UnifiedText.bodyStrong(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: UnifiedTokens.spaceSm),
            Text(
              post.content,
              style: UnifiedText.bodySmall(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: UnifiedTokens.spaceMd),
            Row(
              children: [
                Text(post.authorNickname, style: UnifiedText.caption()),
                const SizedBox(width: UnifiedTokens.spaceSm),
                Text(
                  '${post.createdAt.month}.${post.createdAt.day}',
                  style: UnifiedText.caption(),
                ),
                const Spacer(),
                Icon(
                  post.isLikedByMe
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: 14,
                  color: post.isLikedByMe
                      ? UnifiedColors.black
                      : UnifiedColors.textCaption,
                ),
                const SizedBox(width: 4),
                Text('${post.likeCount}', style: UnifiedText.caption()),
                const SizedBox(width: UnifiedTokens.spaceMd),
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 14,
                  color: UnifiedColors.textCaption,
                ),
                const SizedBox(width: 4),
                Text('${post.commentCount}', style: UnifiedText.caption()),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
