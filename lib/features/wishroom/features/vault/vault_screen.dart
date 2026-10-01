// SCR-09 보관함 `/vault` (탭5) — docs/SCREENS.md §SCR-09
// 탭 3개: 소원 기록관 · 복주머니 · 응원 보상. 우상단 "캐릭터" 칩 → SCR-05.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../application/wishroom_provider.dart';
import '../../data/models.dart';
import '../../data/wr_catalog.dart';
import '../../core/theme/wr_theme.dart';
import '../../core/wr_canvas.dart';
import '../room/room_scene.dart';
import '../characters/character_shop_screen.dart';
import '../compose/compose_screen.dart';
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
    final c = context.wr;
    return Theme(data: wrTheme(WrPalette.midnight), child: Scaffold(
      backgroundColor: c.bg2,
      body: SafeArea(bottom: false, child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 0), child: Row(children: [
          Text('보관함', style: WrType.h1(c.fg)),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CharacterShopScreen())),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(999), border: Border.all(color: c.line)),
              child: Text('캐릭터', style: TextStyle(color: c.fg, fontSize: 12)),
            ),
          ),
        ])),
        TabBar(
          controller: _tabs,
          labelColor: c.fg, unselectedLabelColor: c.muted,
          indicatorColor: c.accent,
          labelStyle: const TextStyle(fontSize: 13),
          tabs: const [Tab(text: '소원 기록관'), Tab(text: '복주머니'), Tab(text: '응원 보상')],
        ),
        Expanded(child: TabBarView(controller: _tabs, children: const [
          _ArchiveTab(), _PouchTab(), _RewardTab(),
        ])),
      ])),
    ));
  }
}

// ═══════════════════ 소원 기록관 ═══════════════════

class _ArchiveTab extends StatefulWidget {
  const _ArchiveTab();
  @override
  State<_ArchiveTab> createState() => _ArchiveTabState();
}

class _ArchiveTabState extends State<_ArchiveTab> {
  bool _ongoing = true;

  @override
  Widget build(BuildContext context) {
    final c = context.wr;
    return Consumer<WishRoomProvider>(builder: (context, p, __) {
      final rooms = p.archiveRooms;
      final ongoing = rooms.where((r) => r.status != RoomStatus.SEALED && r.status != RoomStatus.ARCHIVED).toList();
      final done = rooms.where((r) => r.status == RoomStatus.SEALED || r.status == RoomStatus.ARCHIVED).toList();
      final list = _ongoing ? ongoing : done;
      return RefreshIndicator(onRefresh: () => p.loadArchive(), child: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 8), child: Row(children: [
          _chip('진행 중 (${ongoing.length})', true, c),
          const SizedBox(width: 8),
          _chip('이루어진 소원 (${done.length})', false, c),
        ]))),
        SliverPadding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: .74),
          delegate: SliverChildBuilderDelegate((_, i) {
            if (i == list.length) {
              return GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ComposeScreen())),
                child: DottedBox(c: c),
              );
            }
            final room = list[i];
            return _ArchiveCard(room: room, onTap: () => _openReplay(context, room, p.items));
          }, childCount: list.length + 1),
        )),
      ]));
    });
  }

  Widget _chip(String label, bool ongoing, WrColors c) {
    final sel = _ongoing == ongoing;
    return GestureDetector(onTap: () => setState(() => _ongoing = ongoing), child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: sel ? c.accent : c.card, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(color: sel ? Colors.white : c.fg, fontSize: 12)),
    ));
  }

  void _openReplay(BuildContext context, WishRoom room, List<WrItem> items) {
    showDialog(context: context, barrierColor: const Color(0xE6000000), builder: (_) => _ReplayOverlay(room: room, items: items));
  }
}

class _ArchiveCard extends StatelessWidget {
  const _ArchiveCard({required this.room, required this.onTap});
  final WishRoom room; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.wr;
    final finished = room.status == RoomStatus.SEALED || room.status == RoomStatus.ARCHIVED;
    return GestureDetector(onTap: onTap, child: Container(
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.line)),
      padding: const EdgeInsets.all(10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Stack(children: [
          Positioned.fill(child: ClipRRect(borderRadius: BorderRadius.circular(10),
            child: ColoredBox(color: c.bg1, child: const Center(child: Icon(Icons.local_fire_department, color: Color(0x33FFFFFF), size: 36))))),
          if (finished) Positioned(right: 4, top: 4, child: Transform.rotate(angle: -6 * 3.14159 / 180, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: const Color(0xFFC94A3B), borderRadius: BorderRadius.circular(6)),
            child: const Text('成 완성', style: TextStyle(color: Color(0xFFFFF9E8), fontSize: 10, fontWeight: FontWeight.w700))))),
        ])),
        const SizedBox(height: 6),
        Text(room.text, style: TextStyle(color: c.fg, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Text('${room.daysLit}일째 · Lv.${room.level}', style: TextStyle(color: c.muted, fontSize: 10)),
      ]),
    ));
  }
}

class DottedBox extends StatelessWidget {
  const DottedBox({super.key, required this.c});
  final WrColors c;
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: c.line, width: 1.4)),
        alignment: Alignment.center,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.add, color: c.muted),
          const SizedBox(height: 6),
          Text('새로운 소원방\n만들기', textAlign: TextAlign.center, style: TextStyle(color: c.muted, fontSize: 12)),
        ]),
      );
}

/// 보관된 소원방의 "당시 모습 재생" — 스냅숏 방 + 황금빛 .25 + 꽃잎, 하단 한지 카드.
class _ReplayOverlay extends StatelessWidget {
  const _ReplayOverlay({required this.room, required this.items});
  final WishRoom room; final List<WrItem> items;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Dialog(backgroundColor: Colors.transparent, insetPadding: const EdgeInsets.all(16), child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(children: [
          AspectRatio(aspectRatio: 390 / 844, child: WrCanvasScaler(child: RoomScene(room: room, items: items, gold: .25, frozen: true))),
          Positioned(left: 14, right: 14, bottom: 14, child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xF7FFF4E2), Color(0xF2F7E2C8)]), borderRadius: BorderRadius.circular(14)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(room.text, style: const TextStyle(fontFamily: 'GowunBatangWish', fontSize: 14, color: Color(0xFF4A2A1C)), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Text('${room.daysLit}일 동안 밝혔어요 · ❤${room.supportCount} · 福${room.pouchReceived}', style: const TextStyle(fontSize: 11, color: Color(0x993C2D1E))),
            ]),
          )),
        ]),
      )),
    );
  }
}

// ═══════════════════ 복주머니 ═══════════════════

class _PouchTab extends StatefulWidget {
  const _PouchTab();
  @override
  State<_PouchTab> createState() => _PouchTabState();
}

class _PouchTabState extends State<_PouchTab> {
  bool _adLoading = false;

  Future<void> _earn(String source) async {
    if (source == 'ad') {
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
                if (rewarded) await _doEarn(source);
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
    await _doEarn(source);
  }

  Future<void> _doEarn(String source) async {
    final p = context.read<WishRoomProvider>();
    final res = await p.earn(source);
    if (!mounted) return;
    if (res != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('복주머니 +${res.$1}')));
    } else if (p.lastError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(p.lastError!.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.wr;
    final cat = WrCatalog.I;
    return Consumer<WishRoomProvider>(builder: (context, p, __) {
      final me = p.me;
      final earnList = cat.earn.where((e) => e['auto'] != true).toList();
      return RefreshIndicator(onRefresh: () => p.loadLedger(), child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 22),
          decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: c.line)),
          child: Column(children: [
            const Text('💰', style: TextStyle(fontSize: 42)),
            const SizedBox(height: 8),
            Text('${me?.pouch ?? 0}', style: TextStyle(color: c.glow, fontFamily: 'NotoSerifKRWish', fontWeight: FontWeight.w900, fontSize: 32)),
            Text('복주머니', style: TextStyle(color: c.muted, fontSize: 12)),
          ]),
        ),
        const SizedBox(height: 18),
        Text('복주머니 모으기', style: WrType.h3(c.fg)),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: .92),
          itemCount: earnList.length,
          itemBuilder: (_, i) {
            final e = earnList[i];
            final id = e['id'] as String;
            final used = me?.earnToday[id] ?? 0;
            final limit = (e['limit'] as num).toInt();
            final full = used >= limit;
            return GestureDetector(
              onTap: full || (id == 'ad' && _adLoading) ? null : () => _earn(id),
              child: Opacity(opacity: full ? .5 : 1, child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF9A6AFF), Color(0xFF6A3AD8)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (id == 'ad' && _adLoading) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  else Text('+${e['amount']}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(e['label'] as String, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 10), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('$used/$limit', style: const TextStyle(color: Colors.white70, fontSize: 9)),
                ]),
              )),
            );
          },
        ),
        const SizedBox(height: 22),
        Text('사용처', style: WrType.h3(c.fg)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.line)),
          child: Column(children: [
            _useRow('캐릭터 함께하기', '80 ~ 500', c),
            _useRow('꾸미기 아이템', '아이템별 상이', c),
            _useRow('다른 소원방에 선물', '5 · 10 · 30 · 50', c),
          ]),
        ),
        const SizedBox(height: 22),
        Text('내역', style: WrType.h3(c.fg)),
        const SizedBox(height: 8),
        if (p.ledger.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Center(child: Text('아직 내역이 없어요', style: TextStyle(color: c.muted, fontSize: 12))))
        else ...p.ledger.take(30).map((e) => Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [
              Expanded(child: Text((e['reason'] ?? e['label'] ?? '').toString(), style: TextStyle(color: c.fg, fontSize: 12))),
              Text('${((e['amount'] ?? 0) as num) >= 0 ? '+' : ''}${e['amount'] ?? 0}', style: TextStyle(color: ((e['amount'] ?? 0) as num) >= 0 ? c.glow : c.muted, fontSize: 12, fontWeight: FontWeight.w700)),
            ]))),
      ]));
    });
  }

  Widget _useRow(String label, String value, WrColors c) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [
        Expanded(child: Text(label, style: TextStyle(color: c.fg, fontSize: 12))),
        Text(value, style: TextStyle(color: c.muted, fontSize: 12)),
      ]));
}

// ═══════════════════ 응원 보상 ═══════════════════

class _RewardTab extends StatefulWidget {
  const _RewardTab();
  @override
  State<_RewardTab> createState() => _RewardTabState();
}

class _RewardTabState extends State<_RewardTab> {
  Future<void> _claim(WishRoomProvider p, String id, int at) async {
    final res = await p.claimSupportReward(id, at);
    if (!mounted) return;
    if (res != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('보상을 받았어요')));
    } else if (p.lastError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(p.lastError!.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.wr;
    final cat = WrCatalog.I;
    return Consumer<WishRoomProvider>(builder: (context, p, __) {
      final room = p.room;
      if (room == null) return Center(child: Text('소원방이 없어요', style: TextStyle(color: c.muted)));
      final rewards = cat.supportRewards;
      final serverStates = {for (final r in room.rewards ?? const <SupportRewardState>[]) r.at: r};
      final supportCount = room.supportCount;
      final nextAt = rewards.map((e) => e['at'] as int).where((a) => a > supportCount).fold<int?>(null, (p0, a) => p0 == null || a < p0 ? a : p0);
      final progress = nextAt == null ? 1.0 : (supportCount / nextAt).clamp(0, 1).toDouble();
      return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.line)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('받은 응원 $supportCount회', style: TextStyle(color: c.fg, fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
              value: progress, minHeight: 8, backgroundColor: c.bg1,
              valueColor: AlwaysStoppedAnimation(c.accent))),
            const SizedBox(height: 6),
            if (nextAt != null) Text('다음 보상까지 ${nextAt - supportCount}회', style: TextStyle(color: c.muted, fontSize: 11)),
          ]),
        ),
        const SizedBox(height: 16),
        ...rewards.map((r) {
          final at = r['at'] as int;
          final state = serverStates[at];
          final reached = state?.reached ?? (supportCount >= at);
          final claimed = state?.claimed ?? false;
          return Padding(padding: const EdgeInsets.only(bottom: 10), child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.card, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: reached && !claimed ? c.glow : c.line, width: reached && !claimed ? 1.6 : 1),
            ),
            child: Row(children: [
              Container(width: 44, height: 44, alignment: Alignment.center,
                decoration: BoxDecoration(color: c.bg1, borderRadius: BorderRadius.circular(12)),
                child: Text(_rewardGlyph(r['icon'] as String), style: const TextStyle(fontSize: 20))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$at회 · ${r['reward']}', style: TextStyle(color: c.fg, fontSize: 13, fontWeight: FontWeight.w600)),
                Text(r['desc'] as String, style: TextStyle(color: c.muted, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
              if (claimed)
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: c.accent.withValues(alpha: .18), borderRadius: BorderRadius.circular(999), border: Border.all(color: c.glow)),
                  child: Text('획득', style: TextStyle(color: c.glow, fontSize: 11)))
              else if (reached)
                GestureDetector(onTap: () => _claim(p, room.id, at), child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: c.glow, borderRadius: BorderRadius.circular(999)),
                  child: const Text('받기', style: TextStyle(color: Color(0xFF4A2A10), fontSize: 11, fontWeight: FontWeight.w700))))
              else
                Text('$supportCount/$at', style: TextStyle(color: c.muted, fontSize: 11)),
            ]),
          ));
        }),
      ]);
    });
  }

  String _rewardGlyph(String icon) => switch (icon) {
        'petal' => '🌸', 'spark' => '✨', 'gift' => '🎁', 'chest' => '🧧', 'star' => '⭐', _ => '✦',
      };
}
