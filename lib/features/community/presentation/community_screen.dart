import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../application/wish_post_provider.dart';
import '../domain/wish_post_model.dart';
import 'widgets/wish_report_sheet.dart';

const _wishCategories = ['이사/이동', '학업/시험', '연애/인연', '건강', '재물/사업', '기타'];

/// 03단계 §7.7 WishFeedScreen 표준패턴 - CommunityScreen(소원게시판 기본 피드)
/// [전체/인기/내소원] 탭 + FAB 글쓰기 + 카드 케밥메뉴(신고)
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _tabs = [WishFeedTab.all, WishFeedTab.popular, WishFeedTab.mine];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      context.read<WishPostProvider>().changeTab(_tabs[_tabController.index]);
    });
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<WishPostProvider>().loadFeed(),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openWriteSheet() async {
    final controller = TextEditingController();
    String category = _wishCategories.first;
    bool isAnonymous = false;

    await showAppBottomSheet(
      context,
      title: '소원 남기기',
      child: StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: _wishCategories.map((c) {
                  final selected = category == c;
                  return ChoiceChip(
                    label: Text(c),
                    selected: selected,
                    onSelected: (_) => setSheetState(() => category = c),
                    selectedColor: AppColors.primaryContainer,
                    labelStyle: TextStyle(
                      color: selected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: controller,
                maxLines: 4,
                decoration: const InputDecoration(hintText: '이루고 싶은 소원을 적어보세요'),
              ),
              const SizedBox(height: AppSpacing.sm),
              CheckboxListTile(
                value: isAnonymous,
                onChanged: (v) => setSheetState(() => isAnonymous = v ?? false),
                title: const Text('익명으로 작성'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: '등록하기',
                onPressed: () async {
                  final ok = await context.read<WishPostProvider>().createPost(
                    controller.text,
                    category: category,
                    isAnonymous: isAnonymous,
                  );
                  if (ok && sheetContext.mounted) {
                    Navigator.of(sheetContext).pop();
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
    final provider = context.watch<WishPostProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('소원게시판'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '전체'),
            Tab(text: '인기'),
            Tab(text: '내소원'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openWriteSheet,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.edit_rounded, color: Colors.white),
      ),
      body: SafeArea(
        child: provider.isLoading && provider.posts.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : provider.posts.isEmpty
            ? AppEmptyState(
                icon: Icons.favorite_border_rounded,
                title: '아직 소원이 없어요',
                description: provider.currentTab == WishFeedTab.mine
                    ? '내가 남긴 소원이 여기에 표시돼요'
                    : '첫 번째 소원을 남겨보세요',
              )
            : RefreshIndicator(
                onRefresh: () => context.read<WishPostProvider>().loadFeed(),
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: provider.posts.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) =>
                      _PostCard(post: provider.posts[index]),
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
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.card),
      onTap: () => Navigator.of(
        context,
      ).pushNamed('/community/wish/detail', arguments: post),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: Colors.white,
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
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    size: 18,
                    color: AppColors.textHint,
                  ),
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
            const SizedBox(height: AppSpacing.sm),
            _CategoryBadge(category: post.category),
            const SizedBox(height: AppSpacing.md),
            Text(
              post.content,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
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
                          '${post.supportCount}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                const Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 16,
                  color: AppColors.textHint,
                ),
                const SizedBox(width: 4),
                Text(
                  '${post.commentCount}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final String category;
  const _CategoryBadge({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        category,
        style: const TextStyle(
          fontSize: 11,
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
