// SCR-04 꾸미기 `/decor` (탭4) — docs/SCREENS.md §SCR-04
// 상단 방 미리보기(캐릭터 숨김) + 바텀 패널(슬롯 칩 + 3열 그리드).
// 미보유 아이템 탭 → 미리보기(로컬 상태만) → 구매(purchase) → 장착(decorations PATCH).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../application/wishroom_provider.dart';
import '../../data/models.dart';
import '../../core/theme/wr_theme.dart';
import '../../core/wr_canvas.dart';
import '../room/room_scene.dart';

class DecorScreen extends StatefulWidget {
  const DecorScreen({super.key});
  @override
  State<DecorScreen> createState() => _DecorScreenState();
}

class _DecorScreenState extends State<DecorScreen> {
  Slot _slot = Slot.CANDLE;
  WrItem? _preview;

  @override
  void initState() {
    super.initState();
    final p = context.read<WishRoomProvider>();
    if (!p.catalogLoaded) p.loadCatalog();
  }

  Future<void> _onTapItem(WrItem it, WishRoom room) async {
    // 미보유든 보유든 동일하게 미리보기 상태로 전환 — 실제 장착(구매 포함)은
    // _confirmEquip()에서 [방에 들이기] 버튼을 눌렀을 때만 일어난다.
    setState(() => _preview = it);
  }

  Future<void> _confirmEquip(WrItem it, WishRoom room) async {
    final p = context.read<WishRoomProvider>();
    if (!it.owned && it.price != null && it.price! > 0) {
      final ok = await p.buyItem(it.id);
      if (!ok) {
        if (!mounted) return;
        final err = p.lastError;
        if (err?.code == 'INSUFFICIENT') {
          _showShortage(err!);
        } else if (err != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.message)));
        }
        return;
      }
    }
    final ok2 = await p.equip(room.id, it.id);
    if (!ok2 && mounted) {
      final err = p.lastError;
      if (err != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.message)));
    }
    if (mounted) setState(() => _preview = null);
  }

  void _showShortage(ApiError e) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, builder: (_) => Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xF73E182C), Color(0xFA1E0A16)]),
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('복주머니가 부족해요', style: TextStyle(color: Colors.white, fontSize: 16)),
        const SizedBox(height: 6),
        Text('필요 ${e.need ?? '-'} · 보유 ${e.have ?? '-'}', style: const TextStyle(color: Colors.white54, fontSize: 13)),
        const SizedBox(height: 18),
        SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF5CF6A)),
          child: const Text('복주머니 모으러 가기', style: TextStyle(color: Color(0xFF4A2A10))),
        )),
      ]),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.wr;
    return Theme(data: wrTheme(WrPalette.midnight), child: Scaffold(
      backgroundColor: c.bg2,
      body: Consumer<WishRoomProvider>(builder: (context, p, __) {
        final room = p.room;
        if (room == null) return const Center(child: CircularProgressIndicator(color: Color(0xFFF5CF6A)));
        final slotItems = p.items.where((i) => i.slot == _slot).toList();
        return Column(children: [
          SizedBox(height: 320, child: Stack(children: [
            Positioned.fill(child: WrCanvasScaler(child: Transform.translate(offset: const Offset(0, -150), child: RoomScene(
              room: room, items: p.items, hideChar: true,
            )))),
            if (_preview != null) Positioned(top: 12, left: 0, right: 0, child: Center(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xCC1A0D2E), borderRadius: BorderRadius.circular(999)),
              child: Text('미리보기 · ${_preview!.name}', style: const TextStyle(color: Colors.white, fontSize: 12)),
            ))),
          ])),
          Expanded(child: Container(
            decoration: BoxDecoration(color: c.bg2, borderRadius: const BorderRadius.vertical(top: Radius.circular(26))),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(height: 40, child: ListView(scrollDirection: Axis.horizontal, children: Slot.values.map((s) {
                final sel = _slot == s;
                final label = _slotLabel(s, room);
                return Padding(padding: const EdgeInsets.only(right: 8), child: GestureDetector(
                  onTap: () => setState(() { _slot = s; _preview = null; }),
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: sel ? c.accent : c.card, borderRadius: BorderRadius.circular(999)),
                    child: Text(label, style: TextStyle(color: sel ? Colors.white : c.fg, fontSize: 12))),
                ));
              }).toList())),
              const SizedBox(height: 12),
              Expanded(child: GridView.builder(
                itemCount: slotItems.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: .82),
                itemBuilder: (_, i) {
                  final it = slotItems[i];
                  final equipped = room.equip.all.contains(it.id);
                  return GestureDetector(onTap: () => _onTapItem(it, room), child: Container(
                    decoration: BoxDecoration(
                      color: c.card, borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: equipped ? c.accent : c.line, width: equipped ? 2 : 1),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Column(children: [
                      Expanded(child: Stack(children: [
                        Center(child: it.asset != null ? Image.asset(it.asset!, fit: BoxFit.contain) : Text(it.glyph ?? '✦', style: const TextStyle(fontSize: 32))),
                        if (equipped) Positioned(right: 0, top: 0, child: Container(width: 18, height: 18,
                          decoration: const BoxDecoration(color: Color(0xFFFF8FB1), shape: BoxShape.circle),
                          child: const Icon(Icons.check, size: 12, color: Colors.white))),
                      ])),
                      const SizedBox(height: 4),
                      Text(it.name, style: TextStyle(color: c.fg, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(equipped ? '놓여 있음' : (it.owned ? '보유' : '💰${it.price ?? 0}'),
                        style: TextStyle(color: c.glow, fontSize: 10)),
                    ]),
                  ));
                },
              )),
              if (_preview != null) Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => setState(() => _preview = null),
                  style: OutlinedButton.styleFrom(side: BorderSide(color: c.line)), child: Text('되돌리기', style: TextStyle(color: c.fg)))),
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton(onPressed: () => _confirmEquip(_preview!, room),
                  style: ElevatedButton.styleFrom(backgroundColor: c.accent),
                  child: Text(_preview!.owned ? '방에 들이기' : '💰${_preview!.price ?? 0} · 방에 들이기', style: const TextStyle(color: Colors.white)))),
              ])),
            ]),
          )),
        ]);
      }),
    ));
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
}
