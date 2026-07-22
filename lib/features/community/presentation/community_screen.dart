import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../application/wish_post_provider.dart';
import '../domain/wish_post_model.dart';

/// 03단계 §3.3 커뮤니티 탭 - CommunityScreen(소원게시판 기본 피드)
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<WishPostProvider>().loadFeed());
  }

  Future<void> _openWriteSheet() async {
    final controller = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
          bottom: AppSpacing.lg + MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('소원 남기기', style: Theme.of(sheetContext).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: const InputDecoration(hintText: '이루고 싶은 소원을 적어보세요'),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: () async {
                final ok = await context.read<WishPostProvider>().createPost(controller.text);
                if (ok && sheetContext.mounted) Navigator.of(sheetContext).pop();
              },
              child: const Text('등록하기'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WishPostProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('소원게시판')),
      floatingActionButton: FloatingActionButton(
        onPressed: _openWriteSheet,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.edit_rounded, color: Colors.white),
      ),
      body: SafeArea(
        child: provider.isLoading && provider.posts.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : provider.posts.isEmpty
                ? const AppEmptyState(icon: Icons.favorite_border_rounded, title: '아직 소원이 없어요', description: '첫 번째 소원을 남겨보세요')
                : RefreshIndicator(
                    onRefresh: () => context.read<WishPostProvider>().loadFeed(),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      itemCount: provider.posts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                      itemBuilder: (context, index) => _PostCard(post: provider.posts[index]),
                    ),
                  ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final WishPostModel post;
  const _PostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.card)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(radius: 14, backgroundColor: AppColors.primaryContainer, child: Icon(Icons.person, size: 16, color: AppColors.primary)),
              const SizedBox(width: AppSpacing.sm),
              Text(post.authorNickname, style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              Text(
                '${post.createdAt.month}.${post.createdAt.day}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(post.content, style: const TextStyle(fontSize: 14, height: 1.5)),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              const Icon(Icons.favorite_border_rounded, size: 16, color: AppColors.textHint),
              const SizedBox(width: 4),
              Text('${post.likeCount}', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(width: AppSpacing.lg),
              const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: AppColors.textHint),
              const SizedBox(width: 4),
              Text('${post.commentCount}', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}
