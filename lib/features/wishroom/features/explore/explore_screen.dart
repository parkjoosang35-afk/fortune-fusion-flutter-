// SCR-06 탐색 `/explore` (탭2) — docs/SCREENS.md §SCR-06 · app2/screens-b2.jsx › Explore()/FeedCard() 1:1 이식
// 탭(소원방/✨이루어진 이야기) + [인기순|최신순] 칩 + 인기순 TOP3(3열, 1위 금색 뱃지)
// + 피드 리스트(썸네일96×112 + 캐릭터아바타 + 소원빛깔 태그 + 소원 2줄 + ❤·💬·Lv + 응원하기)
// + 응원 시 하트 8개 연출(heart-up 2.2s)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../application/wishroom_provider.dart';
import '../../data/models.dart';
import '../../data/wr_catalog.dart';
import '../../core/theme/wr_theme.dart';
import '../../core/fx/wr_fx.dart';
import '../../core/wr_nav_pill.dart';
import 'other_room_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key, this.initialTab = 'rooms'});
  /// capsule2.jsx `app.go('explore', {tab:'stories'})` — AchieveFlow/ReviewReward에서
  /// "✨ 소원이 이루어진 이야기 보기" 선택 시 stories 탭으로 바로 진입.
  final String initialTab; // rooms | stories
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  late String _etab = widget.initialTab; // rooms | stories
  bool _hot = true; // 인기순(hot) / 최신순(new)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WishRoomProvider>().loadExplore();
      context.read<WishRoomProvider>().loadReviewFeed();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Theme(data: wrThemeData(), child: Scaffold(
      backgroundColor: WrC.bg2,
      body: Consumer<WishRoomProvider>(builder: (context, p, __) {
        List<WishRoom>? sorted;
        if (p.exploreLoading && p.exploreFeed.isEmpty) {
          sorted = null;
        } else {
          sorted = [...p.exploreFeed];
          sorted.sort((a, b) => _hot
              ? b.supportCount.compareTo(a.supportCount)
              : (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));
        }
        return RefreshIndicator(
          onRefresh: () => p.loadExplore(),
          child: CustomScrollView(slivers: [
            SliverToBoxAdapter(child: SafeArea(bottom: false, child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // app2/fx2.jsx › TopBar(title="모두의 소원방") 1:1 — nav 기본값 true로
                // NavPill(뒤로가기+신통방통 홈)이 항상 포함된다.
                // [버그수정 — 전수감사] 기존엔 NavPill이 전혀 없었다.
                Row(children: [
                  WrNavPill(onBack: () => wrBackOrAskExit(context), onExitHome: () => wrExitHome(context)),
                  const SizedBox(width: 10),
                  Text('모두의 소원방', style: WrF.display(22)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  _tab('소원방', 'rooms'),
                  const SizedBox(width: 8),
                  _tab('✨ 이루어진 이야기', 'stories'),
                ]),
              ]),
            ))),
            if (_etab == 'stories')
              ..._storiesSlivers(context, p)
            else
              ..._roomsSlivers(context, sorted),
          ]),
        );
      }),
    ));
  }

  Widget _tab(String label, String v) {
    final sel = _etab == v;
    return GestureDetector(onTap: () => setState(() => _etab = v), child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: sel ? WrDeco.tabOn : WrDeco.chip,
      child: Text(label, style: WrF.body(13, w: FontWeight.w700, color: sel ? Colors.white : WrC.fg)),
    ));
  }

  // ---------------- 소원방(rooms) 탭 ----------------
  List<Widget> _roomsSlivers(BuildContext context, List<WishRoom>? sorted) {
    if (sorted == null) {
      return [const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: Color(0xFFF5CF6A))))];
    }
    return [
      SliverToBoxAdapter(child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
        child: Row(children: [
          _sortChip('인기순', true),
          const SizedBox(width: 6),
          _sortChip('최신순', false),
        ]),
      )),
      if (sorted.isNotEmpty && _hot) SliverToBoxAdapter(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          for (var i = 0; i < 3 && i < sorted.length; i++) Expanded(child: Padding(
            padding: EdgeInsets.only(right: i < 2 ? 8 : 0, bottom: 16),
            child: _TopCard(room: sorted[i], rank: i + 1, onTap: () => _open(sorted[i])),
          )),
        ]),
      )),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        sliver: SliverList(delegate: SliverChildBuilderDelegate((context, i) {
          final rest = _hot ? sorted.skip(3).toList() : sorted;
          if (rest.isEmpty) {
            return const Padding(padding: EdgeInsets.only(top: 40), child: Center(
              child: Text('아직 소원방이 없어요', style: TextStyle(color: WrC.muted))));
          }
          return Padding(padding: const EdgeInsets.only(bottom: 12), child: _FeedCard(room: rest[i], onTap: () => _open(rest[i])));
        }, childCount: (_hot ? (sorted.length - 3).clamp(0, 1 << 30) : sorted.length).clamp(1, 1 << 30))),
      ),
    ];
  }

  Widget _sortChip(String label, bool hot) {
    final sel = _hot == hot;
    return GestureDetector(onTap: () => setState(() => _hot = hot), child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: sel ? WrDeco.chipOn : WrDeco.chip,
      child: Text(label, style: WrF.body(12, w: FontWeight.w700, color: sel ? Colors.white : WrC.fg)),
    ));
  }

  void _open(WishRoom room) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => OtherRoomScreen(roomId: room.id)));
  }

  // ---------------- ✨ 이루어진 이야기(stories) 탭 ----------------
  List<Widget> _storiesSlivers(BuildContext context, WishRoomProvider p) {
    final list = p.reviewFeed;
    return [
      SliverToBoxAdapter(child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          decoration: WrDeco.panel,
          child: Column(children: [
            Text('✨ 소원이 이루어진 이야기', style: WrF.display(18), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text('봉인했던 소원이 현실이 된 순간들', style: WrF.body(12.5, color: WrC.muted), textAlign: TextAlign.center),
          ]),
        ),
      )),
      if (list.isEmpty)
        const SliverFillRemaining(child: Center(child: Text('아직 나눠진 이야기가 없어요', style: TextStyle(color: WrC.muted))))
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          sliver: SliverList(delegate: SliverChildBuilderDelegate((context, i) =>
            Padding(padding: const EdgeInsets.only(bottom: 10), child: _StoryCard(v: list[i])),
            childCount: list.length,
          )),
        ),
    ];
  }
}

class _TopCard extends StatelessWidget {
  const _TopCard({required this.room, required this.rank, required this.onTap});
  final WishRoom room; final int rank; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final isFirst = rank == 1;
    return GestureDetector(onTap: onTap, child: Container(
      decoration: WrDeco.card,
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Stack(children: [
          Container(height: 90, color: WrC.bg1, child: const Center(child: Icon(Icons.local_fire_department, color: Color(0x33FFFFFF), size: 28))),
          Positioned(top: 6, left: 6, child: Container(width: 22, height: 22, alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: isFirst ? const LinearGradient(colors: [Color(0xFFFFE7A0), Color(0xFFD9A53A)]) : null,
              color: isFirst ? null : WrC.blossom, shape: BoxShape.circle,
              boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8)]),
            child: Text('$rank', style: WrF.body(11, w: FontWeight.w900, color: isFirst ? const Color(0xFF4A2A10) : Colors.white)))),
        ]),
        Padding(padding: const EdgeInsets.fromLTRB(8, 7, 8, 9), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(room.owner, style: WrF.body(11.5, w: FontWeight.w700, color: WrC.fg), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text('❤ ${room.supportCount}', style: WrF.body(10.5, color: WrC.blossom2)),
        ])),
      ]),
    ));
  }
}

class _FeedCard extends StatefulWidget {
  const _FeedCard({required this.room, required this.onTap});
  final WishRoom room; final VoidCallback onTap;
  @override
  State<_FeedCard> createState() => _FeedCardState();
}

class _FeedCardState extends State<_FeedCard> {
  late WishRoom _room = widget.room;
  int _heartKey = 0;

  Future<void> _cheer() async {
    final p = context.read<WishRoomProvider>();
    final reward = await p.support(_room.id);
    if (!mounted) return;
    if (p.lastError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(p.lastError!.message)));
      return;
    }
    final fresh = p.exploreFeed.where((r) => r.id == _room.id).toList();
    setState(() { if (fresh.isNotEmpty) _room = fresh.first; _heartKey++; });
    if (reward != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('응원 ${reward['at']}회 · ${reward['reward']}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cat = WrCatalog.I;
    final room = _room;
    final wc = cat.wishColors.where((c) => c['id'] == room.wishColor).toList();
    final W = wc.isNotEmpty ? wc.first : null;
    return GestureDetector(onTap: widget.onTap, child: Container(
      decoration: WrDeco.card,
      padding: const EdgeInsets.all(10),
      child: Stack(clipBehavior: Clip.none, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(borderRadius: BorderRadius.circular(12), child: Container(width: 96, height: 112, color: WrC.bg1,
            child: const Center(child: Icon(Icons.local_fire_department, color: Color(0x33FFFFFF), size: 32)))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 30, height: 30, decoration: BoxDecoration(shape: BoxShape.circle, color: WrC.bg1,
                border: Border.all(color: WrC.blossom2, width: 1.5)),
                child: const Icon(Icons.person, size: 16, color: WrC.muted)),
              const SizedBox(width: 8),
              Expanded(child: Text('${room.owner}님의 소원방', style: WrF.body(13, w: FontWeight.w700, color: WrC.fg), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
            if (W != null) Padding(padding: const EdgeInsets.only(top: 5), child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(999),
                color: _hex(W['color'] as String).withValues(alpha: .094),
                border: Border.all(color: _hex(W['color'] as String).withValues(alpha: .47))),
              child: Text('${W['hanja']} · ${W['label']}', style: WrF.body(10, w: FontWeight.w700, color: _hex(W['color'] as String))),
            )),
            const SizedBox(height: 5),
            Text(room.text, maxLines: 2, overflow: TextOverflow.ellipsis, style: WrF.body(12.5, color: const Color(0xD9FFF0E6), height: 1.3)),
            const SizedBox(height: 8),
            Row(children: [
              Text('❤ ${room.supportCount}', style: WrF.body(11.5, color: WrC.blossom2)),
              const SizedBox(width: 10),
              Text('💬 ${room.commentCount}', style: WrF.body(11.5, color: WrC.muted)),
              const SizedBox(width: 10),
              Text('Lv.${room.level}', style: WrF.body(11.5, color: WrC.muted)),
              const Spacer(),
              GestureDetector(onTap: room.supportedToday ? null : _cheer, child: Container(
                height: 30, padding: const EdgeInsets.symmetric(horizontal: 12), alignment: Alignment.center,
                decoration: room.supportedToday ? WrDeco.btnDark : WrDeco.btnPink,
                child: Text(room.supportedToday ? '응원함' : '응원하기', style: WrF.body(12, w: FontWeight.w700, color: Colors.white)),
              )),
            ]),
          ])),
        ]),
        if (_heartKey > 0) Positioned(right: 20, top: 30, child: WrHearts(key: ValueKey(_heartKey), x: 0, y: 0, n: 8)),
      ]),
    ));
  }
}

class _StoryCard extends StatefulWidget {
  const _StoryCard({required this.v});
  final WrReview v;
  @override
  State<_StoryCard> createState() => _StoryCardState();
}

class _StoryCardState extends State<_StoryCard> {
  late WrReview _v = widget.v;
  int _pop = 0;

  Future<void> _congrats() async {
    if (_v.mine) return;
    final p = context.read<WishRoomProvider>();
    final ok = await p.congrats(_v.id);
    if (!mounted) return;
    if (ok) {
      final fresh = p.reviewFeed.where((r) => r.id == _v.id).toList();
      setState(() { if (fresh.isNotEmpty) _v = fresh.first; _pop++; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cat = WrCatalog.I;
    final wc = cat.wishColors.where((c) => c['id'] == _v.wishColor).toList();
    final color = wc.isNotEmpty ? _hex(wc.first['color'] as String) : const Color(0xFFFFF0D8);
    return Container(
      decoration: WrDeco.card,
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Stack(children: [
        Positioned(right: -30, top: -30, child: Container(width: 120, height: 120,
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [color.withValues(alpha: .2), Colors.transparent])))),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('🔓 소원 봉인 해제', style: WrF.body(11, w: FontWeight.w700, color: WrC.muted)),
          ]),
          const SizedBox(height: 8),
          Text('"${_v.wishText}"', style: WrF.body(15, w: FontWeight.w700, color: WrC.fg, height: 1.5)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(999),
              gradient: const LinearGradient(colors: [Color(0x33F5CF6A), Color(0x26FF8FB1)]),
              border: Border.all(color: const Color(0x66F5CF6A))),
            child: Text('💛 소원이 이루어졌어요', style: WrF.body(11.5, w: FontWeight.w700, color: const Color(0xFFFFE08A))),
          ),
          if (_v.photo != null) Padding(padding: const EdgeInsets.only(top: 10), child: ClipRRect(borderRadius: BorderRadius.circular(12),
            child: Image.network(_v.photo!, width: double.infinity, height: 170, fit: BoxFit.cover))),
          const SizedBox(height: 10),
          Text('"${_v.text}"', style: WrF.body(13.5, color: const Color(0xE6FFF0E4), height: 1.75)),
          const SizedBox(height: 12),
          Row(children: [
            Text('${_v.author}${_v.mine ? ' · 나' : ''}', style: WrF.body(11.5, color: WrC.muted)),
            const Spacer(),
            GestureDetector(onTap: _v.mine ? null : _congrats, child: Opacity(opacity: _v.mine ? .6 : 1, child: Stack(clipBehavior: Clip.none, children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(999),
                  gradient: _v.congratsByMe ? const LinearGradient(colors: [Color(0xFFFF9CBC), Color(0xFFF2628F)]) : null,
                  color: _v.congratsByMe ? null : const Color(0x14FFFFFF),
                  border: _v.congratsByMe ? null : Border.all(color: const Color(0x73FF8FB1))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Text('❤', style: TextStyle(color: Colors.white, fontSize: 12)),
                  const SizedBox(width: 5),
                  Text('축하해요 ${_v.congrats}', style: WrF.body(12, w: FontWeight.w700, color: Colors.white)),
                ]),
              ),
              if (_pop > 0) Positioned(right: 0, top: 0, child: WrHearts(key: ValueKey(_pop), x: 0, y: 0, n: 6)),
            ]))),
          ]),
        ]),
      ]),
    );
  }
}

Color _hex(String h) => Color(int.parse('FF${h.replaceFirst('#', '')}', radix: 16));
