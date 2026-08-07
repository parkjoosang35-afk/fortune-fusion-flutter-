import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_unified_style.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_toast.dart';
import '../application/wish_post_provider.dart';
import '../application/wish_castle_config_provider.dart';
import '../domain/wish_post_model.dart';
import 'widgets/wish_castle_intro_screen.dart';
import 'widgets/wish_hall_of_fame_sheet.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      context.read<WishPostProvider>().loadFeed();
      context.read<WishPostProvider>().checkRouletteAvailability();
      // [소원성(Wish Castle) 확장] 촛불 레벨 임계값 등 CMS 설정을 커뮤니티 탭
      // 진입 시 1회 로드(이미 로드되어 있으면 재호출해도 가벼운 GET 1회일 뿐이라 무해).
      context.read<WishCastleConfigProvider>().loadConfig();
      // [소원성(Wish Castle) 확장] 소원성 인트로 + 온보딩 - 최초 1회만 노출.
      if (mounted) await showWishCastleIntroIfNeeded(context);
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
                spacing: UnifiedTokens.spaceSm,
                runSpacing: UnifiedTokens.spaceSm,
                children: _wishCategories.map((c) {
                  final selected = category == c;
                  return ChoiceChip(
                    label: Text(c, style: UnifiedText.chipLabel()),
                    selected: selected,
                    onSelected: (_) => setSheetState(() => category = c),
                    backgroundColor: UnifiedColors.chipInactiveBg,
                    selectedColor: UnifiedColors.cardAllMenu,
                    side: BorderSide.none,
                  );
                }).toList(),
              ),
              const SizedBox(height: UnifiedTokens.spaceMd),
              TextField(
                controller: controller,
                maxLines: 4,
                decoration: const InputDecoration(hintText: '이루고 싶은 소원을 적어보세요'),
              ),
              const SizedBox(height: UnifiedTokens.spaceMd),
              // [웹→앱 이식] 신통방통 wish.html "같은 목표를 가진 사람과 함께 응원받기(선택)"
              Text('같은 목표를 가진 사람과 함께 응원받기(선택)', style: UnifiedText.caption()),
              const SizedBox(height: UnifiedTokens.spaceSm),
              Wrap(
                spacing: UnifiedTokens.spaceSm,
                runSpacing: UnifiedTokens.spaceSm,
                children: _goalTags.map((tag) {
                  final selected = goalTag == tag;
                  return ChoiceChip(
                    label: Text(tag, style: UnifiedText.chipLabel()),
                    selected: selected,
                    onSelected: (_) =>
                        setSheetState(() => goalTag = selected ? null : tag),
                    backgroundColor: UnifiedColors.chipInactiveBg,
                    selectedColor: UnifiedColors.cardAllMenu,
                    side: BorderSide.none,
                  );
                }).toList(),
              ),
              const SizedBox(height: UnifiedTokens.spaceSm),
              CheckboxListTile(
                value: isAnonymous,
                onChanged: (v) => setSheetState(() => isAnonymous = v ?? false),
                title: const Text('익명으로 작성'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: UnifiedTokens.spaceMd),
              AppButton(
                label: '소원 빌고 등록하기',
                onPressed: () async {
                  // [3단계 - 복주머니 커뮤니티 적립 연동] 성공 시 서버가 지급한
                  // rewardPoint(int)를 받는다. null이면 실패.
                  final rewardPoint = await context
                      .read<WishPostProvider>()
                      .createPost(
                        controller.text,
                        category: category,
                        isAnonymous: isAnonymous,
                        goalTag: goalTag,
                      );
                  if (rewardPoint == null) return;
                  if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                  if (rewardPoint > 0 && context.mounted) {
                    AppToast.show(context, '소원 등록 완료! 복주머니 $rewardPoint개 획득');
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
      backgroundColor: UnifiedColors.bg,
      appBar: AppBar(
        backgroundColor: UnifiedColors.bg,
        elevation: 0,
        title: Text('소원게시판', style: UnifiedText.titleLarge()),
        actions: [
          // 02§12 리워드 커뮤니티(자유게시판) 진입점 - Phase16, 기존 소원게시판 로직은 변경하지 않음
          IconButton(
            tooltip: '커뮤니티 게시판',
            icon: Icon(Icons.forum_outlined, color: UnifiedColors.textPrimary),
            onPressed: () =>
                Navigator.of(context).pushNamed('/community/board/list'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: UnifiedColors.textPrimary,
          unselectedLabelColor: UnifiedColors.textCaption,
          indicatorColor: UnifiedColors.black,
          labelStyle: UnifiedText.bodyStrong(),
          tabs: const [
            Tab(text: '전체'),
            Tab(text: '인기'),
            Tab(text: '내소원'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openWriteSheet,
        backgroundColor: UnifiedColors.black,
        child: const Icon(Icons.edit_rounded, color: Colors.white),
      ),
      body: SafeArea(
        child: provider.isLoading && provider.posts.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: () => context.read<WishPostProvider>().loadFeed(),
                child: ListView.separated(
                  padding: const EdgeInsets.all(UnifiedTokens.spaceXl),
                  itemCount: provider.posts.length + 1,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: UnifiedTokens.spaceMd),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _WishStatsRow(todayCount: provider.todayCount),
                          const SizedBox(height: UnifiedTokens.spaceXl),
                          if (provider.hotWishes.isNotEmpty) ...[
                            _SectionHeader(
                              icon: Icons.local_fire_department_rounded,
                              title: '오늘의 인기 소원',
                            ),
                            const SizedBox(height: UnifiedTokens.spaceSm),
                            _HotWishStrip(wishes: provider.hotWishes),
                            const SizedBox(height: UnifiedTokens.spaceXl),
                          ],
                          if (provider.hallOfFame.isNotEmpty) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: _SectionHeader(
                                    icon: Icons.emoji_events_rounded,
                                    title: '소원성 명예의 전당',
                                  ),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      showWishHallOfFameSheet(context),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 0),
                                  ),
                                  child: Text(
                                    '전체보기',
                                    style: UnifiedText.caption(),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: UnifiedTokens.spaceSm),
                            _HallOfFameStrip(entries: provider.hallOfFame),
                            const SizedBox(height: UnifiedTokens.spaceXl),
                          ],
                          _SectionHeader(
                            icon: Icons.blur_circular_rounded,
                            title: '오늘의 행운 룰렷',
                          ),
                          const SizedBox(height: UnifiedTokens.spaceSm),
                          const _LuckyRouletteCard(),
                          const SizedBox(height: UnifiedTokens.spaceXl),
                          _SectionHeader(
                            icon: Icons.favorite_rounded,
                            title: '함께 응원하기',
                          ),
                          const SizedBox(height: UnifiedTokens.spaceSm),
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
        Icon(
          icon,
          size: UnifiedTokens.iconMd,
          color: UnifiedColors.textPrimary,
        ),
        const SizedBox(width: UnifiedTokens.spaceSm),
        Text(title, style: UnifiedText.title()),
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
        horizontal: UnifiedTokens.spaceXl,
        vertical: UnifiedTokens.spaceMd,
      ),
      decoration: BoxDecoration(
        color: UnifiedColors.cardSection,
        borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            size: UnifiedTokens.iconMd,
            color: UnifiedColors.textPrimary,
          ),
          const SizedBox(width: UnifiedTokens.spaceSm),
          Expanded(
            child: Text(
              '🌠 소원성 - 당신의 소원이 별이 되는 공간',
              style: UnifiedText.bodySmall(),
            ),
          ),
          Text(
            '오늘 $todayCount개',
            style: UnifiedText.bodySmall(
              color: UnifiedColors.textPrimary,
            ).copyWith(fontWeight: FontWeight.w700),
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
        separatorBuilder: (_, __) =>
            const SizedBox(width: UnifiedTokens.spaceSm),
        itemBuilder: (context, index) {
          final w = wishes[index];
          return Container(
            width: 190,
            padding: const EdgeInsets.all(UnifiedTokens.spaceMd),
            decoration: BoxDecoration(
              color: UnifiedColors.cardSection,
              borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
              border: Border.all(color: UnifiedColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.local_fire_department_rounded,
                      size: UnifiedTokens.iconSm,
                      color: UnifiedColors.textPrimary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${w.supportCount}',
                      style: UnifiedText.bodyStrong(
                        color: UnifiedColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Text(
                    w.content,
                    style: UnifiedText.bodySmall(),
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
          padding: const EdgeInsets.only(bottom: UnifiedTokens.spaceSm),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: UnifiedTokens.spaceMd,
              vertical: UnifiedTokens.spaceSm,
            ),
            decoration: BoxDecoration(
              color: UnifiedColors.cardSection,
              borderRadius: BorderRadius.circular(UnifiedTokens.radiusSm),
            ),
            child: Row(
              children: [
                Text(
                  index < 3 ? _medals[index] : '${index + 1}',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(width: UnifiedTokens.spaceSm),
                Expanded(
                  child: Text(
                    entry.nickname,
                    style: UnifiedText.body(color: UnifiedColors.textPrimary),
                  ),
                ),
                Text(
                  '소원 ${entry.wishCount}개',
                  style: UnifiedText.bodySmall(
                    color: UnifiedColors.textSecondary,
                  ),
                ),
                const SizedBox(width: UnifiedTokens.spaceSm),
                Text(
                  '❤️ ${entry.totalSupport}',
                  style: UnifiedText.bodySmall(
                    color: UnifiedColors.textPrimary,
                  ).copyWith(fontWeight: FontWeight.w700),
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
      padding: const EdgeInsets.all(UnifiedTokens.spaceXl),
      decoration: BoxDecoration(
        color: UnifiedColors.cardAllMenu,
        borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
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
                color: UnifiedColors.bg,
                shape: BoxShape.circle,
                border: Border.all(color: UnifiedColors.border),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: UnifiedColors.black,
                size: 26,
              ),
            ),
          ),
          const SizedBox(height: UnifiedTokens.spaceMd),
          ElevatedButton.icon(
            onPressed: provider.canSpinRoulette ? _spin : null,
            icon: const Icon(Icons.autorenew_rounded, size: 18),
            label: Text(
              provider.canSpinRoulette ? '룰렷 돌리기 (하루 1회)' : '오늘은 이미 돌렸어요',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: UnifiedColors.black,
              foregroundColor: Colors.white,
            ),
          ),
          if (provider.rouletteResult != null) ...[
            const SizedBox(height: UnifiedTokens.spaceMd),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(UnifiedTokens.spaceMd),
              decoration: BoxDecoration(
                color: UnifiedColors.bg,
                borderRadius: BorderRadius.circular(UnifiedTokens.radiusSm),
                border: Border.all(color: UnifiedColors.border),
              ),
              child: Text(
                '"${provider.rouletteResult}"',
                textAlign: TextAlign.center,
                style: UnifiedText.body(
                  color: UnifiedColors.textPrimary,
                ).copyWith(fontStyle: FontStyle.italic, height: 1.4),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// [소원성(Wish Castle) 확장] 촛불 레벨 아이콘 + 진행바 - 게시글 카드/상세화면 공용.
/// 미니멀 원칙(마스터 기획 §UI 디자인 원칙 화이트 미니멀)에 따라 이모지 1개 + 얇은
/// 프로그레스바만으로 성장 상태를 표현하고, 화려한 연출은 별도 애니메이션 위젯(성장/
/// 레벨업 연출)에서만 터뜨린다. 카드 자체는 항상 심플하게 유지한다.
class WishCandleBadge extends StatelessWidget {
  final WishPostModel post;
  final bool compact;
  const WishCandleBadge({super.key, required this.post, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WishCastleConfigProvider>();
    final meta = wishCandleLevelOf(post.candleLevel);
    final progress = provider.isLoaded
        ? provider.progressWithinLevel(post.bokjuCount, post.candleLevel)
        : (post.isMaxLevel ? 1.0 : 0.0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(meta.emoji, style: TextStyle(fontSize: compact ? 13 : 15)),
        const SizedBox(width: 4),
        if (!compact)
          Text(
            meta.name,
            style: UnifiedText.caption(
              color: UnifiedColors.textPrimary,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
        const SizedBox(width: 6),
        SizedBox(
          width: compact ? 44 : 64,
          height: 5,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: UnifiedColors.border,
              valueColor: const AlwaysStoppedAnimation(UnifiedColors.black),
            ),
          ),
        ),
        if (!compact) ...[
          const SizedBox(width: 6),
          Text('🧧 ${post.bokjuCount}', style: UnifiedText.caption()),
        ],
      ],
    );
  }
}

class _PostCard extends StatelessWidget {
  final WishPostModel post;
  const _PostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
      onTap: () => Navigator.of(
        context,
      ).pushNamed('/community/wish/detail', arguments: post),
      child: Container(
        padding: const EdgeInsets.all(UnifiedTokens.spaceXl),
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
                  child: const Icon(
                    Icons.person,
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
                WishCandleBadge(post: post, compact: true),
                const SizedBox(width: UnifiedTokens.spaceSm),
                Text(
                  '${post.createdAt.month}.${post.createdAt.day}',
                  style: UnifiedText.caption(),
                ),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    size: 18,
                    color: UnifiedColors.textCaption,
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
            const SizedBox(height: UnifiedTokens.spaceSm),
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
                      color: UnifiedColors.cardAllMenu,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '🎯 ${post.goalTag}',
                      style: UnifiedText.chipLabel(),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: UnifiedTokens.spaceMd),
            Text(
              post.content,
              style: UnifiedText.body(color: UnifiedColors.textPrimary),
            ),
            const SizedBox(height: UnifiedTokens.spaceMd),
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
                              ? UnifiedColors.black
                              : UnifiedColors.textCaption,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${post.supportCount}',
                          style: UnifiedText.bodySmall(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: UnifiedTokens.spaceXl),
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 16,
                  color: UnifiedColors.textCaption,
                ),
                const SizedBox(width: 4),
                Text('${post.commentCount}', style: UnifiedText.bodySmall()),
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
        color: UnifiedColors.cardAllMenu,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(category, style: UnifiedText.chipLabel()),
    );
  }
}
