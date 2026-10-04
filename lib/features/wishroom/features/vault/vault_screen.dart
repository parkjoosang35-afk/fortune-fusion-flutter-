// SCR-09 보관함 `/vault` (탭5) — docs/SCREENS.md §SCR-09 · app2/screens-c2.jsx › Vault()/Archive()/
// ArchivePlayer()/PouchTab()/RewardTab() 1:1 이식. 탭 3개: 소원 기록관 · 복주머니 · 응원 보상.
// 우상단 "캐릭터" 칩 → SCR-05.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../application/wishroom_provider.dart';
import '../../data/models.dart';
import '../../data/wr_catalog.dart';
import '../../core/theme/wr_theme.dart';
import '../../core/fx/wr_fx.dart';
import '../../core/wr_canvas.dart';
import '../room/room_scene.dart';
import '../characters/character_shop_screen.dart';
import '../compose/compose_screen.dart';
import '../guide/guide_sheet.dart';
import '../../core/wr_nav_pill.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../../ads_test/domain/admob_ad_ids.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});
  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    final p = context.read<WishRoomProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      p.loadArchive();
      p.loadLedger();
    });
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    // wallet_sheet.dart "전체 내역 보기"(복주머니 탭) 요청을 소비해 내부 TabBarView를
    // 전환한다. tourRequested와 동일한 "Provider 플래그 → Shell/화면이 대신 처리" 패턴.
    final subTab = context.select<WishRoomProvider, int?>((p) => p.requestedVaultSubTab);
    if (subTab != null && subTab != _tabs.index) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _tabs.animateTo(subTab);
        context.read<WishRoomProvider>().consumeVaultSubTabRequest();
      });
    }
    return Theme(data: wrThemeData(), child: Scaffold(
      backgroundColor: WrC.bg2,
      body: SafeArea(bottom: false, child: Column(children: [
        // app2/fx2.jsx › TopBar() 제목은 left:104,right:104(화면폭 기준 중앙정렬) 고정값.
        // [버그수정 — 전수감사] 기존엔 NavPill 바로 옆에 좌측정렬되어 화면 중심에서
        // 벗어나 있었다. Stack+Positioned로 app2/fx2.jsx TopBar() 1:1 재구성.
        SizedBox(height: 44, child: Stack(children: [
          const Positioned(top: 0, bottom: 0, left: 104, right: 104, child: Center(child: Text('보관함',
            style: TextStyle(fontFamily: 'NotoSerifKRWish', fontWeight: FontWeight.w900, fontSize: 22, color: Colors.white),
            maxLines: 1, overflow: TextOverflow.ellipsis))),
          Positioned(left: 16, top: 0, bottom: 0, child: Center(child:
            WrNavPill(onBack: () => wrBackOrAskExit(context), onExitHome: () => wrExitHome(context)))),
          Positioned(right: 16, top: 0, bottom: 0, child: Center(child: Row(children: [
            GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CharacterShopScreen())),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: const Color(0x991E0C18), borderRadius: BorderRadius.circular(999), border: Border.all(color: WrC.line)),
                child: Text('캐릭터', style: WrF.body(12, color: WrC.fg)),
              ),
            ),
            const SizedBox(width: 8),
            // app2/screens-c2.jsx › TopBar right › app.openGuide('archive') 1:1.
            // GuideBook의 "한 바퀴 둘러보기"는 app.room && 조건만 보므로 보관함에서도 항상
            // 노출되고, 누르면 app.go('home') 후 startTour() — requestTour()로 셸이 대신한다.
            GestureDetector(
              onTap: () => showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
                builder: (_) => GuideBook(focus: 'archive', onStartTour: context.read<WishRoomProvider>().requestTour)),
              child: Container(
                width: 32, height: 32, alignment: Alignment.center,
                decoration: BoxDecoration(color: const Color(0x991E0C18), shape: BoxShape.circle, border: Border.all(color: WrC.line)),
                child: const Text('?', style: TextStyle(fontFamily: 'NotoSerifKRWish', fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white)),
              ),
            ),
          ]))),
        ])),
        Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 0), child: Container(
          height: 40, padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(color: WrC.tabsBg, borderRadius: BorderRadius.circular(WrR.tabs)),
          child: TabBar(
            controller: _tabs, dividerColor: Colors.transparent, indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(borderRadius: BorderRadius.circular(WrR.tab), gradient: const LinearGradient(colors: [WrC.blossom2, WrC.blossom])),
            labelColor: Colors.white, unselectedLabelColor: WrC.muted,
            labelStyle: WrF.body(13, w: FontWeight.w700), unselectedLabelStyle: WrF.body(13, w: FontWeight.w600),
            tabs: const [Tab(text: '소원 기록관'), Tab(text: '복주머니'), Tab(text: '응원 보상')],
          ),
        )),
        Expanded(child: TabBarView(controller: _tabs, children: const [
          _ArchiveTab(), _PouchTab(), _RewardTab(),
        ])),
      ])),
    ));
  }
}

// ═══════════════════ 소원 기록관 — Archive() 1:1 ═══════════════════

class _ArchiveTab extends StatefulWidget {
  const _ArchiveTab();
  @override
  State<_ArchiveTab> createState() => _ArchiveTabState();
}

class _ArchiveTabState extends State<_ArchiveTab> {
  bool _ongoing = false; // 원본 기본 탭 = 'done'(이루어진 소원)

  @override
  Widget build(BuildContext context) {
    return Consumer<WishRoomProvider>(builder: (context, p, __) {
      final rooms = p.archiveRooms;
      final cur = p.room; // 현재 소원방(진행 중)은 provider.room, 보관함 리스트는 완성/봉인분
      final done = rooms.where((r) => r.status == RoomStatus.SEALED || r.status == RoomStatus.ARCHIVED).toList();
      return RefreshIndicator(onRefresh: () => p.loadArchive(), child: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 10), child: Row(children: [
          _chip('진행 중 (${cur != null ? 1 : 0})', true),
          const SizedBox(width: 8),
          _chip('이루어진 소원 (${done.length})', false),
        ]))),
        if (_ongoing)
          SliverPadding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: .74),
            delegate: SliverChildListDelegate([
              if (cur != null) _CurrentRoomCard(room: cur, items: p.items)
              else GestureDetector(onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ComposeScreen())), child: const DottedBox()),
            ]),
          ))
        else
          SliverPadding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: .74),
            delegate: SliverChildBuilderDelegate((_, i) {
              if (i == done.length) {
                return GestureDetector(
                  onTap: () => cur != null
                      ? ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('진행 중인 소원이 이루어지면 새 소원방을 열 수 있어요')))
                      : Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ComposeScreen())),
                  child: const DottedBox(),
                );
              }
              final room = done[i];
              return _ArchiveCard(room: room, items: p.items, onTap: () => _openReplay(context, room, p.items));
            }, childCount: done.length + 1),
          )),
        if (!_ongoing && done.isEmpty) SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.only(top: 16),
          child: Text('이루어진 소원방은 이곳에 영원히 머뭅니다', textAlign: TextAlign.center, style: WrF.body(12.5, color: WrC.muted, height: 1.7)))),
      ]));
    });
  }

  Widget _chip(String label, bool ongoing) {
    final sel = _ongoing == ongoing;
    return GestureDetector(onTap: () => setState(() => _ongoing = ongoing), child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: sel ? WrDeco.chipOn : WrDeco.chip,
      child: Text(label, style: WrF.body(12, w: FontWeight.w700, color: sel ? Colors.white : WrC.fg)),
    ));
  }

  void _openReplay(BuildContext context, WishRoom room, List<WrItem> items) {
    showDialog(context: context, barrierColor: const Color(0xE6000000), builder: (_) => _ReplayOverlay(room: room, items: items));
  }
}

/// 진행 중인 현재 소원방 카드 — 원본 Archive() 58-61줄.
class _CurrentRoomCard extends StatelessWidget {
  const _CurrentRoomCard({required this.room, required this.items});
  final WishRoom room; final List<WrItem> items;
  @override
  Widget build(BuildContext context) {
    // app2/screens-c2.jsx › Archive() f==='cur' 카드 onClick={() => app.go('home')} 1:1.
    // [버그수정 — 전수감사] 기존엔 popUntil(isFirst)이라, Vault가 IndexedStack 탭(탭4)
    // 안에 있을 땐 화면 스택만 pop될 뿐 바텀탭이 메인(탭0)으로 전환되지 않았다.
    return GestureDetector(
      onTap: () => context.read<WishRoomProvider>().requestTab(0),
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: WrC.blossom2)),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(height: 150, child: WrCanvasScaler(child: RoomScene(room: room, items: items, frozen: true, lowFx: true))),
          Padding(padding: const EdgeInsets.fromLTRB(10, 8, 10, 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('현재 소원방', style: WrF.body(12.5, w: FontWeight.w700, color: WrC.fg)),
            const SizedBox(height: 2),
            Text(room.text, style: WrF.body(11.5, color: WrC.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
        ]),
      ),
    );
  }
}

class _ArchiveCard extends StatelessWidget {
  const _ArchiveCard({required this.room, required this.items, required this.onTap});
  final WishRoom room; final List<WrItem> items; final VoidCallback onTap;
  String _d(DateTime? t) => t == null ? '' : '${t.year}.${t.month.toString().padLeft(2, '0')}.${t.day.toString().padLeft(2, '0')}';
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: onTap, child: Container(
      decoration: BoxDecoration(color: WrC.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0x66F5CF6A))),
      padding: const EdgeInsets.all(10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // G-4 RoomThumb 공용 썸네일 — [버그수정 — 전수감사] 기존 더미 아이콘 교체.
        Expanded(child: Stack(children: [
          Positioned.fill(child: ClipRRect(borderRadius: BorderRadius.circular(10),
            child: LayoutBuilder(builder: (context, c) =>
              RoomThumb(room: room, items: items, w: c.maxWidth, h: c.maxHeight, focus: .22, zoom: 1.5)))),
          Positioned(right: 4, top: 4, child: Transform.rotate(angle: -6 * 3.14159 / 180, child: Container(
            width: 28, height: 28, alignment: Alignment.center,
            decoration: const BoxDecoration(color: WrC.accent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x80C94A3B), blurRadius: 8)]),
            child: const Text('成', style: TextStyle(fontFamily: 'NotoSerifKRWish', fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFFFFF9E8)))))),
        ])),
        const SizedBox(height: 6),
        Text('완성', style: WrF.body(12.5, w: FontWeight.w700, color: WrC.glow)),
        const SizedBox(height: 2),
        Text(room.text, style: WrF.body(11.5, color: WrC.fg), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text('${_d(room.completedAt)} · ${room.daysLit}일', style: WrF.body(10.5, color: WrC.muted)),
      ]),
    ));
  }
}

class DottedBox extends StatelessWidget {
  const DottedBox({super.key});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: WrC.line, width: 1.4)),
        alignment: Alignment.center,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 44, height: 44, alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0x33F2628F), border: Border.all(color: WrC.blossom2)),
            child: const Text('+', style: TextStyle(fontSize: 20, color: WrC.blossom2))),
          const SizedBox(height: 8),
          Text('새로운 소원방\n만들기', textAlign: TextAlign.center, style: WrF.body(12.5, color: WrC.fg, w: FontWeight.w700)),
        ]),
      );
}

/// "당시 모습 재생" — 원본 ArchivePlayer() 1:1. 전체화면 흑배경 + Room(gold:.25) + 꽃잎비 + 한지카드(成 인장 + 생성→완료 기간 + 스탯).
class _ReplayOverlay extends StatelessWidget {
  const _ReplayOverlay({required this.room, required this.items});
  final WishRoom room; final List<WrItem> items;
  String _d(DateTime? t) => t == null ? '' : '${t.year}.${t.month.toString().padLeft(2, '0')}.${t.day.toString().padLeft(2, '0')}';
  @override
  Widget build(BuildContext context) {
    return Dialog(backgroundColor: Colors.black, insetPadding: EdgeInsets.zero, child: Stack(children: [
      Positioned.fill(child: WrCanvasScaler(child: RoomScene(room: room, items: items, gold: .25, frozen: true))),
      const WrPetalRain(n: 16, dur: (6, 9), spread: 6),
      SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(14, 8, 14, 0), child: Row(children: [
        GestureDetector(onTap: () => Navigator.of(context).pop(), child: Container(
          width: 32, height: 32, alignment: Alignment.center,
          decoration: BoxDecoration(color: WrC.glass, shape: BoxShape.circle, border: Border.all(color: WrC.line)),
          child: const Icon(Icons.close, size: 15, color: Colors.white))),
        const Spacer(),
      ]))),
      const Positioned(left: 0, right: 0, top: 58, child: Center(child: Column(children: [
        Text('이루어진 소원방', style: TextStyle(fontFamily: 'NotoSerifKRWish', fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white)),
        SizedBox(height: 1),
        Text('그날의 모습 그대로', style: TextStyle(fontFamily: 'GowunBatangWish', fontSize: 11, color: Color(0xA8FFECDC))),
      ]))),
      Positioned(left: 16, right: 16, bottom: 44, child: Container(
        padding: const EdgeInsets.all(16), decoration: WrDeco.hanji,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 28, height: 28, alignment: Alignment.center,
              decoration: const BoxDecoration(color: WrC.accent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x80C94A3B), blurRadius: 8)]),
              child: const Text('成', style: TextStyle(fontFamily: 'NotoSerifKRWish', fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFFFFF9E8)))),
            const SizedBox(width: 10),
            Text('${_d(room.createdAt)} → ${_d(room.completedAt)} · ${room.daysLit}일', style: const TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 11.5, color: Color(0xA65A321E))),
          ]),
          const SizedBox(height: 10),
          Text(room.text, style: const TextStyle(fontFamily: 'GowunBatangWish', fontWeight: FontWeight.w700, fontSize: 16, color: WrC.hanjiInk, height: 1.5)),
          const SizedBox(height: 10),
          Row(children: [
            Text('Lv.${room.level}', style: const TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF8A4A3A))),
            const SizedBox(width: 14),
            Text('🙏 ${room.devotionCount}', style: const TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF8A4A3A))),
            const SizedBox(width: 14),
            Text('❤ ${room.supportCount}', style: const TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF8A4A3A))),
            const SizedBox(width: 14),
            Text('福 ${room.pouchReceived}', style: const TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF8A4A3A))),
          ]),
        ]),
      )),
    ]));
  }
}

// ═══════════════════ 복주머니 — PouchTab() 1:1 ═══════════════════

class _EarnSection {
  const _EarnSection({required this.id, required this.no, required this.icon, required this.c1, required this.c2,
    required this.title, this.big = false, this.go});
  final String id, no, icon, title; final Color c1, c2; final bool big; final String? go;
}

const List<_EarnSection> _kSections = [
  _EarnSection(id: 'ad', no: '01', icon: '▶', c1: Color(0xFF9A6AFF), c2: Color(0xFF6A3AD8), title: '짧은 영상 보기', big: true),
  _EarnSection(id: 'attend', no: '02', icon: '✓', c1: Color(0xFFF5CF6A), c2: Color(0xFFC9962A), title: '오늘의 출석'),
  _EarnSection(id: 'devo10', no: '03', icon: '🙏', c1: Color(0xFFFF9CBC), c2: Color(0xFFF2628F), title: '정성 10회 채우기', go: 'home'),
  _EarnSection(id: 'm_visit', no: '04', icon: '☾', c1: Color(0xFF8AB8FF), c2: Color(0xFF4A7AD8), title: '다른 소원방 3곳 둘러보기', go: 'explore'),
  _EarnSection(id: 'm_cheer', no: '05', icon: '❤', c1: Color(0xFFFF8FB1), c2: Color(0xFFC93A7A), title: '응원 3번 보내기', go: 'explore'),
  _EarnSection(id: 'm_msg', no: '06', icon: '💬', c1: Color(0xFF7FD6A0), c2: Color(0xFF2F8A5A), title: '응원 메시지 남기기', go: 'explore'),
];

class _PouchTab extends StatefulWidget {
  const _PouchTab();
  @override
  State<_PouchTab> createState() => _PouchTabState();
}

class _PouchTabState extends State<_PouchTab> {
  bool _adLoading = false;
  int _gotKey = 0; int _gotAmount = 0;

  Future<void> _earn(_EarnSection s) async {
    if (s.id == 'ad') {
      if (!AdmobAdIds.isSupportedPlatform) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('이 플랫폼에서는 광고 시청을 지원하지 않아요')));
        return;
      }
      if (_adLoading) return;
      setState(() => _adLoading = true);
      await RewardedAd.load(
        adUnitId: AdmobAdIds.rewardedUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            bool rewarded = false;
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) async {
                ad.dispose();
                if (mounted) setState(() => _adLoading = false);
                if (rewarded) await _doEarn(s.id);
              },
              onAdFailedToShowFullScreenContent: (ad, _) {
                ad.dispose();
                if (mounted) setState(() => _adLoading = false);
              },
            );
            ad.show(onUserEarnedReward: (ad, reward) { rewarded = true; });
          },
          onAdFailedToLoad: (_) {
            if (mounted) setState(() => _adLoading = false);
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('지금은 광고를 불러올 수 없어요')));
          },
        ),
      );
      return;
    }
    // app2/screens-c2.jsx › PouchTab() act() 1:1 — go 필드는 메타데이터일 뿐, 실제
    // 클릭 동작은 devo10만 app.go('home')으로 분기하고 나머지(m_visit/m_cheer/m_msg
    // 포함)는 go 값과 무관하게 전부 즉시 doEarn(S.id)를 호출한다.
    // [버그수정 — 전수감사] 기존엔 go=='explore'일 때 적립 없이 안내 토스트만 띄웠다
    // (원본엔 그런 분기가 없다). go=='home'도 popUntil(isFirst)이라 Vault 탭(IndexedStack)
    // 안에서는 메인 탭으로 전환되지 않았다.
    if (s.go == 'home') { context.read<WishRoomProvider>().requestTab(0); return; }
    await _doEarn(s.id);
  }

  Future<void> _doEarn(String source) async {
    final p = context.read<WishRoomProvider>();
    final res = await p.earn(source);
    if (!mounted) return;
    if (res != null) {
      setState(() { _gotKey++; _gotAmount = res.$1; });
      p.loadLedger();
    } else if (p.lastError != null) {
      final msg = p.lastError!.code == 'EARN_LIMIT' ? '오늘은 모두 받았어요' : p.lastError!.message;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WishRoomProvider>(builder: (context, p, __) {
      final me = p.me;
      final cat = WrCatalog.I;
      final earnCat = {for (final e in cat.earn) e['id'] as String: e};
      final today = me?.earnToday ?? const <String, int>{};
      final total = cat.earn.fold<int>(0, (a, e) => a + (e['amount'] as num).toInt() * (e['limit'] as num).toInt());
      final gotToday = cat.earn.fold<int>(0, (a, e) {
        final id = e['id'] as String; final limit = (e['limit'] as num).toInt();
        return a + (e['amount'] as num).toInt() * (today[id] ?? 0).clamp(0, limit);
      });
      final room = p.room;
      final devoUsed = room?.devotionsToday ?? 0, devoLim = room?.dailyLimit ?? 10;

      return RefreshIndicator(onRefresh: () => p.loadLedger(), child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
        // 잔액 패널 — pouch 84px bob + Burst 연출
        Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0x99781E32), Color(0xCC280C1C)])),
          child: Row(children: [
            Stack(clipBehavior: Clip.none, children: [
              _BobbingPouch(key: const ValueKey('pouch')),
              if (_gotKey > 0) WrBurst(key: ValueKey(_gotKey), x: 42, y: 42, n: 16, glyph: '✨', spread: 90),
            ]),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('내 복주머니 · 신통방통 공용', style: WrF.body(12.5, color: WrC.muted)),
              Text('${me?.pouch ?? 0}', key: ValueKey(me?.pouch), style: WrF.display(38, color: WrC.glow)),
              if (_gotKey > 0) Text('+$_gotAmount 담겼어요', key: ValueKey('got$_gotKey'), style: WrF.body(13, color: WrC.glow)),
            ])),
          ]),
        ),
        const SizedBox(height: 18),
        Row(children: [
          Text('복주머니 모으기', style: WrF.display(16)),
          const SizedBox(width: 6),
          Text('매일 자정 초기화', style: WrF.body(11, color: WrC.muted)),
        ]),
        const SizedBox(height: 10),
        // 오늘 진행 요약
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: WrC.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: WrC.cardBorder)),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('오늘 모은 복주머니', style: WrF.body(12, color: WrC.muted)),
              const SizedBox(height: 2),
              Row(crossAxisAlignment: CrossAxisAlignment.baseline, children: [
                Text('$gotToday', style: WrF.display(22, color: WrC.glow)),
                const SizedBox(width: 4),
                Text('/ 최대 $total', style: WrF.body(12, color: WrC.muted)),
              ]),
              const SizedBox(height: 8),
              ClipRRect(borderRadius: BorderRadius.circular(5), child: LinearProgressIndicator(
                value: total == 0 ? 0 : (gotToday / total).clamp(0, 1).toDouble(), minHeight: 5, backgroundColor: const Color(0x1FFFFFFF),
                valueColor: const AlwaysStoppedAnimation(WrC.blossom))),
            ])),
            const SizedBox(width: 10),
            Image.asset('assets/wishroom/items/pouch.png', width: 46, errorBuilder: (_, __, ___) => const Text('💰', style: TextStyle(fontSize: 36))),
          ]),
        ),
        const SizedBox(height: 10),
        ...List.generate(_kSections.length, (i) {
          final s = _kSections[i];
          final e = earnCat[s.id];
          if (e == null) return const SizedBox.shrink();
          final limit = (e['limit'] as num).toInt();
          final amount = (e['amount'] as num).toInt();
          final n = today[s.id] ?? 0;
          final done = n >= limit;
          final isDevo = s.id == 'devo10';
          final prog = isDevo ? devoUsed.clamp(0, devoLim) : n;
          final progMax = isDevo ? devoLim : limit;
          return Padding(padding: const EdgeInsets.only(bottom: 10), child: Container(
            padding: EdgeInsets.fromLTRB(14, s.big ? 14 : 12, 14, s.big ? 12 : 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: done ? WrC.card : null,
              gradient: !done && s.big ? LinearGradient(colors: [s.c1.withValues(alpha: .2), const Color(0x1FF2628F)]) : (!done ? null : null),
              border: Border.all(color: done ? WrC.cardBorder : (s.big ? s.c1.withValues(alpha: .53) : WrC.cardBorder)),
            ),
            child: Opacity(opacity: done ? .62 : 1, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: s.big ? 50 : 42, height: s.big ? 50 : 42, alignment: Alignment.center,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
                    color: done ? const Color(0x1AFFFFFF) : null,
                    gradient: done ? null : LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [s.c1, s.c2]),
                    boxShadow: done ? null : [BoxShadow(color: s.c1.withValues(alpha: .4), blurRadius: 14)]),
                  child: Text(done ? '✓' : s.icon, style: TextStyle(fontSize: s.big ? 20 : 17, color: Colors.white))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(s.no, style: TextStyle(fontFamily: 'IBMPlexMonoWish', fontSize: 9.5, letterSpacing: 1.5, color: s.c1)),
                    const SizedBox(width: 6),
                    Expanded(child: Text(s.title, style: WrF.body(s.big ? 15 : 13.5, w: FontWeight.w700, color: WrC.fg), maxLines: 2)),
                  ]),
                  const SizedBox(height: 2),
                  Text(_descFor(s.id, isDevo ? devoUsed.clamp(0, devoLim) : 0, devoLim), style: WrF.body(11.5, color: WrC.muted, height: 1.45)),
                ])),
              ]),
              if (progMax > 1) Padding(padding: const EdgeInsets.only(top: 10), child: Row(children: [
                for (var k = 0; k < progMax; k++) Expanded(child: Container(
                  margin: EdgeInsets.only(right: k == progMax - 1 ? 0 : 3), height: 5,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(3),
                    gradient: k < prog ? LinearGradient(colors: [s.c1, s.c2]) : null,
                    color: k < prog ? null : const Color(0x24FFFFFF)))),
              ])),
              const SizedBox(height: 10),
              Row(children: [
                Image.asset('assets/wishroom/items/pouch.png', width: 16, errorBuilder: (_, __, ___) => const Text('💰', style: TextStyle(fontSize: 13))),
                const SizedBox(width: 4),
                Text('+$amount', style: TextStyle(fontFamily: 'NotoSerifKRWish', fontWeight: FontWeight.w900, fontSize: s.big ? 18 : 15, color: done ? WrC.muted : WrC.glow)),
                const SizedBox(width: 6),
                Expanded(child: Text(
                  limit > 1 ? '· $n/$limit회 · 하루 최대 +${amount * limit}' : (done ? '· 받음' : s.id.startsWith('m_') ? '· 오늘의 미션' : '· 하루 1회'),
                  style: WrF.body(10.5, color: WrC.muted), maxLines: 1, overflow: TextOverflow.ellipsis)),
                GestureDetector(
                  onTap: done || (s.id == 'ad' && _adLoading) ? null : () => _earn(s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14), height: 32, alignment: Alignment.center,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(999),
                      color: done ? WrC.darkBtn : (s.big ? null : WrC.darkBtn),
                      gradient: !done && s.big ? const LinearGradient(colors: [WrC.blossom2, WrC.blossom]) : null,
                      border: Border.all(color: done ? WrC.line : s.c1.withValues(alpha: .47))),
                    child: s.id == 'ad' && _adLoading
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(done ? '오늘 완료' : (isDevo ? '정성 들이러 가기 ›' : s.id == 'ad' ? '영상 보기' : s.id == 'attend' ? '출석하기' : s.id == 'm_visit' ? '둘러보기' : s.id == 'm_cheer' ? '응원하러 가기' : '메시지 남기기'),
                          style: const TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 12.5, color: Colors.white)),
                  ),
                ),
              ]),
            ])),
          ));
        }),
        const SizedBox(height: 18),
        Text('사용처', style: WrF.display(16)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(color: WrC.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: WrC.cardBorder)),
          child: Column(children: [
            _useRow('캐릭터', '500'),
            _useRow('꾸미기 아이템', '50~150'),
            _useRow('인장', '50~120'),
            _useRow('선물하기', '자유롭게', last: true),
          ]),
        ),
        const SizedBox(height: 18),
        Text('내역', style: WrF.display(16)),
        const SizedBox(height: 8),
        if (p.ledger.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Center(child: Text('아직 내역이 없어요', style: WrF.body(12, color: WrC.muted))))
        else ...p.ledger.take(10).map((e) {
          final amount = ((e['amount'] ?? 0) as num).toInt();
          final at = e['at'];
          return Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Container(
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: WrC.line))),
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text((e['label'] ?? e['reason'] ?? '').toString(), style: WrF.body(13, w: FontWeight.w700, color: WrC.fg)),
                const SizedBox(height: 2),
                Text(_agoLedger(at), style: WrF.body(11, color: WrC.muted)),
              ])),
              Text('${amount > 0 ? '+' : ''}$amount', style: WrF.body(14, w: FontWeight.w700, color: amount > 0 ? WrC.glow : WrC.fg)),
            ]),
          ));
        }),
      ]));
    });
  }

  String _descFor(String id, int devoUsed, int devoLim) => switch (id) {
        'ad' => '짧은 영상을 끝까지 보면 복주머니가 담겨요',
        'attend' => '하루 한 번, 들러주신 것만으로 충분해요',
        'devo10' => '오늘 정성 ${devoUsed.clamp(0, devoLim)}/$devoLim · 다 채우면 자동으로 담겨요',
        'm_visit' => '다른 분들의 소원을 조용히 둘러봐요',
        'm_cheer' => '마음이 닿는 소원에 응원을 보내요',
        'm_msg' => '따뜻한 한 마디를 남겨주세요',
        _ => '',
      };

  String _agoLedger(dynamic at) {
    if (at == null) return '';
    DateTime? t;
    if (at is num) t = DateTime.fromMillisecondsSinceEpoch(at.toInt());
    if (at is String) t = DateTime.tryParse(at);
    if (t == null) return '';
    final m = DateTime.now().difference(t).inMinutes;
    if (m < 1) return '지금';
    if (m < 60) return '$m분 전';
    final h = m ~/ 60;
    return h < 24 ? '$h시간 전' : '${h ~/ 24}일 전';
  }

  Widget _useRow(String label, String value, {bool last = false}) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: last ? null : const BoxDecoration(border: Border(bottom: BorderSide(color: WrC.line))),
        child: Row(children: [
          Expanded(child: Text(label, style: WrF.body(13, color: WrC.fg))),
          Text(value, style: WrF.body(13, w: FontWeight.w700, color: WrC.glow)),
        ]),
      );
}

/// 복주머니 이미지 bob 애니메이션 — CSS `bob 4s ease-in-out infinite` 1:1.
class _BobbingPouch extends StatefulWidget {
  const _BobbingPouch({super.key});
  @override
  State<_BobbingPouch> createState() => _BobbingPouchState();
}

class _BobbingPouchState extends State<_BobbingPouch> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: _c, builder: (_, __) => Transform.translate(
        offset: Offset(0, -6 * Curves.easeInOut.transform(_c.value)),
        child: Image.asset('assets/wishroom/items/pouch.png', width: 84, errorBuilder: (_, __, ___) => const Text('💰', style: TextStyle(fontSize: 64))),
      ));
}

// ═══════════════════ 응원 보상 — RewardTab() 1:1 ═══════════════════

class _RewardTab extends StatefulWidget {
  const _RewardTab();
  @override
  State<_RewardTab> createState() => _RewardTabState();
}

class _RewardTabState extends State<_RewardTab> {
  bool _busy = false;
  Map<String, dynamic>? _open; // 받기 연출 상태 { at, reward, item, bonus }
  int _openKey = 0;

  Future<void> _claim(WishRoomProvider p, String id, Map<String, dynamic> r) async {
    final at = r['at'] as int;
    setState(() => _busy = true);
    final res = await p.claimSupportReward(id, at);
    if (!mounted) return;
    setState(() => _busy = false);
    if (res != null) {
      setState(() { _openKey++; _open = {'at': at, 'reward': r['reward'], 'item': res['item'], 'bonus': res['bonus']}; });
    } else if (p.lastError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(p.lastError!.message)));
    }
  }

  String _rewardGlyph(String icon) => switch (icon) {
        'petal' => '🌸', 'spark' => '✨', 'gift' => '🎁', 'chest' => '🧧', 'star' => '⭐', _ => '✦',
      };

  @override
  Widget build(BuildContext context) {
    final cat = WrCatalog.I;
    return Consumer<WishRoomProvider>(builder: (context, p, __) {
      final room = p.room;
      if (room == null) return Center(child: Text('소원방을 만들면 응원 보상이 열려요', style: WrF.body(14, color: WrC.muted)));
      final rewards = cat.supportRewards;
      final serverStates = {for (final r in room.rewards ?? const <SupportRewardState>[]) r.at: r};
      final n = room.supportCount;
      Map<String, dynamic>? next;
      for (final r in rewards) { final at = r['at'] as int; final st = serverStates[at]; final reached = st?.reached ?? n >= at; if (!reached) { next = r; break; } }
      final prevAt = next == null ? 0 : (rewards.indexOf(next) > 0 ? rewards[rewards.indexOf(next) - 1]['at'] as int : 0);
      final pct = next == null ? 1.0 : ((n - prevAt) / ((next['at'] as int) - prevAt)).clamp(0, 1).toDouble();
      final ready = rewards.where((r) { final at = r['at'] as int; final st = serverStates[at]; final reached = st?.reached ?? n >= at; final claimed = st?.claimed ?? false; return reached && !claimed; }).length;

      return Stack(children: [
        ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20),
              gradient: const RadialGradient(center: Alignment(0, -1), radius: 1.6, colors: [Color(0x4CF2628F), Color(0x14220E1C)])),
            child: Column(children: [
              Text('응원을 많이 받을수록\n특별한 보상이 열려요', textAlign: TextAlign.center, style: WrF.display(17)),
              const SizedBox(height: 6),
              RichText(textAlign: TextAlign.center, text: TextSpan(style: WrF.body(13, color: WrC.muted), children: [
                const TextSpan(text: '지금까지 받은 응원 '),
                TextSpan(text: '❤ $n', style: const TextStyle(color: Color(0xFFFF8FB1), fontSize: 15, fontWeight: FontWeight.w700)),
              ])),
              if (next != null) Padding(padding: const EdgeInsets.only(top: 14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text.rich(TextSpan(style: WrF.body(11.5, color: WrC.muted), children: [
                    const TextSpan(text: '다음 보상 · '),
                    TextSpan(text: '${next['reward']}', style: const TextStyle(color: WrC.fg)),
                  ]))),
                  Text('${(next['at'] as int) - n}회 남음', style: WrF.body(11.5, color: WrC.muted)),
                ]),
                const SizedBox(height: 6),
                ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(
                  value: pct, minHeight: 8, backgroundColor: const Color(0x1AFFFFFF),
                  valueColor: const AlwaysStoppedAnimation(WrC.blossom))),
              ])) else Padding(padding: const EdgeInsets.only(top: 10), child: Text('✦ 모든 응원 보상을 열었어요', style: WrF.body(12.5, color: const Color(0xFFFFE08A)))),
              if (ready > 0) Padding(padding: const EdgeInsets.only(top: 10), child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), color: const Color(0x2EF5CF6A), border: Border.all(color: const Color(0x80F5CF6A))),
                child: Text('🎁 받을 수 있는 보상 $ready개', style: const TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFFFFE08A))))),
            ]),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(4, 12, 4, 0), child: Text.rich(TextSpan(style: WrF.body(11.5, color: WrC.muted, height: 1.6), children: [
            const TextSpan(text: '받은 보상은 보관함에 담기고, '),
            const TextSpan(text: '꾸미기', style: TextStyle(color: WrC.fg)),
            const TextSpan(text: '에서 바로 방에 둘 수 있어요. 응원 보상 아이템은 상점에서 살 수 없어요.'),
          ]))),
          const SizedBox(height: 12),
          ...rewards.asMap().entries.map((entry) {
            final r = entry.value; final at = r['at'] as int;
            final st = serverStates[at];
            final reached = st?.reached ?? n >= at;
            final claimed = st?.claimed ?? false;
            final statusReady = reached && !claimed;
            return Padding(padding: const EdgeInsets.only(bottom: 8), child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: statusReady ? const Color(0x29F5CF6A) : WrC.card,
                border: Border.all(color: statusReady ? const Color(0xB3F5CF6A) : (claimed ? const Color(0x4DF5CF6A) : WrC.cardBorder), width: statusReady ? 1.4 : 1),
              ),
              child: Row(children: [
                Container(width: 54, height: 54, alignment: Alignment.center,
                  decoration: const BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [Color(0x4DFFA0BE), Colors.transparent])),
                  child: Stack(alignment: Alignment.center, children: [
                    Opacity(opacity: reached ? 1 : .35, child: Text(_rewardGlyph(r['icon'] as String), style: const TextStyle(fontSize: 26))),
                    if (!reached) const Positioned(right: -2, bottom: -2, child: Text('🔒', style: TextStyle(fontSize: 12))),
                  ])),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(claimed ? _ownedLabel(r) : '$at회 · ${r['reward']}', style: WrF.body(13.5, w: FontWeight.w700, color: WrC.fg)),
                  const SizedBox(height: 2),
                  Text('응원 $at회 · ${r['desc']}', style: WrF.body(11, color: WrC.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                ])),
                if (statusReady)
                  GestureDetector(onTap: _busy ? null : () => _claim(p, room.id, r), child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(999),
                      gradient: const LinearGradient(colors: [Color(0xFFFFE7A0), WrC.glow, Color(0xFFD9A53A)])),
                    child: const Text('🎁 받기', style: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 12.5, color: Color(0xFF4A2A10)))))
                // app2/screens-c2.jsx › RewardTab() st==='claimed' 칩 onClick={() => app.go('decor')} 1:1.
                // [버그수정 — 전수감사] 기존엔 탭 핸들러 없는 정적 Container + "✓ 받음"만
                // 표시했다(원본은 "✓ 받음 · 꾸미기 ›" + 꾸미기 탭(탭3)으로 이동).
                else if (claimed)
                  GestureDetector(onTap: () => context.read<WishRoomProvider>().requestTab(3), child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: WrC.glow, borderRadius: BorderRadius.circular(999)),
                    child: const Text('✓ 받음 · 꾸미기 ›', style: TextStyle(color: Color(0xFF4A2A10), fontSize: 11, fontWeight: FontWeight.w700))))
                else
                  Text('${at - n}회 남음', style: WrF.body(11, color: WrC.muted)),
              ]),
            ));
          }),
        ]),
        if (_open != null) _ClaimOverlay(key: ValueKey(_openKey), data: _open!, room: room, onClose: () => setState(() => _open = null)),
      ]);
    });
  }

  String _ownedLabel(Map<String, dynamic> r) => r['reward'] as String;
}

/// 받기 연출 — 상자가 열리고 아이템이 떠오름. 원본 RewardTab() 214-232줄.
class _ClaimOverlay extends StatefulWidget {
  const _ClaimOverlay({super.key, required this.data, required this.room, required this.onClose});
  final Map<String, dynamic> data; final WishRoom room; final VoidCallback onClose;
  @override
  State<_ClaimOverlay> createState() => _ClaimOverlayState();
}

class _ClaimOverlayState extends State<_ClaimOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..forward();
  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final at = widget.data['at'] as int;
    final item = widget.data['item'] as Map<String, dynamic>?;
    final bonus = widget.data['bonus'] as int?;
    final itemName = item?['name'] as String?;
    final itemImg = item?['img'] as String?;
    return Positioned.fill(child: Stack(children: [
      GestureDetector(onTap: widget.onClose, child: Container(color: const Color(0xB3000000))),
      Positioned(left: 24, right: 24, top: 150, child: Container(
        padding: const EdgeInsets.fromLTRB(18, 26, 18, 18),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xF7461E38), Color(0xFA1A0812)]),
          border: Border.all(color: const Color(0x73FFDC96)),
          boxShadow: const [BoxShadow(color: Color(0x4DFFC878), blurRadius: 60), BoxShadow(color: Color(0x99000000), blurRadius: 50, offset: Offset(0, 24))]),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('SUPPORT × $at', style: TextStyle(fontFamily: 'IBMPlexMonoWish', fontSize: 10, letterSpacing: 3, color: const Color(0xFFFFE08A))),
          SizedBox(height: 150, child: Stack(alignment: Alignment.topCenter, clipBehavior: Clip.none, children: [
            AnimatedBuilder(animation: _c, builder: (_, __) {
              final t = Curves.easeOut.transform(_c.value);
              return Positioned(top: 60, child: Opacity(opacity: (t * 3).clamp(0.0, 1.0), child: Transform.scale(scale: .7 + .3 * t,
                child: Image.asset('assets/wishroom/items/chest.png', width: 90, errorBuilder: (_, __, ___) => const Text('🧰', style: TextStyle(fontSize: 60))))));
            }),
            AnimatedBuilder(animation: _c, builder: (_, __) {
              final raw = ((_c.value - .55) / .45).clamp(0.0, 1.0);
              final t = Curves.easeOutCubic.transform(raw);
              return Positioned(top: 20 - 20 * t, child: Opacity(opacity: raw, child:
                itemImg != null
                  ? Image.asset('assets/wishroom/items/$itemImg.png', width: 96, errorBuilder: (_, __, ___) => const Text('🎁', style: TextStyle(fontSize: 70)))
                  : Image.asset('assets/wishroom/items/pouch.png', width: 90, errorBuilder: (_, __, ___) => const Text('💰', style: TextStyle(fontSize: 60)))));
            }),
            if (_c.value > .5) WrBurst(x: 0, y: 70, n: 26, spread: 150, color: const Color(0xFFFFE0A0)),
          ])),
          Text(itemName ?? '복주머니 +${bonus ?? 0}', style: WrF.display(21)),
          const SizedBox(height: 8),
          Text(itemName != null
                ? '응원해주신 마음이 모여 선물이 되었어요.\n보관함에 담아두었어요.'
                : '모든 장식을 이미 가지고 있어 복주머니로 드려요.',
              textAlign: TextAlign.center, style: WrF.body(13, color: WrC.muted, height: 1.6)),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(child: GestureDetector(onTap: widget.onClose, child: Container(
              height: 46, alignment: Alignment.center, decoration: WrDeco.btnDark,
              child: const Text('닫기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))))),
            if (item != null) ...[
              const SizedBox(width: 8),
              // app2/screens-c2.jsx › RewardTab() 받기 연출 "방에 두기" onClick
              // { setOpen(null); app.go('decor') } 1:1. [버그수정 — 전수감사]
              // 기존엔 장착만 하고 꾸미기 탭으로 이동하지 않았다.
              Expanded(flex: 2, child: GestureDetector(onTap: () async {
                final p = context.read<WishRoomProvider>();
                final id = item['id'] as String?;
                if (id != null) await p.equip(widget.room.id, id);
                widget.onClose();
                p.requestTab(3);
              }, child: Container(
                height: 46, alignment: Alignment.center, decoration: WrDeco.btnPink,
                child: const Text('방에 두기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))))),
            ],
          ]),
        ]),
      )),
    ]));
  }
}
