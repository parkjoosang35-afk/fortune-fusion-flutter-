// SCR-06 탐색 `/explore` (탭2) — docs/SCREENS.md §SCR-06
// 탭(인기순/최신순) + TOP3 카드 + 피드 리스트. 응원 시 하트 연출은 피드카드 탭에서 처리.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../application/wishroom_provider.dart';
import '../../data/models.dart';
import '../../core/theme/wr_theme.dart';
import 'other_room_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  bool _popular = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<WishRoomProvider>().loadExplore());
  }

  @override
  Widget build(BuildContext context) {
    final c = context.wr;
    return Theme(data: wrTheme(WrPalette.midnight), child: Scaffold(
      backgroundColor: c.bg2,
      body: Consumer<WishRoomProvider>(builder: (context, p, __) {
        var feed = [...p.exploreFeed];
        if (_popular) {
          feed.sort((a, b) => (b.supportCount + b.pouchReceived).compareTo(a.supportCount + a.pouchReceived));
        } else {
          feed.sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));
        }
        final top3 = feed.take(3).toList();
        final rest = feed.skip(3).toList();
        return RefreshIndicator(
          onRefresh: () => p.loadExplore(),
          child: CustomScrollView(slivers: [
            SliverToBoxAdapter(child: SafeArea(bottom: false, child: Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 8), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('소원방 탐색', style: WrType.h1(c.fg)),
              const SizedBox(height: 10),
              Row(children: [
                _tab('인기순', true, c),
                const SizedBox(width: 8),
                _tab('최신순', false, c),
              ]),
            ])))),
            if (p.exploreLoading && feed.isEmpty)
              const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: Color(0xFFF5CF6A))))
            else ...[
              if (top3.isNotEmpty) SliverToBoxAdapter(child: SizedBox(height: 180, child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: top3.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) => _TopCard(room: top3[i], rank: i + 1, onTap: () => _open(top3[i])),
              ))),
              SliverPadding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), sliver: SliverList(delegate: SliverChildBuilderDelegate(
                (_, i) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _FeedCard(room: rest[i], onTap: () => _open(rest[i]))),
                childCount: rest.length,
              ))),
            ],
          ]),
        );
      }),
    ));
  }

  Widget _tab(String label, bool popular, WrColors c) {
    final sel = _popular == popular;
    return GestureDetector(onTap: () => setState(() => _popular = popular), child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: sel ? c.accent : c.card, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(color: sel ? Colors.white : c.fg, fontSize: 13)),
    ));
  }

  void _open(WishRoom room) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => OtherRoomScreen(roomId: room.id)));
  }
}

class _TopCard extends StatelessWidget {
  const _TopCard({required this.room, required this.rank, required this.onTap});
  final WishRoom room; final int rank; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.wr;
    final isFirst = rank == 1;
    return GestureDetector(onTap: onTap, child: Container(
      width: 120,
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.line)),
      padding: const EdgeInsets.all(10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 22, height: 22, alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: isFirst ? const LinearGradient(colors: [Color(0xFFFFE7A0), Color(0xFFD9A53A)]) : null,
            color: isFirst ? null : c.bg1, shape: BoxShape.circle),
          child: Text('$rank', style: TextStyle(color: isFirst ? const Color(0xFF4A2A10) : c.fg, fontSize: 12, fontWeight: FontWeight.w700))),
        const SizedBox(height: 8),
        Text('${room.owner}님의 소원방', style: TextStyle(color: c.fg, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(room.text, style: TextStyle(color: c.muted, fontSize: 10), maxLines: 2, overflow: TextOverflow.ellipsis),
        const Spacer(),
        Text('Lv.${room.level}', style: TextStyle(color: c.glow, fontSize: 10)),
      ]),
    ));
  }
}

class _FeedCard extends StatelessWidget {
  const _FeedCard({required this.room, required this.onTap});
  final WishRoom room; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.wr;
    return GestureDetector(onTap: onTap, child: Container(
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.line)),
      padding: const EdgeInsets.all(10),
      child: Row(children: [
        Container(width: 96, height: 112, decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: c.bg1),
          child: const Icon(Icons.local_fire_department, color: Color(0x33FFFFFF), size: 32)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${room.owner}님의 소원방', style: TextStyle(color: c.fg, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(room.text, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, fontSize: 12)),
          const SizedBox(height: 6),
          Text('❤ ${room.supportCount} · 💬 ${room.commentCount} · Lv.${room.level}', style: TextStyle(color: c.muted, fontSize: 11)),
        ])),
      ]),
    ));
  }
}
