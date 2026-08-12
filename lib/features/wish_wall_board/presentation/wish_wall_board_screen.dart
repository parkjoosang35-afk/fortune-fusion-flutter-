import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../application/wish_wall_provider.dart';
import '../domain/wish_wall_models.dart';
import '../theme/wish_wall_theme.dart';
import '../widgets/bottle_widget.dart';
import '../widgets/wish_wall_ambient_fx.dart';
import 'wish_wall_compose_screen.dart';
import 'wish_wall_detail_screen.dart';
import 'wish_wall_my_screen.dart';

/// 01. 신통방통 소원방(소원벽게시판) — 병 벽(피드) 화면.
///
/// [handoff.zip] design/wb3-wall.jsx `BottleWall`을 Flutter로 이식.
/// Instagram/Threads 감성의 큰 카드 피드 + 세그먼트 탭(전체/인기/최신) +
/// 카테고리 칩 + "오늘의 공동소원" 스토리 로우로 구성된다.
class WishWallBoardScreen extends StatefulWidget {
  const WishWallBoardScreen({super.key});

  @override
  State<WishWallBoardScreen> createState() => _WishWallBoardScreenState();
}

enum _FeedTab { all, popular, latest }

class _WishWallBoardScreenState extends State<WishWallBoardScreen> {
  _FeedTab _tab = _FeedTab.all;
  WishCategory? _category;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<WishWallProvider>().ensureLoaded();
    });
  }

  List<WishPost> _applyFilters(List<WishPost> source) {
    var list = List<WishPost>.of(source);
    if (_category != null) {
      list = list.where((w) => w.categoryId == _category).toList();
    }
    switch (_tab) {
      case _FeedTab.all:
        break;
      case _FeedTab.popular:
        list.sort((a, b) => b.supportCount.compareTo(a.supportCount));
        break;
      case _FeedTab.latest:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }
    return list;
  }

  void _openDetail(WishPost wish) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WishWallDetailScreen(wishId: wish.id)),
    );
  }

  void _openCompose() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const WishWallComposeScreen()),
    );
  }

  void _openMy() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const WishWallMyScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WishWallProvider>();
    final list = _applyFilters(provider.feed);

    return Scaffold(
      backgroundColor: WishWallColors.bg,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            const Positioned.fill(child: WishWallAmbientBackground()),
            CustomScrollView(
              slivers: [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _WallHeaderDelegate(
                    tab: _tab,
                    onTabChanged: (t) => setState(() => _tab = t),
                    onOpenMy: _openMy,
                  ),
                ),
                SliverToBoxAdapter(child: _TodayCollectiveRow()),
                SliverToBoxAdapter(
                  child: _CategoryChipRow(
                    selected: _category,
                    onSelect: (c) => setState(() => _category = c),
                  ),
                ),
                if (provider.isLoading && list.isEmpty)
                  const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: WishWallColors.accent,
                      ),
                    ),
                  )
                else if (list.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                        child: Text(
                          '이 카테고리엔 아직 병이 없어요',
                          style: WishWallText.body(color: WishWallColors.muted),
                        ),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _BottlePostCard(
                        wish: list[index],
                        showBorderTop: index > 0,
                        onOpen: () => _openDetail(list[index]),
                      ),
                      childCount: list.length,
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 110)),
              ],
            ),
            Positioned(
              right: 20,
              bottom: 24,
              child: _ComposeFab(onPressed: _openCompose),
            ),
          ],
        ),
      ),
    );
  }
}

class _WallHeaderDelegate extends SliverPersistentHeaderDelegate {
  _WallHeaderDelegate({
    required this.tab,
    required this.onTabChanged,
    required this.onOpenMy,
  });

  final _FeedTab tab;
  final ValueChanged<_FeedTab> onTabChanged;
  final VoidCallback onOpenMy;

  static const double _height = 96;

  @override
  double get minExtent => _height;
  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: WishWallColors.bg.withValues(alpha: 0.94),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('신통방통 소원방', style: WishWallText.title2()),
              ),
              IconButton(
                onPressed: onOpenMy,
                icon: const Icon(
                  Icons.person_outline_rounded,
                  color: WishWallColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _SegTab(
                label: '전체',
                active: tab == _FeedTab.all,
                onTap: () => onTabChanged(_FeedTab.all),
              ),
              const SizedBox(width: 20),
              _SegTab(
                label: '인기',
                active: tab == _FeedTab.popular,
                onTap: () => onTabChanged(_FeedTab.popular),
              ),
              const SizedBox(width: 20),
              _SegTab(
                label: '최신',
                active: tab == _FeedTab.latest,
                onTap: () => onTabChanged(_FeedTab.latest),
              ),
            ],
          ),
          Container(height: 1, color: WishWallColors.line),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _WallHeaderDelegate oldDelegate) {
    return oldDelegate.tab != tab;
  }
}

class _SegTab extends StatelessWidget {
  const _SegTab({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 4),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: WishWallText.family,
                fontSize: 15,
                fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                letterSpacing: -0.3,
                color: active ? WishWallColors.ink : WishWallColors.muted,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 24,
              height: 3,
              decoration: BoxDecoration(
                color: active ? WishWallColors.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayCollectiveRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: WishWallColors.line)),
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      WishWallColors.accentSoft,
                      WishWallColors.bg,
                    ],
                  ),
                  border: Border.all(color: WishWallColors.accent, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: WishWallColors.accent.withValues(alpha: 0.28),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: Transform.scale(
                    scale: 0.35,
                    child: BottleWidget(
                      category: WishCategory.exam,
                      size: 100,
                      glow: 1,
                      sealed: false,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: WishWallColors.accent,
                    border: Border.all(color: WishWallColors.bg, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TODAY', style: WishWallText.mono()),
                const SizedBox(height: 2),
                Text(
                  '오늘은 모두의 건강을 빌어요',
                  style: WishWallText.body().copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '1,284 명이 함께 담고 있어요',
                  style: WishWallText.caption(),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: WishWallColors.ink,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '함께',
              style: WishWallText.label(color: WishWallColors.bg),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChipRow extends StatelessWidget {
  const _CategoryChipRow({required this.selected, required this.onSelect});
  final WishCategory? selected;
  final ValueChanged<WishCategory?> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
        children: [
          _CategoryChip(
            label: '전체',
            active: selected == null,
            onTap: () => onSelect(null),
          ),
          const SizedBox(width: 6),
          ...WishCategory.values.expand((c) => [
                _CategoryChip(
                  label: c.label,
                  active: selected == c,
                  onTap: () => onSelect(c),
                ),
                const SizedBox(width: 6),
              ]),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? WishWallColors.ink : WishWallColors.bg2,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? WishWallColors.ink : WishWallColors.line,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: WishWallText.family,
            fontSize: 13,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: -0.2,
            color: active ? WishWallColors.bg : WishWallColors.ink2,
          ),
        ),
      ),
    );
  }
}

class _BottlePostCard extends StatefulWidget {
  const _BottlePostCard({
    required this.wish,
    required this.showBorderTop,
    required this.onOpen,
  });
  final WishPost wish;
  final bool showBorderTop;
  final VoidCallback onOpen;

  @override
  State<_BottlePostCard> createState() => _BottlePostCardState();
}

class _BottlePostCardState extends State<_BottlePostCard> {
  bool _burst = false;

  Future<void> _doSupport() async {
    final wish = widget.wish;
    if (wish.hasSupportedByMe) return;
    setState(() => _burst = true);
    await context.read<WishWallProvider>().support(wish.id);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final wish = widget.wish;
    final cork = wish.categoryId.corkColor;

    return InkWell(
      onTap: widget.onOpen,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        decoration: BoxDecoration(
          border: widget.showBorderTop
              ? const Border(top: BorderSide(color: WishWallColors.line))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: wish.isAnonymous
                        ? WishWallColors.bg3
                        : WishWallColors.accentSoft,
                    border: Border.all(color: WishWallColors.line),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    wish.isAnonymous ? '?' : wish.authorAvatarEmoji,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            wish.displayName,
                            style: WishWallText.body().copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '· ${_timeAgo(wish.createdAt)}',
                            style: WishWallText.caption(),
                          ),
                        ],
                      ),
                      Text(
                        '#${wish.categoryId.label}',
                        style: WishWallText.caption(),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.more_horiz,
                  color: WishWallColors.ink.withValues(alpha: 0.6),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 76,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.topCenter,
                    children: [
                      BottleWidget(
                        category: wish.categoryId,
                        size: 76,
                        glow: wish.glow,
                      ),
                      BottleRibbons(count: wish.ribbonCount, color: cork),
                      BottleLeaves(count: wish.leafCount),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    wish.text,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: WishWallText.body().copyWith(height: 1.55),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _ActionPill(
                  active: wish.hasSupportedByMe,
                  onTap: _doSupport,
                  icon: wish.hasSupportedByMe
                      ? Icons.favorite
                      : Icons.favorite_border,
                  label: _fmtCount(wish.supportCount),
                  color: WishWallColors.red,
                  showBurst: _burst,
                ),
                _ActionPill(
                  icon: Icons.chat_bubble_outline,
                  label: _fmtCount(0),
                ),
                _ActionPill(
                  icon: Icons.auto_awesome,
                  label: _fmtCount(wish.prayerCount),
                ),
                const Spacer(),
                InkWell(
                  onTap: widget.onOpen,
                  borderRadius: BorderRadius.circular(17),
                  child: Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: WishWallColors.accentSoft,
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(color: WishWallColors.accent),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '✨ 복주머니',
                      style: WishWallText.label(color: WishWallColors.accent2),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
    this.color,
    this.showBurst = false,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;
  final Color? color;
  final bool showBurst;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: active ? color : WishWallColors.ink,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: WishWallText.family,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: active ? color : WishWallColors.ink,
                  ),
                ),
              ],
            ),
          ),
          if (showBurst)
            Positioned(
              left: 10,
              top: 2,
              child: _FloatHeart(color: color ?? WishWallColors.red),
            ),
        ],
      ),
    );
  }
}

class _FloatHeart extends StatefulWidget {
  const _FloatHeart({required this.color});
  final Color color;

  @override
  State<_FloatHeart> createState() => _FloatHeartState();
}

class _FloatHeartState extends State<_FloatHeart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return Opacity(
          opacity: (1 - t).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(6 * t, -26 * t),
            child: Transform.scale(
              scale: 1 + 0.5 * t,
              child: Icon(Icons.favorite, size: 14, color: widget.color),
            ),
          ),
        );
      },
    );
  }
}

class _ComposeFab extends StatelessWidget {
  const _ComposeFab({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(26),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          color: WishWallColors.accent,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: WishWallColors.accent.withValues(alpha: 0.42),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('새 소원', style: WishWallText.label(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

String _fmtCount(int n) {
  if (n < 1000) return '$n';
  if (n < 10000) return '${(n / 1000).toStringAsFixed(1)}k';
  return '${(n / 1000).round()}k';
}

String _timeAgo(DateTime time) {
  final diff = DateTime.now().difference(time);
  final mins = diff.inMinutes;
  if (mins < 1) return '방금';
  if (mins < 60) return '${mins}분';
  if (mins < 60 * 24) return '${diff.inHours}시간';
  return '${diff.inDays}일';
}
