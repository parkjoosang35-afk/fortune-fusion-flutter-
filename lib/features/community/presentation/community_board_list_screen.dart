import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
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
      appBar: AppBar(title: const Text('커뮤니티 게시판')),
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
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: provider.boards.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.md),
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
      borderRadius: BorderRadius.circular(AppRadius.card),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CommunityPostListScreen(board: board),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: const BoxDecoration(
                color: AppColors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.forum_rounded, color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    board.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (board.description != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      board.description!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}
