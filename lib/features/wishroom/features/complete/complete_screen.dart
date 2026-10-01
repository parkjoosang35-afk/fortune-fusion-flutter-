// SCR-10 소원 완료·봉인 `/room/complete` — docs/SCREENS.md §SCR-10, §14.1
// 완료 연출(촛불 최대→황금빛→Lv10 전환→빛기둥→캐릭터 글로우→축하 문구) → 기념 카드
// → [되돌리기(7일 이내)] / [봉인하기] → Sealed 화면.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../application/wishroom_provider.dart';
import '../../data/models.dart';
import '../../core/theme/wr_theme.dart';
import '../../core/motion/wr_motion.dart';
import '../../core/wr_canvas.dart';
import '../room/room_scene.dart';
import '../../wishroom_shell.dart';

class CompleteScreen extends StatefulWidget {
  const CompleteScreen({super.key, required this.roomId});
  final String roomId;
  @override
  State<CompleteScreen> createState() => _CompleteScreenState();
}

class _CompleteScreenState extends State<CompleteScreen> {
  bool _revealing = false;
  bool _sealing = false;
  bool _sealed = false;
  double _gold = 0;
  double _charGlow = 0;
  bool _showCaption = false;
  final List<Timer> _timers = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  @override
  void dispose() {
    for (final t in _timers) { t.cancel(); }
    super.dispose();
  }

  Future<void> _boot() async {
    final p = context.read<WishRoomProvider>();
    final room = p.room;
    if (room != null && room.status != RoomStatus.COMPLETED && room.status != RoomStatus.SEALED) {
      final ok = await p.complete(widget.roomId);
      if (!mounted) return;
      if (!ok) {
        if (p.lastError != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(p.lastError!.message)));
        }
        return;
      }
      _playReveal();
    } else if (room?.status == RoomStatus.SEALED) {
      setState(() => _sealed = true);
    }
  }

  void _playReveal() {
    setState(() { _revealing = true; });
    final steps = CompleteTimeline.steps; // [600,1600,2600,3600,4600,5600]
    _timers.add(Timer(Duration(milliseconds: steps[0]), () { if (mounted) setState(() => _gold = .15); }));
    _timers.add(Timer(Duration(milliseconds: steps[1]), () { if (mounted) setState(() => _gold = .5); }));
    _timers.add(Timer(Duration(milliseconds: steps[2]), () { if (mounted) setState(() => _gold = .7); }));
    _timers.add(Timer(Duration(milliseconds: steps[3]), () { if (mounted) setState(() {}); }));
    _timers.add(Timer(Duration(milliseconds: steps[4]), () { if (mounted) setState(() => _charGlow = 1); }));
    _timers.add(Timer(Duration(milliseconds: steps[5]), () { if (mounted) setState(() { _showCaption = true; _revealing = false; }); }));
  }

  Future<void> _undo(WishRoomProvider p) async {
    final ok = await p.complete(widget.roomId, cancel: true);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).popUntil((r) => r.isFirst || r.settings.name == null);
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const WishRoomShell()), (r) => false);
    } else if (p.lastError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(p.lastError!.message)));
    }
  }

  Future<void> _seal(WishRoomProvider p) async {
    setState(() => _sealing = true);
    await Future.delayed(const Duration(milliseconds: 1400));
    final ok = await p.seal(widget.roomId);
    if (!mounted) return;
    setState(() { _sealing = false; });
    if (ok) {
      setState(() => _sealed = true);
    } else if (p.lastError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(p.lastError!.message)));
    }
  }

  void _shareImage() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('기념 이미지를 공유 준비 중이에요')));
  }

  @override
  Widget build(BuildContext context) {
    // [버그수정] Theme(...) 적용 전 context에는 WrColors extension이 없어
    // context.wr(null-check)가 터진다. midnight 고정이므로 상수를 직접 참조.
    const c = WrColors.midnight;
    return Theme(data: wrTheme(WrPalette.midnight), child: Scaffold(
      backgroundColor: c.bg2,
      body: Consumer<WishRoomProvider>(builder: (context, p, __) {
        final room = p.room;
        if (room == null) return const Center(child: CircularProgressIndicator(color: Color(0xFFF5CF6A)));
        if (_sealed) return _SealedBody(room: room);
        return AnimatedScale(
          scale: _sealing ? .02 : 1,
          duration: const Duration(milliseconds: 1400),
          curve: WrCurves.door,
          child: Stack(children: [
            Positioned.fill(child: WrCanvasScaler(child: RoomScene(
              room: room, items: p.items, gold: _gold, charGlow: _charGlow > 0, boost: _gold > .4 ? 2 : 0,
            ))),
            if (_sealing) Center(child: Container(width: 130, height: 130, alignment: Alignment.center,
              decoration: BoxDecoration(color: const Color(0xFFC94A3B), borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Color(0x99C94A3B), blurRadius: 30)]),
              child: const Text('成', style: TextStyle(fontFamily: 'NotoSerifKRWish', fontWeight: FontWeight.w900, fontSize: 64, color: Color(0xFFFFF9E8))))),
            if (_sealing) const Positioned(bottom: 120, left: 0, right: 0, child: Center(child: Text('봉인하는 중', style: TextStyle(color: Colors.white70, fontSize: 14)))),
            if (!_revealing && !_sealing) SafeArea(child: Column(children: [
              Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: Row(children: [
                IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.close, color: Colors.white)),
              ])),
              if (_showCaption) Padding(padding: const EdgeInsets.only(top: 12), child: Column(children: [
                ShaderMask(shaderCallback: (b) => const LinearGradient(colors: [Color(0xFFFFF6D8), Color(0xFFF5CF6A), Color(0xFFFF8FB1)]).createShader(b),
                  child: const Text('축하합니다', style: TextStyle(fontFamily: 'NotoSerifKRWish', fontWeight: FontWeight.w900, fontSize: 34, color: Colors.white))),
                const SizedBox(height: 8),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 32), child: Text(
                  '${room.daysLit}일 동안 밝혔던 당신의 소원이\n하늘에 닿았어요',
                  textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5))),
              ])),
              const Spacer(),
            ])),
            if (!_revealing && !_sealing && _showCaption) Positioned(left: 16, right: 16, bottom: 24, child: _BottomCard(
              room: room, onUndo: () => _undo(p), onSeal: () => _seal(p), onShare: _shareImage,
            )),
          ]),
        );
      }),
    ));
  }
}

class _BottomCard extends StatelessWidget {
  const _BottomCard({required this.room, required this.onUndo, required this.onSeal, required this.onShare});
  final WishRoom room; final VoidCallback onUndo, onSeal, onShare;
  @override
  Widget build(BuildContext context) {
    final canUndo = room.cancelUntil != null && room.cancelUntil!.isAfter(DateTime.now());
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xF7FFF4E2), Color(0xF2F7E2C8)]), borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('成', style: TextStyle(fontFamily: 'NotoSerifKRWish', fontWeight: FontWeight.w900, fontSize: 42, color: Color(0xFFC94A3B))),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(room.text, style: const TextStyle(fontFamily: 'GowunBatangWish', fontSize: 14, color: Color(0xFF4A2A1C)), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text('❤${room.supportCount} · 福${room.pouchReceived} · ${room.daysLit}일', style: const TextStyle(fontSize: 11, color: Color(0x993C2D1E))),
            ])),
          ]),
        ]),
      ),
      const SizedBox(height: 10),
      Row(children: [
        if (canUndo) Expanded(child: OutlinedButton(
          onPressed: onUndo,
          style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white54), padding: const EdgeInsets.symmetric(vertical: 14)),
          child: const Text('되돌리기', style: TextStyle(color: Colors.white)))),
        if (canUndo) const SizedBox(width: 10),
        Expanded(flex: 2, child: ElevatedButton(
          onPressed: onSeal,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF5CF6A), padding: const EdgeInsets.symmetric(vertical: 14)),
          child: const Text('成 소원방 봉인하기', style: TextStyle(color: Color(0xFF4A2A10), fontWeight: FontWeight.w700)))),
      ]),
      const SizedBox(height: 10),
      TextButton(onPressed: onShare, child: const Text('기념 이미지 공유하기', style: TextStyle(color: Colors.white70, fontSize: 13))),
    ]);
  }
}

class _SealedBody extends StatelessWidget {
  const _SealedBody({required this.room});
  final WishRoom room;
  @override
  Widget build(BuildContext context) {
    final c = context.wr;
    return SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 170, height: 210,
          decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.line)),
          alignment: Alignment.center,
          child: Stack(alignment: Alignment.center, children: [
            const Icon(Icons.local_fire_department, color: Color(0x33FFFFFF), size: 56),
            Positioned(bottom: 14, right: 14, child: Transform.rotate(angle: -6 * 3.14159 / 180, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFC94A3B), borderRadius: BorderRadius.circular(6)),
              child: const Text('成', style: TextStyle(fontFamily: 'NotoSerifKRWish', fontWeight: FontWeight.w900, fontSize: 20, color: Color(0xFFFFF9E8)))))),
          ]),
        ),
        const SizedBox(height: 24),
        Text('소원 기록관에\n영원히 머뭅니다', textAlign: TextAlign.center, style: WrType.h1(c.fg)),
        const SizedBox(height: 32),
        SizedBox(width: double.infinity, height: 54, child: ElevatedButton(
          onPressed: () => Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const WishRoomShell()), (r) => false),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF2628F), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          child: const Text('+ 새로운 소원방 만들기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        )),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, height: 54, child: OutlinedButton(
          onPressed: () => Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const WishRoomShell(initialIndex: 4)), (r) => false),
          style: OutlinedButton.styleFrom(side: BorderSide(color: c.line), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          child: Text('소원 기록관 보기', style: TextStyle(color: c.fg)),
        )),
      ],
    )));
  }
}
