import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_unified_style.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../application/community_post_provider.dart';
import '../domain/community_post_model.dart';
import 'community_post_list_screen.dart';

/// 02§12/06§4.12 리워드 커뮤니티 - CommunityBoardListScreen(게시판 목록)
/// 04A L-1 `community_boards` 대응. 소원게시판(CommunityScreen)과는 별개 화면.
class CommunityBoardListScreen extends StatefulWidget {
  const CommunityBoardListScreen({super.key});

  @override
  State<CommunityBoardListScreen> createState() =>
      _CommunityBoardListScreenState();
}

class _CommunityBoardListScreenState extends State<CommunityBoardListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<CommunityPostProvider>().loadBoards(),
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
        title: Text('커뮤니티 게시판', style: UnifiedText.titleLarge()),
      ),
      body: SafeArea(
        child: provider.isLoadingBoards && provider.boards.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : provider.boards.isEmpty
            ? const AppEmptyState(
                icon: Icons.forum_outlined,
                title: '게시판이 없어요',
                description: '아직 등록된 게시판이 없습니다',
              )
            : ListView.separated(
                padding: const EdgeInsets.all(UnifiedTokens.screenPadding),
                itemCount: provider.boards.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: UnifiedTokens.spaceMd),
                itemBuilder: (context, index) =>
                    _BoardTile(board: provider.boards[index]),
              ),
      ),
    );
  }
}

class _BoardTile extends StatelessWidget {
  final CommunityBoardModel board;
  const _BoardTile({required this.board});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CommunityPostListScreen(board: board),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
        decoration: BoxDecoration(
          color: UnifiedColors.cardSection,
          borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
        ),
        child: Row(
          children: [
            Container(
              width: UnifiedTokens.iconCircleMd,
              height: UnifiedTokens.iconCircleMd,
              decoration: const BoxDecoration(
                color: UnifiedColors.cardAllMenu,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.forum_outlined,
                color: UnifiedColors.textPrimary,
                size: UnifiedTokens.iconMd,
              ),
            ),
            const SizedBox(width: UnifiedTokens.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(board.name, style: UnifiedText.bodyStrong()),
                  if (board.description != null) ...[
                    const SizedBox(height: 2),
                    Text(board.description!, style: UnifiedText.bodySmall()),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: UnifiedColors.textCaption,
              size: UnifiedTokens.iconMd,
            ),
          ],
        ),
      ),
    );
  }
}
