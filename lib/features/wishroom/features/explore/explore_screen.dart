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
import '../room/room_scene.dart';
import '../review/review_write_screen.dart';
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
  // app2/review2.jsx › Stories() `const [tab, setTab] = useState('all')` 1:1 —
  // [버그수정 — 전수감사] 기존엔 '나의 이야기' 탭 자체가 없어 reviewFeed(= all)만 보여줬다.
  String _storyTab = 'all'; // all | mine

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WishRoomProvider>().loadExplore();
      context.read<WishRoomProvider>().loadReviewFeed();
    });
  }

  void _setStoryTab(String v) {
    setState(() => _storyTab = v);
    final p = context.read<WishRoomProvider>();
    // app2/review2.jsx › Stories() `React.useEffect(load, [tab])` 1:1 — 탭 전환 시 재조회.
    if (v == 'mine') {
      p.loadMyReviews();
    } else {
      p.loadReviewFeed();
    }
  }

  Future<void> _openWrite({WrReview? edit}) async {
    final room = context.read<WishRoomProvider>().room;
    if (room == null) return;
    final result = await Navigator.of(context).push<Object?>(MaterialPageRoute(builder: (_) => ReviewWriteScreen(room: room, edit: edit)));
    if (!mounted) return;
    final p = context.read<WishRoomProvider>();
    if (edit != null) {
      // 고치기 완료(WrReview 반환) — 나의 이야기 탭 최신화.
      if (result is WrReview) p.loadMyReviews();
    } else if (result != null) {
      // 신규 작성 완료("next"/"stories") — 두 탭 모두 최신화.
      p.loadMyReviews();
      p.loadReviewFeed();
    }
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
        // app2/fx2.jsx › TopBar(title="모두의 소원방") 1:1 — top:52 고정(화면 폭 기준
        // 중앙정렬 제목) + `.scroll{padding-top:100}` 즉 TopBar는 스크롤되지 않고
        // 탭/칩/TOP3/피드만 그 아래에서 스크롤된다.
        // [버그수정 — 전수감사] 기존엔 NavPill+제목+탭 전체가 CustomScrollView 맨 앞
        // 슬리버 안에 있어 스크롤하면 같이 사라졌고, 제목도 중앙정렬이 아니라
        // NavPill 바로 옆(좌측)에 붙어 있었다. vault_screen.dart/notifications_screen.dart와
        // 동일한 "고정 헤더 Column + Expanded 스크롤" 패턴으로 교체.
        return SafeArea(bottom: false, child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              WrNavPill(onBack: () => wrBackOrAskExit(context), onExitHome: () => wrExitHome(context)),
              Expanded(child: Center(child: Text('모두의 소원방', style: WrF.display(22), overflow: TextOverflow.ellipsis))),
              const SizedBox(width: 60), // NavPill과 시각적 균형
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Row(children: [
              _tab('소원방', 'rooms'),
              const SizedBox(width: 8),
              _tab('✨ 이루어진 이야기', 'stories'),
            ]),
          ),
          Expanded(child: RefreshIndicator(
            onRefresh: () => p.loadExplore(),
            child: CustomScrollView(slivers: [
              if (_etab == 'stories')
                ..._storiesSlivers(context, p)
              else
                ..._roomsSlivers(context, sorted),
            ]),
          )),
        ]));
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
            child: _TopCard(room: sorted[i], items: context.read<WishRoomProvider>().items, rank: i + 1, onTap: () => _open(sorted[i])),
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
          return Padding(padding: const EdgeInsets.only(bottom: 12), child: _FeedCard(room: rest[i], items: context.read<WishRoomProvider>().items, onTap: () => _open(rest[i])));
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
  // app2/review2.jsx › Stories() `tab==='all' ? '/reviews' : '/reviews?mine=1'` 1:1.
  // [버그수정 — 전수감사] 기존엔 '모두의 이야기/나의 이야기' 탭 자체가 없었다.
  List<Widget> _storiesSlivers(BuildContext context, WishRoomProvider p) {
    final list = _storyTab == 'mine' ? p.myReviews : p.reviewFeed;
    final room = p.room;
    // app2/review2.jsx › Stories() `canWrite` 1:1 — 내 방이 ACHIEVED이고, 그 방에 대한
    // 내 후기가 아직 없고, '나의 이야기' 탭일 때만 금색 CTA를 보여준다.
    final canWrite = room != null && room.wishStatus == WishStatus.ACHIEVED && _storyTab == 'mine' &&
        !list.any((v) => v.mine && v.roomId == room.id);
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
      SliverToBoxAdapter(child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Row(children: [
          _storyTabBtn('모두의 이야기', 'all'),
          const SizedBox(width: 8),
          _storyTabBtn('나의 이야기', 'mine'),
        ]),
      )),
      if (canWrite) SliverToBoxAdapter(child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: SizedBox(width: double.infinity, height: WrSize.btnH, child: DecoratedBox(decoration: WrDeco.btnGold,
          child: Material(color: Colors.transparent, child: InkWell(borderRadius: BorderRadius.circular(16),
            onTap: () => _openWrite(),
            child: const Center(child: Text('💌 이루어진 이야기 남기기', style: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF4A2A10)))))))),
      )),
      if (list.isEmpty)
        SliverFillRemaining(child: Center(child: Text(_storyTab == 'mine' ? '아직 남긴 이야기가 없어요' : '아직 나눠진 이야기가 없어요', style: const TextStyle(color: WrC.muted))))
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          sliver: SliverList(delegate: SliverChildBuilderDelegate((context, i) =>
            Padding(padding: const EdgeInsets.only(bottom: 10), child: _StoryCard(v: list[i], onEdit: () => _openWrite(edit: list[i]))),
            childCount: list.length,
          )),
        ),
    ];
  }

  Widget _storyTabBtn(String label, String v) {
    final sel = _storyTab == v;
    return GestureDetector(onTap: () => _setStoryTab(v), child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: sel ? WrDeco.tabOn : WrDeco.chip,
      child: Text(label, style: WrF.body(13, w: FontWeight.w700, color: sel ? Colors.white : WrC.fg)),
    ));
  }
}

class _TopCard extends StatelessWidget {
  const _TopCard({required this.room, required this.items, required this.rank, required this.onTap});
  final WishRoom room; final List<WrItem> items; final int rank; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final isFirst = rank == 1;
    return GestureDetector(onTap: onTap, child: Container(
      decoration: WrDeco.card,
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Stack(children: [
          // G-4 RoomThumb — app2/room2.jsx › RoomThumb() 공용 위젯. 탐색 TOP3 썸네일.
          // [버그수정 — 전수감사] 기존엔 Icons.local_fire_department 더미 아이콘이었다.
          SizedBox(height: 90, child: LayoutBuilder(builder: (context, c) =>
            RoomThumb(room: room, items: items, w: c.maxWidth, h: 90, focus: .22, zoom: 1.5))),
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
  const _FeedCard({required this.room, required this.items, required this.onTap});
  final WishRoom room; final List<WrItem> items; final VoidCallback onTap;
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
    return GestureDetector(onTap: widget.onTap, child: LayoutBuilder(builder: (context, constraints) {
      final innerW = constraints.maxWidth - 20; // Container padding 10*2
      return Container(
      decoration: WrDeco.card,
      padding: const EdgeInsets.all(10),
      child: Stack(clipBehavior: Clip.none, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // G-4 RoomThumb 공용 썸네일 — [버그수정 — 전수감사] 기존 더미 아이콘 교체.
          ClipRRect(borderRadius: BorderRadius.circular(12), child: RoomThumb(room: room, items: widget.items, w: 96, h: 112, focus: .22, zoom: 1.5)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              // app2/screens-b2.jsx › FeedCard() <img src={charSrc(room.char)}/> 30px 원형
              // 아바타 1:1. [버그수정 — 전수감사] 기존엔 Icons.person 더미 아이콘이었다.
              Container(width: 30, height: 30, clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(shape: BoxShape.circle, color: WrC.bg1,
                  border: Border.all(color: WrC.blossom2, width: 1.5)),
                child: Image.asset(WrCatalog.I.charImage(room.char, WrTheme.free), fit: BoxFit.cover, alignment: Alignment.topCenter,
                  errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 16, color: WrC.muted))),
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
        if (_heartKey > 0) WrHearts(key: ValueKey(_heartKey), x: innerW - 20, y: 30, n: 8),
      ]),
    );
    }));
  }
}

class _StoryCard extends StatefulWidget {
  const _StoryCard({required this.v, required this.onEdit});
  final WrReview v;
  /// app2/review2.jsx › StoryCard() `onEdit(v)` — 내 글 "고치기" 선택 시 ReviewWriteScreen(edit) 열기.
  final VoidCallback onEdit;
  @override
  State<_StoryCard> createState() => _StoryCardState();
}

class _StoryCardState extends State<_StoryCard> {
  late WrReview _v = widget.v;
  int _pop = 0;
  bool _menu = false;
  bool _gone = false; // app2/review2.jsx `v._gone` — 삭제/신고 후 이 카드만 즉시 숨김.
  final GlobalKey _congratsBtnKey = GlobalKey();
  double _congratsBtnWidth = 0;

  Future<void> _congrats() async {
    if (_v.mine) return;
    final p = context.read<WishRoomProvider>();
    final ok = await p.congrats(_v.id);
    if (!mounted) return;
    if (ok) {
      final fresh = p.reviewFeed.where((r) => r.id == _v.id).toList();
      final box = _congratsBtnKey.currentContext?.findRenderObject() as RenderBox?;
      final w = box?.size.width ?? 0;
      setState(() { if (fresh.isNotEmpty) _v = fresh.first; _congratsBtnWidth = w; _pop++; });
    }
  }

  // app2/review2.jsx › StoryCard() `del()` 1:1 — DELETE /reviews/{id} → 토스트 →
  // onChange({...v, _gone:true}). 받은 복주머니는 회수하지 않는다는 안내 문구까지 동일.
  Future<void> _delete() async {
    setState(() => _menu = false);
    final p = context.read<WishRoomProvider>();
    final ok = await p.deleteReview(_v.id);
    if (!mounted) return;
    if (ok) {
      setState(() => _gone = true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('이야기를 지웠어요 · 받은 복주머니는 그대로예요')));
    } else if (p.lastError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(p.lastError!.message)));
    }
  }

  // app2/review2.jsx › StoryCard() `report()` 1:1 — POST /reviews/{id}/report {reason:'부적절'}.
  Future<void> _report() async {
    setState(() => _menu = false);
    final p = context.read<WishRoomProvider>();
    final ok = await p.reportReview(_v.id, '부적절');
    if (!mounted) return;
    if (ok) {
      setState(() => _gone = true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('신고가 접수되어 숨겨졌어요')));
    } else if (p.lastError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(p.lastError!.message)));
    }
  }

  String _fmtDate(DateTime? t) => t == null ? '' : '${t.year}.${t.month.toString().padLeft(2, '0')}.${t.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    if (_gone) return const SizedBox.shrink();
    final cat = WrCatalog.I;
    final wc = cat.wishColors.where((c) => c['id'] == _v.wishColor).toList();
    final color = wc.isNotEmpty ? _hex(wc.first['color'] as String) : const Color(0xFFFFF0D8);
    return Container(
      decoration: WrDeco.card,
      clipBehavior: Clip.none,
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(16)), // WrDeco.card radius 근사 — 아래 메뉴 오버플로우는 Clip.none Stack에서 허용.
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned(right: -30, top: -30, child: Container(width: 120, height: 120,
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [color.withValues(alpha: .2), Colors.transparent])))),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('🔓 소원 봉인 해제', style: WrF.body(11, w: FontWeight.w700, color: WrC.muted)),
                const Spacer(),
                Text(_fmtDate(_v.achievedAt), style: WrF.mono(size: 9.5, color: WrC.muted)),
                GestureDetector(onTap: () => setState(() => _menu = !_menu),
                  child: const SizedBox(width: 24, height: 24, child: Icon(Icons.more_horiz, size: 18, color: WrC.muted))),
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
                // app2/review2.jsx › StoryCard() `v.mine && <span className="chip">{공개/나만 보기}</span>` 1:1.
                if (_v.mine) ...[
                  const SizedBox(width: 6),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: WrDeco.chip,
                    child: Text(_v.visibility == 'PUBLIC' ? '공개' : '나만 보기', style: WrF.body(10.5, color: WrC.fg))),
                ],
                const Spacer(),
                GestureDetector(onTap: _v.mine ? null : _congrats, child: Opacity(opacity: _v.mine ? .6 : 1, child: Stack(clipBehavior: Clip.none, children: [
                  Container(key: _congratsBtnKey, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                  if (_pop > 0) WrHearts(key: ValueKey(_pop), x: _congratsBtnWidth, y: 0, n: 6),
                ]))),
              ]),
            ]),
            // app2/review2.jsx › StoryCard() `{menu && <div>...}` 1:1 — 내 글: 고치기/지우기,
            // 남의 글: 신고하기. right:12 top:40 드롭다운.
            if (_menu) Positioned(right: 12, top: 40, child: Container(
              decoration: BoxDecoration(color: const Color(0xFF2A1020), borderRadius: BorderRadius.circular(12), border: Border.all(color: WrC.line),
                boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 20, offset: Offset(0, 8))]),
              clipBehavior: Clip.antiAlias,
              child: _v.mine
                ? Column(mainAxisSize: MainAxisSize.min, children: [
                    _menuItem('고치기', () { setState(() => _menu = false); widget.onEdit(); }),
                    _menuItem('지우기', _delete, color: const Color(0xFFFF9A9A)),
                  ])
                : _menuItem('신고하기', _report),
            )),
          ]),
        ),
      ),
    );
  }

  Widget _menuItem(String label, VoidCallback onTap, {Color color = Colors.white}) => GestureDetector(
    onTap: onTap,
    child: Container(width: 120, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(label, style: WrF.body(13, color: color))));
}

Color _hex(String h) => Color(int.parse('FF${h.replaceFirst('#', '')}', radix: 16));
