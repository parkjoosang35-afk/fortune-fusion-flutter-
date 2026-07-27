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
// [웹→앱 이식] 신통방통 wish.html "같은 목표를 가진 사람과 함께 응원받기(선택)" 목표태그 풀
const _goalTags = ['이사/이동', '합격/시험', '연애/인연', '건강', '취업/사업', '기타'];

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WishPostProvider>().loadFeed();
      context.read<WishPostProvider>().checkRouletteAvailability();
    });
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
    String? goalTag;

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
                    selectedColor: AppColors.containerOf(context),
                    labelStyle: TextStyle(
                      color: selected
                          ? AppColors.primary
                          : AppColors.textSecondaryOf(context),
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
              const SizedBox(height: AppSpacing.md),
              // [웹→앱 이식] 신통방통 wish.html "같은 목표를 가진 사람과 함께 응원받기(선택)"
              Text(
                '같은 목표를 가진 사람과 함께 응원받기(선택)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondaryOf(context),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: _goalTags.map((tag) {
                  final selected = goalTag == tag;
                  return ChoiceChip(
                    label: Text(tag),
                    selected: selected,
                    onSelected: (_) => setSheetState(
                      () => goalTag = selected ? null : tag,
                    ),
                    selectedColor: AppColors.secondary.withValues(alpha: 0.2),
                    labelStyle: TextStyle(
                      color: selected
                          ? AppColors.secondaryDark
                          : AppColors.textSecondaryOf(context),
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    ),
                  );
                }).toList(),
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
                label: '소원 빌고 등록하기',
                onPressed: () async {
                  final ok = await context.read<WishPostProvider>().createPost(
                    controller.text,
                    category: category,
                    isAnonymous: isAnonymous,
                    goalTag: goalTag,
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
        actions: [
          // 02§12 리워드 커뮤니티(자유게시판) 진입점 - Phase16, 기존 소원게시판 로직은 변경하지 않음
          IconButton(
            tooltip: '커뮤니티 게시판',
            icon: const Icon(Icons.forum_outlined),
            onPressed: () =>
                Navigator.of(context).pushNamed('/community/board/list'),
          ),
        ],
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
            : RefreshIndicator(
                onRefresh: () => context.read<WishPostProvider>().loadFeed(),
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: provider.posts.length + 1,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _WishStatsRow(todayCount: provider.todayCount),
                          const SizedBox(height: AppSpacing.lg),
                          if (provider.hotWishes.isNotEmpty) ...[
                            _SectionHeader(
                              icon: Icons.local_fire_department_rounded,
                              title: '오늘의 인기 소원',
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            _HotWishStrip(wishes: provider.hotWishes),
                            const SizedBox(height: AppSpacing.lg),
                          ],
                          if (provider.hallOfFame.isNotEmpty) ...[
                            _SectionHeader(
                              icon: Icons.emoji_events_rounded,
                              title: '소원성 명예의 전당',
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            _HallOfFameStrip(entries: provider.hallOfFame),
                            const SizedBox(height: AppSpacing.lg),
                          ],
                          _SectionHeader(
                            icon: Icons.blur_circular_rounded,
                            title: '오늘의 행운 룰렷',
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          const _LuckyRouletteCard(),
                          const SizedBox(height: AppSpacing.lg),
                          _SectionHeader(
                            icon: Icons.favorite_rounded,
                            title: '함께 응원하기',
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          if (provider.posts.isEmpty)
                            AppEmptyState(
                              icon: Icons.favorite_border_rounded,
                              title: '아직 소원이 없어요',
                              description:
                                  provider.currentTab == WishFeedTab.mine
                                  ? '내가 남긴 소원이 여기에 표시돼요'
                                  : '첫 번째 소원을 남겨보세요',
                            ),
                        ],
                      );
                    }
                    return _PostCard(post: provider.posts[index - 1]);
                  },
                ),
              ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.secondary),
        const SizedBox(width: 6),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

/// [웹→앱 이식] 신통방통 wish.html 출석 스탬프 자리를 대신하는 "오늘 등록된 소원" 요약 스트립
class _WishStatsRow extends StatelessWidget {
  final int todayCount;
  const _WishStatsRow({required this.todayCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            size: 18,
            color: AppColors.secondary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '🌠 소원성 - 당신의 소원이 별이 되는 공간',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Text(
            '오늘 $todayCount개',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// [웹→앱 이식] 신통방통 wish.html "hot-wish-strip" - 인기 소원 가로 스크롤 카드
class _HotWishStrip extends StatelessWidget {
  final List<WishPostModel> wishes;
  const _HotWishStrip({required this.wishes});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: wishes.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final w = wishes[index];
          return Container(
            width: 190,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.goldGlowBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.local_fire_department_rounded,
                      size: 14,
                      color: AppColors.secondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${w.supportCount}',
                      style: Theme.of(context).textTheme.labelMedium
                          ?.copyWith(color: AppColors.secondaryDark),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Text(
                    w.content,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// [웹→앱 이식] 신통방통 wish.html "hall-of-fame-strip" - 응원 많이 받은 작성자 랭킹
class _HallOfFameStrip extends StatelessWidget {
  final List<WishHallOfFameEntry> entries;
  const _HallOfFameStrip({required this.entries});

  static const _medals = ['🥇', '🥈', '🥉'];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: entries.asMap().entries.map((e) {
        final index = e.key;
        final entry = e.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(AppRadius.cardSmall),
            ),
            child: Row(
              children: [
                Text(
                  index < 3 ? _medals[index] : '${index + 1}',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    entry.nickname,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Text(
                  '소원 ${entry.wishCount}개',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '❤️ ${entry.totalSupport}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// [웹→앱 이식] 신통방통 wish.html "행운 룰렷 돌리기 (하루 1회)"
class _LuckyRouletteCard extends StatefulWidget {
  const _LuckyRouletteCard();

  @override
  State<_LuckyRouletteCard> createState() => _LuckyRouletteCardState();
}

class _LuckyRouletteCardState extends State<_LuckyRouletteCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  Future<void> _spin() async {
    final provider = context.read<WishPostProvider>();
    if (!provider.canSpinRoulette) return;
    _spinController.forward(from: 0);
    final result = await provider.spinRoulette();
    if (!mounted || result == null) return;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WishPostProvider>();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: AppColors.purpleGradient,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        children: [
          RotationTransition(
            turns: Tween(begin: 0.0, end: 3.0).animate(
              CurvedAnimation(parent: _spinController, curve: Curves.easeOut),
            ),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.secondary, width: 2),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ElevatedButton.icon(
            onPressed: provider.canSpinRoulette ? _spin : null,
            icon: const Icon(Icons.autorenew_rounded, size: 18),
            label: Text(
              provider.canSpinRoulette ? '룰렷 돌리기 (하루 1회)' : '오늘은 이미 돌렸어요',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: Colors.white,
            ),
          ),
          if (provider.rouletteResult != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.cardSmall),
              ),
              child: Text(
                '"${provider.rouletteResult}"',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
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
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.containerOf(context),
                  child: const Icon(
                    Icons.person,
                    size: 16,
                    color: AppColors.primary,
                  ),
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
                  icon: Icon(
                    Icons.more_vert_rounded,
                    size: 18,
                    color: AppColors.textHintOf(context),
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
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _CategoryBadge(category: post.category),
                // [웹→앱 이식] 신통방통 wish.html 목표태그(goalTag) 뱃지
                if (post.goalTag != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '🎯 ${post.goalTag}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.secondaryDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
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
                              : AppColors.textHintOf(context),
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
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 16,
                  color: AppColors.textHintOf(context),
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
        color: AppColors.containerOf(context),
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
