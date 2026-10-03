// SCR-04 꾸미기 `/decor` (탭4) — docs/CHANGELOG.md · app2/screens-b2.jsx › Decor() 1:1 이식
// 상단 방 미리보기(캐릭터 숨김, 선택 슬롯에 따라 카메라 포커스 이동)
// + "지금 켜진 기운" 뱃지 목록 + TopBar(안내서 · 복주머니)
// + 바텀패널: THEME를 맨 앞에 두는 슬롯칩 + 3열 그리드(등급 TIER · 기운 FxBadge)
// + THEME 슬롯 선택 시 ThemeSwitch(테마 전환 칩 + TIER 범례)
// + 아이템 탭 → ItemCard 바텀시트(설명 + 효과 + 구매/적용/자리옮기기)
// + 배치 성공 시 PlaceFx(빛기둥+링+버스트+라벨) 연출
// + 하단 고정 "적용하고 소원방 보기" 버튼
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../application/wishroom_provider.dart';
import '../../data/models.dart';
import '../../data/wr_catalog.dart';
import '../../core/theme/wr_theme.dart';
import '../../core/wr_canvas.dart';
import '../room/room_scene.dart';
import '../room/room_layout.dart' as layout;
import '../guide/guide_sheet.dart';
import '../../core/wr_nav_pill.dart';
import '../wallet/wallet_sheet.dart';
import '../../core/wr_ad_earn_button.dart';

class DecorScreen extends StatefulWidget {
  const DecorScreen({super.key});
  @override
  State<DecorScreen> createState() => _DecorScreenState();
}

class _DecorScreenState extends State<DecorScreen> {
  Slot _slot = Slot.THEME; // 원본: const [slot, setSlot] = useState('THEME')
  WrItem? _preview; // pv — 미보유 아이템 임시 미리보기
  WrItem? _card; // card — 탭한 아이템(ItemCard 시트)
  _Placed? _placed; // 배치 성공 직후 PlaceFx 연출
  WrItem? _moving; // PlaceMode 진입 아이템
  ApiError? _shortErr;
  WrItem? _shortItem; // app2/screens-b2.jsx › Shortage({name, icon}) — 부족한 아이템 자체(아이콘+이름 표시용)
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final p = context.read<WishRoomProvider>();
    if (!p.catalogLoaded) p.loadCatalog();
  }

  bool _isOn(WrItem it, WishRoom room) => room.equip.all.contains(it.id);
  bool _multi(Slot s) => _slotMax(s) > 1;
  int _slotMax(Slot s) {
    switch (s) {
      case Slot.DECORATION: return 5;
      case Slot.SEAL: return 3;
      case Slot.THEME: return 5;
      default: return 1;
    }
  }

  void _tap(WrItem it, WishRoom room) {
    if (it.id.endsWith('_none')) { _equip(it, room); return; }
    setState(() { _card = it; if (!_isOn(it, room)) _preview = it; });
  }

  Future<void> _equip(WrItem it, WishRoom room, {bool bought = false}) async {
    final p = context.read<WishRoomProvider>();
    final ok = await p.equip(room.id, it.id);
    if (!mounted) return;
    if (!ok) {
      final err = p.lastError;
      if (err != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.message)));
      return;
    }
    setState(() { _preview = null; _card = null; });
    _place(it, p.room!, bought: bought);
  }

  void _place(WrItem it, WishRoom room, {bool bought = false, bool moved = false}) {
    final on = room.equip.all.contains(it.id);
    if (it.id.endsWith('_none') || !on) { setState(() => _placed = null); return; }
    final at = layout.focusOf(it, room.equip, context.read<WishRoomProvider>().items, room.layout);
    final key = DateTime.now().millisecondsSinceEpoch;
    setState(() => _placed = _Placed(it: it, at: at, key: key, room: room, bought: bought, moved: moved));
    Timer(const Duration(milliseconds: 4600), () {
      if (mounted && _placed != null && DateTime.now().millisecondsSinceEpoch - _placed!.key > 4400) {
        setState(() => _placed = null);
      }
    });
  }

  Future<void> _buy(WrItem it, WishRoom room) async {
    if (_busy) return;
    setState(() => _busy = true);
    final p = context.read<WishRoomProvider>();
    final ok = await p.buyItem(it.id);
    if (!mounted) return;
    if (!ok) {
      setState(() => _busy = false);
      final err = p.lastError;
      if (err?.code == 'INSUFFICIENT') {
        setState(() { _shortErr = err; _shortItem = it; });
      } else if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.message)));
      }
      return;
    }
    // 구매 성공 → 바로 장착
    final freshRoom = p.room!;
    final freshItem = p.items.where((i) => i.id == it.id).firstOrNull ?? it;
    await _equip(freshItem, freshRoom, bought: true);
    if (mounted) setState(() => _busy = false);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(data: wrThemeData(), child: Scaffold(
      backgroundColor: WrC.bg2,
      body: Consumer<WishRoomProvider>(builder: (context, p, __) {
        final room = p.room;
        if (room == null) return const Center(child: CircularProgressIndicator(color: Color(0xFFF5CF6A)));
        final cat = WrCatalog.I;
        final eq = room.equip;
        // 미리보기(미보유 선택) 반영한 가상 room
        final pvRoom = _previewRoom(room, eq);
        final zone = _zone(_slot);
        final fy = _placed != null
            ? _placed!.at.dy
            : (_preview != null ? layout.focusOf(_preview!, pvRoom.equip, p.items, room.layout).dy : zone);
        final camTop = -math.max(0.0, math.min(844.0 - 380.0, fy - 185.0));

        return Column(children: [
          SizedBox(height: 400, child: Stack(clipBehavior: Clip.hardEdge, children: [
            Positioned.fill(child: ClipRect(child: WrCanvasScaler(child: AnimatedContainer(
              duration: const Duration(milliseconds: 1000),
              curve: const Cubic(.22, 1, .36, 1),
              transform: Matrix4.translationValues(0, camTop, 0),
              child: RoomScene(
                room: pvRoom, items: p.items, hideChar: true,
                fx: _placed != null ? [
                  _PlaceFx(key: ValueKey(_placed!.key), it: _placed!.it, at: _placed!.at, bought: _placed!.bought, moved: _placed!.moved),
                  _EffectOn(key: ValueKey('e${_placed!.key}'), it: _placed!.it, room: _placed!.room),
                ] : const [],
              ),
            )))),
            Positioned.fill(child: IgnorePointer(child: Container(
              decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0x33000000), Colors.transparent, Colors.transparent, WrC.bg2], stops: [0, .3, .7, 1])),
            ))),
            if (_preview != null && _card == null) Positioned(top: 104, left: 0, right: 0, child: Center(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(color: WrC.glass, borderRadius: BorderRadius.circular(999)),
              child: Text('미리보기 · ${_preview!.name}', style: WrF.body(12, w: FontWeight.w700, color: WrC.blossom2)),
            ))),
            // 지금 켜진 기운
            if (_fxList(room.effects).isNotEmpty) Positioned(left: 12, right: 12, top: 318, child: Wrap(
              spacing: 4, runSpacing: 4, alignment: WrapAlignment.center,
              children: _fxList(room.effects).map((t) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xB3140810), borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0x59FFDCA0))),
                child: Text(t, style: const TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w800, fontSize: 10.5, color: Color(0xFFFFE6B8))),
              )).toList(),
            )),
            SafeArea(bottom: false, child: Padding(padding: const EdgeInsets.fromLTRB(14, 10, 14, 0), child: Row(children: [
              // app2/screens-b2.jsx › Decor() TopBar(left=? 안내서버튼) — nav 기본값
              // true로 NavPill이 그 왼쪽에 함께 온다. [버그수정 — 전수감사] 기존엔
              // NavPill이 전혀 없었다.
              WrNavPill(onBack: () => wrBackOrAskExit(context), onExitHome: () => wrExitHome(context)),
              const SizedBox(width: 6),
              GestureDetector(onTap: _openGuide, child: Container(width: 32, height: 32, alignment: Alignment.center,
                decoration: BoxDecoration(color: WrC.glass, shape: BoxShape.circle, border: Border.all(color: WrC.line)),
                child: const Text('?', style: TextStyle(fontFamily: 'NotoSerifKRWish', fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white)))),
              const Expanded(child: Center(child: Text('내 소원방 꾸미기', style: TextStyle(fontFamily: 'GowunBatangWish', fontWeight: FontWeight.w700, fontSize: 15, color: Colors.white)))),
              // app2/screens-b2.jsx › Decor() right={<PouchPill ... onClick={app.openWallet}/>} [버그수정 — 전수감사]
              // 기존엔 탭 핸들러가 전혀 없는 정적 Container였다.
              GestureDetector(onTap: () => openWalletSheet(context), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: WrC.glass, borderRadius: BorderRadius.circular(999)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Image.asset('assets/wishroom/items/pouch.png', width: 16, height: 16,
                      errorBuilder: (_, __, ___) => const Text('💰', style: TextStyle(fontSize: 14))),
                  const SizedBox(width: 5),
                  Text('${p.me?.pouch ?? 0}', style: const TextStyle(fontFamily: 'NotoSerifKRWish', fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white)),
                ]),
              )),
            ]))),
          ])),
          Expanded(child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF3A1630), Color(0xFF1A0812)]),
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              border: Border(top: BorderSide(color: Color(0x40FFBED2))),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(padding: const EdgeInsets.fromLTRB(14, 14, 14, 10), child: SizedBox(height: 32, child: ListView(
                scrollDirection: Axis.horizontal,
                children: _orderedSlots().map((s) {
                  final sel = _slot == s;
                  final themeInfo = s == Slot.THEME ? cat.themes.where((t) => t['id'] == room.theme.name).toList() : const [];
                  final T = themeInfo.isNotEmpty ? themeInfo.first : null;
                  final label = _slotLabel(s, room);
                  return Padding(padding: const EdgeInsets.only(right: 6), child: GestureDetector(
                    onTap: () => setState(() { _slot = s; _preview = null; }),
                    child: Container(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                      decoration: sel ? WrDeco.chipOn : (T != null
                          ? BoxDecoration(borderRadius: BorderRadius.circular(999), color: WrC.chipBg,
                              border: Border.all(color: const Color(0x8CFFD68C)),
                              boxShadow: const [BoxShadow(color: Color(0x40FFC878), blurRadius: 12)])
                          : WrDeco.chip),
                      child: Text('${T != null ? '${T['glyph']} ' : ''}$label',
                        style: WrF.body(12, w: FontWeight.w700, color: sel ? Colors.white : (T != null ? const Color(0xFFFFE0A8) : WrC.fg))),
                    ),
                  ));
                }).toList(),
              ))),
              Expanded(child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 110),
                child: _slot == Slot.THEME
                    ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _themeSwitch(room),
                        const SizedBox(height: 10),
                        _itemGrid(room, p, Slot.THEME, themeOnly: true),
                      ])
                    : _itemGrid(room, p, _slot),
              )),
            ]),
          )),
          Align(alignment: Alignment.bottomCenter, child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 26),
            decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Colors.transparent, Color(0xFF1A0812)], stops: [0, .35])),
            child: SizedBox(height: 50, child: ElevatedButton(
              onPressed: () => Navigator.of(context).maybePop(),
              style: ElevatedButton.styleFrom(backgroundColor: WrC.blossom, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: const Text('적용하고 소원방 보기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
            )),
          )),
        ]).let((col) => Stack(children: [
          col,
          if (_card != null) _itemCardSheet(room, p, _card!),
          if (_moving != null) _PlaceModeView(it: _moving!, room: room, items: p.items,
            onDone: (patch) async {
              final it = _moving!;
              setState(() => _moving = null);
              if (patch != null) {
                final ok = await context.read<WishRoomProvider>().setLayout(room.id, it.id,
                  x: patch.reset ? null : patch.x, y: patch.reset ? null : patch.y, s: patch.reset ? null : patch.s, reset: patch.reset);
                if (ok && mounted) {
                  final rm = context.read<WishRoomProvider>().room!;
                  _place(it, rm, moved: true);
                }
              }
            }),
          if (_shortErr != null) _shortageSheet(_shortErr!, _shortItem),
        ]));
      }),
    ));
  }

  List<Slot> _orderedSlots() => [Slot.THEME, ...Slot.values.where((s) => s != Slot.THEME)];

  double _zone(Slot s) {
    switch (s) {
      case Slot.CANDLE: return 400;
      case Slot.FLOWER: return 520;
      case Slot.DECORATION: return 190;
      case Slot.BACKGROUND: return 214;
      case Slot.SPECIAL: return 280;
      case Slot.SEAL: return 500;
      case Slot.THEME: return 260;
    }
  }

  List<String> _fxList(Effects fx) => [
        if (fx.devo > 0) '정성 +${fx.devo}%',
        if (fx.support > 0) '응원 +${fx.support}%',
        if (fx.cool > 0) '머금기 -${fx.cool}초',
        if (fx.daily > 0) '하루 +${fx.daily}회',
        if (fx.pouch > 0) '복 +${fx.pouch}',
        if (fx.decay > 0) '불빛 ${fx.decay}%↑',
      ];

  WishRoom _previewRoom(WishRoom room, Equip eq) {
    if (_preview == null || _isOn(_preview!, room)) return room;
    final it = _preview!;
    final max = _slotMax(it.slot);
    Map<String, dynamic> equipJson = {
      'CANDLE': eq.candle, 'FLOWER': eq.flower, 'BACKGROUND': eq.background, 'SPECIAL': eq.special,
      'DECORATION': eq.decoration, 'SEAL': eq.seal, 'THEME': eq.theme,
    };
    final key = it.slot.name;
    if (_multi(it.slot)) {
      final list = List<String>.from(equipJson[key] as List);
      list.add(it.id);
      if (list.length > max) list.removeRange(0, list.length - max);
      equipJson[key] = list;
    } else {
      equipJson[key] = it.id;
    }
    return WishRoom.fromJson({
      'id': room.id, 'ownerId': room.ownerId, 'owner': room.owner, 'region': room.region, 'text': room.text, 'char': room.char,
      'status': room.status.name, 'visibility': room.visibility.name, 'theme': room.theme.name,
      'outfit': room.outfit?.name, 'outfitNow': room.outfitNow.name, 'wishColor': room.wishColor, 'paper': room.paper,
      'devotionCount': room.devotionCount, 'supportCount': room.supportCount, 'pouchReceived': room.pouchReceived,
      'level': room.level, 'commentCount': room.commentCount, 'points': room.points, 'levelName': room.levelName,
      'curLevelPts': room.curLevelPts, 'nextLevelPts': room.nextLevelPts, 'brightness': room.brightness, 'decayLabel': room.decayLabel,
      'decayBadge': room.decayBadge, 'isMine': room.isMine, 'supportedToday': room.supportedToday,
      'absentDays': room.absentDays, 'devotionsToday': room.devotionsToday, 'devotionsRemaining': room.devotionsRemaining,
      'dailyLimit': room.dailyLimit, 'cooldownSec': room.cooldownSec, 'daysLit': room.daysLit,
      'equip': equipJson,
      'layout': room.layout.map((k, v) => MapEntry(k, {'x': v.x, 'y': v.y, 's': v.s})),
    });
  }

  String _slotLabel(Slot s, WishRoom room) {
    switch (s) {
      case Slot.CANDLE: return '촛불';
      case Slot.FLOWER: return '꽃';
      case Slot.DECORATION: return '장식 ${room.equip.decoration.length}/5';
      case Slot.BACKGROUND: return '배경';
      case Slot.SPECIAL: return '특별';
      case Slot.SEAL: return '인장 ${room.equip.seal.length}/3';
      case Slot.THEME: return '테마 소품 ${room.equip.theme.length}/5';
    }
  }

  Widget _themeSwitch(WishRoom room) {
    final cat = WrCatalog.I;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('소원방 테마 · 테마를 바꾸면 방 분위기와 수호자 의상이 함께 바뀌어요',
        style: WrF.body(11, color: WrC.muted)),
      const SizedBox(height: 6),
      Row(children: cat.themes.map((t) {
        final on = room.theme.name == t['id'];
        return Expanded(child: Padding(padding: const EdgeInsets.only(right: 6), child: GestureDetector(
          onTap: () => _switchTheme(room, t['id'] as String, t['label'] as String),
          child: Container(padding: const EdgeInsets.symmetric(vertical: 8), alignment: Alignment.center,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(999),
              color: on ? WrC.blossom : WrC.chipBg,
              border: Border.all(color: on ? Colors.transparent : _hex(t['color'] as String))),
            child: Text('${t['glyph']} ${t['label']}', style: WrF.body(11.5, w: FontWeight.w700, color: on ? Colors.white : WrC.fg),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
        )));
      }).toList()),
      const SizedBox(height: 8),
      Wrap(spacing: 10, children: _tierEntries().map((e) => Text('● ${e.value}', style: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 10.5, color: e.key))).toList()),
    ]);
  }

  List<MapEntry<Color, String>> _tierEntries() => const [
        MapEntry(Color(0xFFC8F5D4), '무료'),
        MapEntry(Color(0xFFFFE08A), '🧧 일반'),
        MapEntry(Color(0xFFE8C8FF), '✨ 특별'),
      ];

  Color _tierColor(String? tier) {
    switch (tier) {
      case 'normal': return const Color(0xFFFFE08A);
      case 'special': return const Color(0xFFE8C8FF);
      default: return const Color(0xFFC8F5D4);
    }
  }

  String _tierLabel(String? tier) {
    switch (tier) {
      case 'normal': return '🧧 일반';
      case 'special': return '✨ 특별';
      default: return '무료';
    }
  }

  Future<void> _switchTheme(WishRoom room, String id, String label) async {
    if (_busy || room.theme.name == id) return;
    setState(() => _busy = true);
    final p = context.read<WishRoomProvider>();
    final ok = await p.setTheme(room.id, WrTheme.values.byName(id));
    if (mounted) {
      setState(() => _busy = false);
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label 소원방으로 바뀌었어요')));
      } else if (p.lastError != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(p.lastError!.message)));
      }
    }
  }

  Widget _itemGrid(WishRoom room, WishRoomProvider p, Slot slot, {bool themeOnly = false}) {
    final items = p.items.where((i) {
      if (i.slot != slot) return false;
      final visible = i.price != null || i.owned || i.reward != null;
      if (!visible) return false;
      if (slot == Slot.THEME) return i.theme?.name == room.theme.name || _isOn(i, room);
      return true;
    }).toList();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 2),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 9, crossAxisSpacing: 9, childAspectRatio: .8),
      itemBuilder: (_, i) {
        final it = items[i];
        final on = _isOn(it, room);
        final isPreview = _preview?.id == it.id;
        return GestureDetector(onTap: () => _tap(it, room), child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: on ? const Color(0x24F2628F) : WrC.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: on || isPreview ? WrC.blossom2 : WrC.cardBorder, width: on || isPreview ? 1.6 : 1),
            boxShadow: on ? const [BoxShadow(color: Color(0x40F2628F), blurRadius: 16)] : const [],
          ),
          child: Stack(children: [
            Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(height: 56, child: Center(child: it.asset != null
                  ? Image.asset(it.asset!, fit: BoxFit.contain, errorBuilder: (_, __, ___) => Text(it.glyph ?? '✦', style: const TextStyle(fontSize: 30)))
                  : Text(it.glyph ?? '✦', style: const TextStyle(fontSize: 30)))),
              const SizedBox(height: 3),
              Text(it.name, style: WrF.body(12, w: FontWeight.w700, color: WrC.fg), maxLines: 1, overflow: TextOverflow.ellipsis),
              if (it.tier != null) Text(_tierLabel(it.tier), style: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 9.5, color: _tierColor(it.tier))),
              if (it.effect != null) Padding(padding: const EdgeInsets.only(top: 2), child: _fxBadge(it, room, big: false)),
              const SizedBox(height: 2),
              Row(mainAxisSize: MainAxisSize.min, children: [
                if (!it.owned && it.price == null) Text('❤ 응원 ${it.reward}회', style: const TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 11, color: WrC.glow))
                else if (!it.owned) ...[
                  Image.asset('assets/wishroom/items/pouch.png', width: 13, height: 13,
                      errorBuilder: (_, __, ___) => const Text('💰', style: TextStyle(fontSize: 11))),
                  const SizedBox(width: 2),
                  Text('${it.price}', style: const TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 11, color: WrC.glow)),
                ] else Text(on ? '놓여 있음' : (it.reward != null ? '응원 보상' : '보유'), style: const TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 11, color: WrC.muted)),
              ]),
            ]),
            if (on) Positioned(top: 0, right: 0, child: Container(width: 18, height: 18,
              decoration: const BoxDecoration(color: WrC.blossom, shape: BoxShape.circle, boxShadow: [BoxShadow(color: WrC.blossom, blurRadius: 8)]),
              child: const Icon(Icons.check, size: 11, color: Colors.white))),
          ]),
        ));
      },
    );
  }

  Widget _fxBadge(WrItem it, WishRoom room, {required bool big}) {
    if (it.effect == null) return const SizedBox.shrink();
    final cat = WrCatalog.I;
    final c = cat.wishColors.where((x) => x['id'] == it.aura).toList();
    final C = c.isNotEmpty ? c.first : null;
    final match = it.aura != 'all' && room.wishColor == it.aura;
    final v = (it.effect!.type == 'daily' || it.effect!.type == 'decay') ? it.effect!.v : (it.effect!.v * (match ? 1.5 : 1)).round();
    final label = _effectLabel(it.effect!.type, v, big: big);
    final color = C != null ? _hex(C['color'] as String) : const Color(0xFFFFE08A);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: big ? 10 : 6, vertical: big ? 4 : 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: match ? null : const Color(0x59000000),
        gradient: match ? const LinearGradient(colors: [Color(0xFFFFE08A), Color(0xFFFFB0C8)]) : null,
        border: Border.all(color: color.withValues(alpha: .6)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: big ? 7 : 5, height: big ? 7 : 5, decoration: BoxDecoration(shape: BoxShape.circle, color: color,
          boxShadow: [BoxShadow(color: color, blurRadius: 6)])),
        const SizedBox(width: 3),
        Text('$label${match && big ? ' · 궁합 ×1.5' : ''}', style: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w800,
          fontSize: big ? 12 : 9.5, color: match ? const Color(0xFF3A1A14) : const Color(0xFFFFE6C8))),
      ]),
    );
  }

  String _effectLabel(String type, int v, {required bool big}) {
    if (big) {
      switch (type) {
        case 'devo': return '정성 1회 성장 +$v%';
        case 'support': return '받는 응원 효과 +$v%';
        case 'cool': return '머금는 시간 −$v초';
        case 'daily': return '하루 정성 +$v회';
        case 'pouch': return '정성 10회 보너스 복주머니 +$v';
        case 'decay': return '촛불이 $v% 아래로 약해지지 않아요';
      }
    } else {
      switch (type) {
        case 'devo': return '정성 +$v%';
        case 'support': return '응원 +$v%';
        case 'cool': return '−$v초';
        case 'daily': return '하루 +$v회';
        case 'pouch': return '복 +$v';
        case 'decay': return '불빛 $v%↑';
      }
    }
    return '';
  }

  Widget _itemCardSheet(WishRoom room, WishRoomProvider p, WrItem card) {
    final it = p.items.where((i) => i.id == card.id).firstOrNull ?? card;
    final on = _isOn(it, room);
    final cat = WrCatalog.I;
    final c = cat.wishColors.where((x) => x['id'] == it.aura).toList();
    final C = c.isNotEmpty ? c.first : null;
    final my = cat.wishColors.where((x) => x['id'] == room.wishColor).toList();
    final match = it.aura != 'all' && room.wishColor == it.aura;
    final canPlace = [Slot.FLOWER, Slot.DECORATION, Slot.SEAL, Slot.THEME].contains(it.slot) && on;
    return Stack(children: [
      Positioned.fill(child: GestureDetector(onTap: () => setState(() { _card = null; _preview = null; }),
        child: Container(color: const Color(0x80000000)))),
      Positioned(left: 10, right: 10, bottom: 22, child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        decoration: WrDeco.sheet,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 14), alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          Text('ITEM · ${_slotLabel(it.slot, room).split(' ').first}', style: WrF.mono(size: 10.5)),
          const SizedBox(height: 4),
          Text(it.name, style: WrF.display(19, color: Colors.white)),
          const SizedBox(height: 14),
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Container(width: 84, height: 84, alignment: Alignment.center,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: WrC.line),
                gradient: RadialGradient(colors: [(C != null ? _hex(C['color'] as String).withValues(alpha: .25) : const Color(0x40FFDCA0)), Colors.transparent])),
              child: it.asset != null ? Image.asset(it.asset!, fit: BoxFit.contain, errorBuilder: (_, __, ___) => Text(it.glyph ?? '✦', style: const TextStyle(fontSize: 42))) : Text(it.glyph ?? '✦', style: const TextStyle(fontSize: 42))),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(C != null ? '${C['hanja']} · ${C['label']}의 기운' : '✦ 모든 소원의 기운',
                style: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 11, color: C != null ? _hex(C['color'] as String) : WrC.glow)),
              const SizedBox(height: 4),
              Text(it.desc ?? '', style: WrF.body(13.5, color: Colors.white, height: 1.6)),
            ])),
          ]),
          if (it.effect != null) Container(
            margin: const EdgeInsets.only(top: 14), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: match ? const Color(0x14FFDC82) : WrC.card,
              border: Border.all(color: match ? const Color(0x99FFDC82) : WrC.cardBorder)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('방에 두면', style: WrF.mono(size: 10, color: WrC.blossom2)),
              const SizedBox(height: 8),
              _fxBadge(it, room, big: true),
              const SizedBox(height: 8),
              Text(match ? '내 소원(${my.isNotEmpty ? my.first['label'] : ''})과 같은 기운이라 효과가 1.5배예요.'
                  : it.aura == 'all' ? '어떤 소원에도 같은 힘을 내요.' : '${C != null ? C['label'] : ''} 소원이라면 효과가 1.5배가 돼요.',
                style: WrF.body(12, color: WrC.muted, height: 1.6)),
            ]),
          ),
          const SizedBox(height: 16),
          Row(children: [
            if (!it.owned && it.price == null) Expanded(child: SizedBox(height: 50, child: ElevatedButton(
              onPressed: null,
              style: ElevatedButton.styleFrom(backgroundColor: WrC.darkBtn),
              child: Text('❤ 응원 ${it.reward}회를 받으면 열려요', style: WrF.body(13, color: Colors.white54)),
            )))
            else if (!it.owned) Expanded(child: SizedBox(height: 50, child: ElevatedButton(
              onPressed: _busy ? null : () => _buy(it, room),
              style: ElevatedButton.styleFrom(backgroundColor: WrC.blossom),
              child: Text('💰 ${it.price} · 방에 들이기', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            )))
            else if (on) ...[
              if (canPlace) Expanded(flex: 2, child: Padding(padding: const EdgeInsets.only(right: 8), child: SizedBox(height: 50, child: ElevatedButton(
                onPressed: () => setState(() { _moving = it; _card = null; }),
                style: ElevatedButton.styleFrom(backgroundColor: WrC.glow),
                child: const Text('✥ 자리 옮기기', style: TextStyle(color: Color(0xFF4A2A10), fontWeight: FontWeight.w700)),
              )))),
              Expanded(child: SizedBox(height: 50, child: ElevatedButton(
                onPressed: () => _equip(it, room),
                style: ElevatedButton.styleFrom(backgroundColor: WrC.darkBtn),
                child: Text([Slot.FLOWER, Slot.SPECIAL, Slot.CANDLE, Slot.BACKGROUND].contains(it.slot) ? '놓여 있어요' : '치우기',
                  style: WrF.body(13, color: Colors.white)),
              ))),
            ]
            else Expanded(child: SizedBox(height: 50, child: ElevatedButton(
              onPressed: () => _equip(it, room),
              style: ElevatedButton.styleFrom(backgroundColor: WrC.blossom),
              child: const Text('방에 두기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ))),
          ]),
        ]),
      )),
    ]);
  }

  // app2/screens-b2.jsx › Shortage({app, name, icon, need, have, onClose}) 1:1 이식.
  // [버그수정 — 전수감사] 기존엔 ApiError만 받아 부족한 아이템의 아이콘+이름 카드가
  // 전혀 없었고(바로 "복주머니 n개 필요" 텍스트로 시작), "다른 방법으로 모으기" 버튼도
  // 그냥 닫기만 했다. 원본은 onClose(); app.openWallet()으로 지갑 시트를 띄운다.
  Widget _shortageSheet(ApiError e, WrItem? item) {
    return Stack(children: [
      Positioned.fill(child: GestureDetector(onTap: () => setState(() { _shortErr = null; _shortItem = null; }), child: Container(color: const Color(0x80000000)))),
      Positioned(left: 10, right: 10, bottom: 22, child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        decoration: WrDeco.sheet,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 14), alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          Text('NEED MORE', style: WrF.mono(size: 10.5)),
          const SizedBox(height: 4),
          Text('복주머니가 조금 부족해요', style: WrF.display(18, color: Colors.white)),
          const SizedBox(height: 14),
          if (item != null) Container(
            padding: const EdgeInsets.all(14),
            decoration: WrDeco.card,
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              SizedBox(width: 64, child: Center(child: ColorFiltered(
                colorFilter: const ColorFilter.matrix(_grayscale30),
                child: item.asset != null
                    ? Image.asset(item.asset!, width: 48, height: 48, fit: BoxFit.contain, errorBuilder: (_, __, ___) => Text(item.glyph ?? '✦', style: const TextStyle(fontSize: 36)))
                    : Text(item.glyph ?? '✦', style: const TextStyle(fontSize: 36)),
              ))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.name, style: WrF.body(14, w: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 2),
                Text('복주머니 ${e.need ?? '-'}개 필요', style: WrF.body(12.5, color: WrC.muted)),
              ])),
            ]),
          ),
          SizedBox(height: item != null ? 14 : 0),
          Text('지금 ${e.have ?? 0}개 · ${(e.need ?? 0) - (e.have ?? 0)}개 더 모으면 돼요', style: WrF.body(14, color: Colors.white, height: 1.7)),
          Container(margin: const EdgeInsets.only(top: 12), padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: WrC.line, style: BorderStyle.solid)),
            child: Text('복주머니는 신통방통 어디서나 함께 쓰는 재화예요.\n출석, 정성, 짧은 영상으로 조금씩 담깁니다.', style: WrF.body(13, color: WrC.muted, height: 1.7))),
          const SizedBox(height: 16),
          WrAdEarnButton(onDone: () => setState(() { _shortErr = null; _shortItem = null; })),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, height: 46, child: OutlinedButton(
            onPressed: () {
              setState(() { _shortErr = null; _shortItem = null; });
              openWalletSheet(context);
            },
            style: OutlinedButton.styleFrom(side: const BorderSide(color: WrC.line)),
            child: Text('다른 방법으로 모으기', style: WrF.body(14, color: Colors.white)),
          )),
        ]),
      )),
    ]);
  }

  // app2/screens-b2.jsx › app.openGuide('decor') 1:1 — guide2.jsx GuideBook(focus:'decor') 재사용.
  // GuideBook의 "한 바퀴 둘러보기"는 app.room && 조건만 보므로 꾸미기에서도 항상 노출되고,
  // 누르면 app.go('home') 후 startTour() — Provider.requestTour()로 셸이 탭 전환을 대신한다.
  void _openGuide() {
    final p = context.read<WishRoomProvider>();
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (_) => GuideBook(focus: 'decor', onStartTour: p.requestTour));
  }
}

class _Placed {
  final WrItem it; final Offset at; final int key; final WishRoom room; final bool bought, moved;
  _Placed({required this.it, required this.at, required this.key, required this.room, this.bought = false, this.moved = false});
}

/// 아이템을 방에 놓는 순간 — 빛 기둥 → 링 2겹 → 반짝이 버스트 → 이름 라벨. app2/screens-b2.jsx › PlaceFx
class _PlaceFx extends StatefulWidget {
  const _PlaceFx({super.key, required this.it, required this.at, this.bought = false, this.moved = false});
  final WrItem it; final Offset at; final bool bought, moved;
  @override
  State<_PlaceFx> createState() => _PlaceFxState();
}

class _PlaceFxState extends State<_PlaceFx> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..forward();
  @override
  void dispose() { _c.dispose(); super.dispose(); }

  static const _colorMap = {
    Slot.CANDLE: Color(0xFFFFE08A), Slot.FLOWER: Color(0xFFFFB6D0), Slot.DECORATION: Color(0xFFFFD8A0),
    Slot.BACKGROUND: Color(0xFFC8D8FF), Slot.SPECIAL: Color(0xFFE8C8FF), Slot.SEAL: Color(0xFFFF9A8A), Slot.THEME: Color(0xFFFFE6A8),
  };
  static const _verbMap = {
    Slot.CANDLE: '을(를) 밝혔어요', Slot.FLOWER: '을(를) 꽂았어요', Slot.DECORATION: '을(를) 놓았어요',
    Slot.BACKGROUND: '(으)로 창밖이 바뀌었어요', Slot.SPECIAL: '이(가) 방에 퍼져요', Slot.SEAL: '을(를) 찍었어요', Slot.THEME: '을(를) 놓았어요',
  };

  @override
  Widget build(BuildContext context) {
    final c = _colorMap[widget.it.slot] ?? const Color(0xFFFFE08A);
    final verb = widget.moved ? '의 자리를 옮겼어요' : (_verbMap[widget.it.slot] ?? '');
    final wide = widget.it.slot == Slot.BACKGROUND || widget.it.slot == Slot.SPECIAL;
    return AnimatedBuilder(animation: _c, builder: (_, __) {
      final t = _c.value;
      return Positioned.fill(child: IgnorePointer(child: Stack(children: [
        // 빛 기둥
        if (!wide) Positioned(left: widget.at.dx - 22, top: widget.at.dy - 260 * math.min(1, t * 2),
          child: Opacity(opacity: (1 - t).clamp(0.0, 1.0), child: Container(width: 44, height: 260 * math.min(1, t * 2),
            decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, c.withValues(alpha: .6)]))))),
        // 링 2겹
        for (final d in [0.0, .18]) Positioned(
          left: widget.at.dx - (wide ? 130 : 60), top: widget.at.dy - (wide ? 130 : 60),
          child: Opacity(opacity: (1 - (t - d).clamp(0.0, 1.0)).clamp(0.0, 1.0), child: Container(
            width: (wide ? 260 : 120) * (0.6 + 0.4 * t), height: (wide ? 260 : 120) * (0.6 + 0.4 * t),
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c, width: 2), boxShadow: [BoxShadow(color: c, blurRadius: 20)]),
          ))),
        // 플래시
        Positioned(left: widget.at.dx - 70, top: widget.at.dy - 70, child: Opacity(opacity: (1 - t).clamp(0.0, 1.0), child: Container(
          width: 140, height: 140, decoration: BoxDecoration(shape: BoxShape.circle,
            gradient: RadialGradient(colors: [Colors.white, c.withValues(alpha: .5), Colors.transparent])),
        ))),
        // 반짝이 버스트
        for (int i = 0; i < (widget.bought ? 16 : 10); i++) _sparkle(i, c, t),
        // 이름 라벨
        Positioned(left: (widget.at.dx - 110).clamp(12.0, 390.0 - 232), top: widget.at.dy + (wide ? 60 : 36), width: 220,
          child: Opacity(opacity: t > .25 ? 1 : t / .25, child: Center(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(999),
              gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFF8FB1), Color(0xFFF2628F)]),
              boxShadow: const [BoxShadow(color: Color(0x8CF2628F), blurRadius: 18)]),
            child: Text('${widget.bought ? '✦ NEW · ' : '✦ '}${widget.it.name}$verb',
              style: const TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 12.5, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
          )))),
      ])));
    });
  }

  Widget _sparkle(int i, Color c, double t) {
    final ang = (i / 10) * math.pi * 2;
    final dist = 60 * t;
    final dx = widget.at.dx + math.cos(ang) * dist, dy = widget.at.dy + math.sin(ang) * dist;
    return Positioned(left: dx - 3, top: dy - 3, child: Opacity(opacity: (1 - t).clamp(0.0, 1.0), child: Container(
      width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: c, boxShadow: [BoxShadow(color: c, blurRadius: 6)]),
    )));
  }
}

/// 효과 발동 연출 — 기운이 촛불로 흘러들어가며 'EFFECT ON'을 체감. app2/screens-b2.jsx › EffectOn
class _EffectOn extends StatefulWidget {
  const _EffectOn({super.key, required this.it, required this.room});
  final WrItem it; final WishRoom room;
  @override
  State<_EffectOn> createState() => _EffectOnState();
}

class _EffectOnState extends State<_EffectOn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))..forward();
  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (widget.it.effect == null) return const SizedBox.shrink();
    final cat = WrCatalog.I;
    final c = cat.wishColors.where((x) => x['id'] == widget.it.aura).toList();
    final col = c.isNotEmpty ? _hex(c.first['color'] as String) : const Color(0xFFFFE08A);
    final match = widget.it.aura != 'all' && widget.room.wishColor == widget.it.aura;
    return AnimatedBuilder(animation: _c, builder: (_, __) {
      final t = _c.value;
      final show = t > .4;
      return Positioned.fill(child: IgnorePointer(child: Opacity(opacity: show ? ((t - .4) / .2).clamp(0.0, 1.0) : 0, child: Stack(children: [
        Positioned(left: 0, right: 0, top: 150, child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('EFFECT ON', style: TextStyle(fontFamily: 'IBMPlexMonoWish', fontWeight: FontWeight.w500, fontSize: 11, letterSpacing: 3, color: col)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), color: match ? null : const Color(0x59000000),
              gradient: match ? const LinearGradient(colors: [Color(0xFFFFE08A), Color(0xFFFFB0C8)]) : null,
              border: Border.all(color: col.withValues(alpha: .6))),
            child: Text(_short(widget.it.effect!), style: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w800, fontSize: 12, color: match ? const Color(0xFF3A1A14) : const Color(0xFFFFE6C8))),
          ),
          if (match) Padding(padding: const EdgeInsets.only(top: 6), child: Text('✦ 내 소원과 기운이 맞아요',
            style: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 12, color: const Color(0xFFFFE08A)))),
        ]))),
      ]))));
    });
  }

  String _short(ItemEffect e) {
    switch (e.type) {
      case 'devo': return '정성 +${e.v}%';
      case 'support': return '응원 +${e.v}%';
      case 'cool': return '−${e.v}초';
      case 'daily': return '하루 +${e.v}회';
      case 'pouch': return '복 +${e.v}';
      case 'decay': return '불빛 ${e.v}%↑';
    }
    return '';
  }
}

class _LayoutPatch { final double x, y, s; final bool reset; _LayoutPatch(this.x, this.y, this.s, {this.reset = false}); }

/// 직접 배치 — 끌어서 옮기고, 아래 슬라이더로 크기. app2/screens-b2.jsx › PlaceMode
class _PlaceModeView extends StatefulWidget {
  const _PlaceModeView({required this.it, required this.room, required this.items, required this.onDone});
  final WrItem it; final WishRoom room; final List<WrItem> items;
  final void Function(_LayoutPatch?) onDone;
  @override
  State<_PlaceModeView> createState() => _PlaceModeViewState();
}

class _PlaceModeViewState extends State<_PlaceModeView> {
  late double _x, _y, _s;

  @override
  void initState() {
    super.initState();
    final at = layout.focusOf(widget.it, widget.room.equip, widget.items, widget.room.layout);
    final cu = widget.room.layout[widget.it.id];
    _x = cu?.x ?? at.dx;
    _y = cu?.y ?? (widget.it.kind == 'hang' ? at.dy : at.dy + (widget.it.s ?? 52) / 2);
    _s = cu?.s ?? (widget.it.slot == Slot.FLOWER ? 96 : (widget.it.s ?? 52));
  }

  @override
  Widget build(BuildContext context) {
    final maxS = widget.it.slot == Slot.FLOWER ? 150.0 : 110.0;
    final vRoom = _virtualRoom();
    return Positioned.fill(child: Material(color: const Color(0xFF0A0408), child: Stack(children: [
      Positioned.fill(child: WrCanvasScaler(child: RoomScene(room: vRoom, items: widget.items, hideChar: true, frozen: true))),
      Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _GridPainter()))),
      LayoutBuilder(builder: (context, c) {
        final scale = c.maxWidth / wrCanvasW;
        return Positioned(
          left: (_x - _s * .6) * scale, top: (_y - _s * 1.1) * scale,
          width: _s * 1.2 * scale, height: _s * 1.2 * scale,
          child: GestureDetector(
            onPanUpdate: (d) => setState(() {
              _x = (_x + d.delta.dx / scale).clamp(14.0, 376.0);
              _y = (_y + d.delta.dy / scale).clamp(70.0, 640.0);
            }),
            child: Container(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFE08A), width: 2, style: BorderStyle.solid),
                boxShadow: const [BoxShadow(color: Color(0x40FFE08A), blurRadius: 24, spreadRadius: 4)]),
              child: Stack(clipBehavior: Clip.none, children: [
                Positioned(left: 0, right: 0, top: -26, child: Center(child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFFFE08A), borderRadius: BorderRadius.circular(999)),
                  child: const Text('✥ 끌어서 옮기기', style: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 10.5, color: Color(0xFF3A1A14)), maxLines: 1, overflow: TextOverflow.ellipsis),
                ))),
              ]),
            ),
          ),
        );
      }),
      Positioned(top: 56, left: 0, right: 0, child: Center(child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(color: WrC.glass, borderRadius: BorderRadius.circular(999)),
        child: Text('${widget.it.name} · 자리 정하기', style: const TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 12.5, color: Colors.white)),
      ))),
      Positioned(left: 14, right: 14, bottom: 30, child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: const Color(0xEB1A0812), border: Border.all(color: WrC.line)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            SizedBox(width: 34, child: Text('크기', style: WrF.body(12, color: WrC.muted))),
            Expanded(child: Slider(value: _s.clamp(24.0, maxS), min: 24, max: maxS, activeColor: WrC.blossom,
              onChanged: (v) => setState(() => _s = v))),
            SizedBox(width: 34, child: Text('${_s.round()}', textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'IBMPlexMonoWish', fontWeight: FontWeight.w700, fontSize: 12, color: Colors.white))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(flex: 11, child: OutlinedButton(onPressed: () => widget.onDone(_LayoutPatch(0, 0, 0, reset: true)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: WrC.line), padding: const EdgeInsets.symmetric(vertical: 12)),
              child: const Text('기본 자리', style: TextStyle(color: Colors.white, fontSize: 12.5), maxLines: 1))),
            const SizedBox(width: 8),
            Expanded(flex: 8, child: OutlinedButton(onPressed: () => widget.onDone(null),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: WrC.line), padding: const EdgeInsets.symmetric(vertical: 12)),
              child: const Text('취소', style: TextStyle(color: Colors.white, fontSize: 12.5), maxLines: 1))),
            const SizedBox(width: 8),
            Expanded(flex: 15, child: ElevatedButton(onPressed: () => widget.onDone(_LayoutPatch(_x, _y, _s)),
              style: ElevatedButton.styleFrom(backgroundColor: WrC.blossom, padding: const EdgeInsets.symmetric(vertical: 12)),
              child: const Text('여기에 두기', style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700), maxLines: 1))),
          ]),
        ]),
      )),
    ])));
  }

  WishRoom _virtualRoom() {
    final room = widget.room;
    final layoutJson = Map<String, Map<String, double>>.from(room.layout.map((k, v) => MapEntry(k, {'x': v.x, 'y': v.y, 's': v.s})));
    layoutJson[widget.it.id] = {'x': _x, 'y': _y, 's': _s};
    return WishRoom.fromJson({
      'id': room.id, 'ownerId': room.ownerId, 'owner': room.owner, 'region': room.region, 'text': room.text, 'char': room.char,
      'status': room.status.name, 'visibility': room.visibility.name, 'theme': room.theme.name,
      'outfit': room.outfit?.name, 'outfitNow': room.outfitNow.name, 'wishColor': room.wishColor, 'paper': room.paper,
      'devotionCount': room.devotionCount, 'supportCount': room.supportCount, 'pouchReceived': room.pouchReceived,
      'level': room.level, 'commentCount': room.commentCount, 'points': room.points, 'levelName': room.levelName,
      'curLevelPts': room.curLevelPts, 'nextLevelPts': room.nextLevelPts, 'brightness': room.brightness, 'decayLabel': room.decayLabel,
      'decayBadge': room.decayBadge, 'isMine': room.isMine, 'supportedToday': room.supportedToday,
      'absentDays': room.absentDays, 'devotionsToday': room.devotionsToday, 'devotionsRemaining': room.devotionsRemaining,
      'dailyLimit': room.dailyLimit, 'cooldownSec': room.cooldownSec, 'daysLit': room.daysLit,
      'equip': {
        'CANDLE': room.equip.candle, 'FLOWER': room.equip.flower, 'BACKGROUND': room.equip.background, 'SPECIAL': room.equip.special,
        'DECORATION': room.equip.decoration, 'SEAL': room.equip.seal, 'THEME': room.equip.theme,
      },
      'layout': layoutJson,
    });
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0x0FFFFFFF)..strokeWidth = 1;
    const step = 26.0;
    final scale = size.width / wrCanvasW;
    for (double x = 0; x < size.width; x += step * scale) { canvas.drawLine(Offset(x, 0), Offset(x, size.height), p); }
    for (double y = 0; y < size.height; y += step * scale) { canvas.drawLine(Offset(0, y), Offset(size.width, y), p); }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Color _hex(String s) { final h = s.replaceFirst('#', ''); return Color(int.parse('FF$h', radix: 16)); }

// CSS filter: grayscale(.3) 근사 행렬 — Shortage 시트의 아이템 아이콘에 적용(app2/screens-b2.jsx 1:1)
const List<double> _grayscale30 = [
  .76378, .21456, .02166, 0, 0,
  .06378, .91456, .02166, 0, 0,
  .06378, .21456, .72166, 0, 0,
  0, 0, 0, 1, 0,
];

extension _Let<T> on T { R let<R>(R Function(T) f) => f(this); }
