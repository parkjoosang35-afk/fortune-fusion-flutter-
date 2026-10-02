// SCR-10 소원 완료·봉인 `/room/complete` — docs/SCREENS.md §SCR-10, §14.1
// app2/screens-c2.jsx › Complete()/Sealed() 1:1 이식.
// 완료 연출(6단계, CompleteTimeline.steps) → 기념 카드([되돌리기]/[💌 후기]/[봉인하기])
// → 봉인 중(인장 stamp + Burst28) → Sealed 화면([+새 소원방]/[기록관 보기]).
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../application/wishroom_provider.dart';
import '../../data/models.dart';
import '../../core/theme/wr_theme.dart';
import '../../core/motion/wr_motion.dart';
import '../../core/fx/wr_fx.dart';
import '../../core/wr_canvas.dart';
import '../room/room_scene.dart';
import '../review/review_write_screen.dart';
import '../explore/explore_screen.dart';
import '../../wishroom_shell.dart';

class CompleteScreen extends StatefulWidget {
  const CompleteScreen({super.key, required this.roomId, this.already = false});
  final String roomId;
  /// capsule2.jsx `app.go('complete', {already:true})` — 이미 ACHIEVED/COMPLETED 상태에서
  /// 진입(연출 재생 없이 바로 최종 상태로 보여줌). 원본 `Complete({already})` 의 st 초기값 로직.
  final bool already;
  @override
  State<CompleteScreen> createState() => _CompleteScreenState();
}

class _CompleteScreenState extends State<CompleteScreen> {
  // st: 0(시작) ~ 6(완료) — 원본 Complete() 의 React state 'st' 1:1
  int _st = 0;
  int _seal = 0; // 0 없음 · 1 수축 중 · 2 stamp+봉인중 · 3 완료(Sealed 전환)
  bool _reviewed = false; // 원본 reviewed state — 후기 제출 완료 시 되돌리기/💌후기 버튼 숨김
  final List<Timer> _timers = [];

  @override
  void initState() {
    super.initState();
    if (widget.already) {
      _st = 6;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
    }
  }

  @override
  void dispose() {
    for (final t in _timers) { t.cancel(); }
    super.dispose();
  }

  Future<void> _boot() async {
    final p = context.read<WishRoomProvider>();
    final room = p.room;
    if (room == null) return;
    if (room.status == RoomStatus.SEALED) {
      setState(() => _seal = 3);
      return;
    }
    if (room.status == RoomStatus.COMPLETED) {
      // [버그수정 유지] 완료 직후 재진입(새로고침 등) 시 연출을 다시 재생하지 않고
      // 바로 최종 상태(캡션+버튼 노출)로 진입 — already=true 와 동일한 경로.
      setState(() => _st = 6);
      return;
    }
    final ok = await p.complete(widget.roomId);
    if (!mounted) return;
    if (!ok) {
      if (p.lastError != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(p.lastError!.message)));
      return;
    }
    _playReveal();
  }

  /// 원본: [500,1500,2500,3500,4400,5300]ms → setSt(1..6). 이 프로젝트 공용 상수
  /// CompleteTimeline.steps=[600,1600,2600,3600,4600,5600] 를 그대로 재사용(§14.1 표와 근사 일치).
  void _playReveal() {
    final steps = CompleteTimeline.steps;
    for (var i = 0; i < steps.length; i++) {
      _timers.add(Timer(Duration(milliseconds: steps[i]), () { if (mounted) setState(() => _st = i + 1); }));
    }
  }

  Future<void> _cancel(WishRoomProvider p) async {
    final ok = await p.complete(widget.roomId, cancel: true);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const WishRoomShell()), (r) => false);
    } else if (p.lastError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(p.lastError!.message)));
    }
  }

  void _doSeal(WishRoomProvider p) {
    setState(() => _seal = 1);
    _timers.add(Timer(const Duration(milliseconds: 1400), () { if (mounted) setState(() => _seal = 2); }));
    _timers.add(Timer(const Duration(milliseconds: 2700), () async {
      final ok = await p.seal(widget.roomId);
      if (!mounted) return;
      if (ok) {
        setState(() => _seal = 3);
      } else {
        if (p.lastError != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(p.lastError!.message)));
        setState(() => _seal = 0);
      }
    }));
  }

  Future<void> _openReview(WishRoom room) async {
    final go = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => ReviewWriteScreen(room: room), fullscreenDialog: true));
    if (!mounted) return;
    if (go == null) return; // 스킵("나중에 남길게요") — reviewed 상태 변경 없음
    setState(() => _reviewed = true);
    if (go == 'stories') {
      // "이야기 보기" → capsule2.jsx `app.go('explore', {tab:'stories'})` 1:1 — 탐색 stories 탭으로 이동.
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ExploreScreen(initialTab: 'stories')));
    }
  }

  void _shareImage() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('기념 이미지를 저장했어요')));
  }

  @override
  Widget build(BuildContext context) {
    if (_seal == 3) {
      return Theme(data: wrThemeData(), child: Scaffold(backgroundColor: Colors.black,
        body: Consumer<WishRoomProvider>(builder: (context, p, __) {
          final room = p.room;
          if (room == null) return const Center(child: CircularProgressIndicator(color: WrC.glow));
          return _SealedBody(room: room);
        })));
    }
    return Theme(data: wrThemeData(), child: Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<WishRoomProvider>(builder: (context, p, __) {
        final room = p.room;
        if (room == null) return const Center(child: CircularProgressIndicator(color: WrC.glow));
        final st = _st;
        return Stack(children: [
          Positioned.fill(child: AnimatedScale(
            scale: _seal > 0 ? .02 : 1,
            duration: const Duration(milliseconds: 1400),
            curve: WrCurves.door,
            child: WrCanvasScaler(child: SizedBox(width: 390, height: 844, child: Stack(clipBehavior: Clip.none, children: [
              RoomScene(
                room: room, items: p.items,
                boost: st >= 1 ? 2 : 0, gold: st >= 2 ? .5 : 0, charGlow: st >= 5,
                levelOverride: st >= 3 ? 10 : null,
              ),
              if (st >= 1) const WrBurst(x: 204, y: 330, n: 24, spread: 180, color: Color(0xFFFFF2B8), dur: 1600),
              if (st >= 4) for (var i = 0; i < 7; i++) _LightPillar(index: i),
              if (st >= 3) const Positioned.fill(child: IgnorePointer(child: WrPetalRain(n: 40, dur: (4, 7), spread: 3))),
              if (st >= 3) for (var i = 0; i < _lotusSpots.length; i++) _LotusPop(index: i, pos: _lotusSpots[i]),
              if (st >= 5) const WrButterflies(x: 204, y: 420),
            ]))),
          )),
          if (_seal > 0 && _seal < 3) _SealingOverlay(sealing: _seal),
          if (st >= 6 && _seal == 0) SafeArea(child: Column(children: [
            Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: Row(children: [
              IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.close, color: Colors.white)),
            ])),
            Padding(padding: const EdgeInsets.only(top: 12), child: Column(children: [
              ShaderMask(shaderCallback: (b) => const LinearGradient(colors: [Color(0xFFFFF6D8), Color(0xFFF5CF6A), Color(0xFFFF8FB1)]).createShader(b),
                child: const Text('축하합니다', style: TextStyle(fontFamily: 'NotoSerifKRWish', fontWeight: FontWeight.w900, fontSize: 34, color: Colors.white))),
              const SizedBox(height: 8),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 32), child: Text(
                '${room.daysLit}일 동안 밝혔던 당신의 소원이\n하늘에 닿았어요',
                textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5))),
            ])),
            const Spacer(),
          ])),
          if (st >= 6 && _seal == 0) Positioned(left: 14, right: 14, bottom: 34, child: _BottomCard(
            room: room, reviewed: _reviewed,
            onUndo: () => _cancel(p),
            onReview: () => _openReview(room),
            onSeal: () => _doSeal(p),
            onShare: _shareImage,
          )),
        ]);
      }),
    ));
  }
}

const _lotusSpots = [Offset(40, 560), Offset(300, 600), Offset(170, 650), Offset(90, 470), Offset(280, 470)];

class _LightPillar extends StatefulWidget {
  const _LightPillar({required this.index});
  final int index;
  @override
  State<_LightPillar> createState() => _LightPillarState();
}

class _LightPillarState extends State<_LightPillar> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: Duration(milliseconds: ((2.2 + (widget.index % 3) * .5) * 1000).round()))..repeat();
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final i = widget.index;
    final w = 6.0 + (i % 3) * 4;
    return Positioned(left: 50 + i * 48, bottom: 100, child: AnimatedBuilder(animation: _c, builder: (_, __) {
      final dl = (i * .15 / (2.2 + (i % 3) * .5)).clamp(0.0, 1.0);
      final raw = ((_c.value - dl) % 1 + 1) % 1;
      final op = (1 - raw).clamp(0.0, 1.0) * .9;
      return IgnorePointer(child: Opacity(opacity: op, child: Container(width: w, height: 340, decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.transparent, Color(0xE6FFE6A0), Colors.transparent])))));
    }));
  }
}

class _LotusPop extends StatefulWidget {
  const _LotusPop({required this.index, required this.pos});
  final int index; final Offset pos;
  @override
  State<_LotusPop> createState() => _LotusPopState();
}

class _LotusPopState extends State<_LotusPop> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
  @override
  void initState() { super.initState(); Future.delayed(Duration(milliseconds: (widget.index * 140).round()), () { if (mounted) _c.forward(); }); }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Positioned(left: widget.pos.dx, top: widget.pos.dy, child: IgnorePointer(child: ScaleTransition(
      scale: CurvedAnimation(parent: _c, curve: WrCurves.overshoot),
      child: FadeTransition(opacity: _c, child: Image.asset('assets/wishroom/items/lotus.png', width: 70,
        errorBuilder: (_, __, ___) => const Text('🪷', style: TextStyle(fontSize: 44)))),
    )));
  }
}

class _SealingOverlay extends StatelessWidget {
  const _SealingOverlay({required this.sealing});
  final int sealing; // 1 수축 중 · 2 stamp
  @override
  Widget build(BuildContext context) {
    return Positioned.fill(child: Container(color: Colors.black38, child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 130, height: 130, alignment: Alignment.center,
        decoration: BoxDecoration(color: const Color(0xFFC94A3B), borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0xB3C94A3B), blurRadius: 40)]),
        child: const Text('成', style: TextStyle(fontFamily: 'NotoSerifKRWish', fontWeight: FontWeight.w900, fontSize: 70, color: Color(0xFFFFF9E8)))),
      if (sealing == 2) ...[
        const SizedBox(height: 36),
        const SizedBox(width: 1, height: 1, child: Stack(clipBehavior: Clip.none, children: [WrBurst(x: 0, y: 0, n: 28, spread: 200)])),
        const SizedBox(height: 36),
        const Text('봉인하는 중', style: TextStyle(fontFamily: 'NotoSerifKRWish', fontWeight: FontWeight.w900, fontSize: 20, color: Colors.white)),
      ],
    ]))));
  }
}

class _BottomCard extends StatelessWidget {
  const _BottomCard({required this.room, required this.reviewed, required this.onUndo, required this.onReview, required this.onSeal, required this.onShare});
  final WishRoom room; final bool reviewed; final VoidCallback onUndo, onReview, onSeal, onShare;
  @override
  Widget build(BuildContext context) {
    // 원본: !reviewed && !room.sealUntil 일 때만 되돌리기, !reviewed 일 때 💌 후기 노출.
    final canUndo = !reviewed && room.cancelUntil != null && room.cancelUntil!.isAfter(DateTime.now());
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: WrDeco.hanji,
        child: Row(children: [
          const Text('成', style: TextStyle(fontFamily: 'NotoSerifKRWish', fontWeight: FontWeight.w900, fontSize: 42, color: Color(0xFFC94A3B))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(room.text, style: const TextStyle(fontFamily: 'GowunBatangWish', fontSize: 14, color: Color(0xFF4A2A1C)), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text('❤ ${room.supportCount} · 福 ${room.pouchReceived} · ${room.daysLit}일', style: const TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 11.5, color: Color(0xFF8A4A3A))),
          ])),
        ]),
      ),
      const SizedBox(height: 10),
      // 원본 flex 비율: 되돌리기 1 · 💌 후기 1.4 · 봉인하기 2 (되돌리기·💌후기는 !reviewed 일 때만 노출)
      Row(children: [
        if (canUndo) ...[
          Expanded(flex: 10, child: _actionBtn('되돌리기', WrDeco.btnDark, Colors.white, onUndo)),
          const SizedBox(width: 8),
        ],
        if (!reviewed) ...[
          Expanded(flex: 14, child: _actionBtn('💌 후기', WrDeco.btnGold, const Color(0xFF4A2A10), onReview)),
          const SizedBox(width: 8),
        ],
        Expanded(flex: 20, child: _actionBtn('成 소원방 봉인하기', WrDeco.btnPink, Colors.white, onSeal)),
      ]),
      const SizedBox(height: 10),
      TextButton(onPressed: onShare, child: Text('기념 이미지 공유하기', style: WrF.body(12.5, color: WrC.muted))),
    ]);
  }

  Widget _actionBtn(String label, BoxDecoration deco, Color color, VoidCallback onTap) => SizedBox(
    height: WrSize.btnSmH,
    child: DecoratedBox(decoration: deco, child: Material(color: Colors.transparent, child: InkWell(borderRadius: BorderRadius.circular(16), onTap: onTap,
      child: Center(child: Text(label, style: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: WrSize.btnSmFont, color: color), maxLines: 1, overflow: TextOverflow.ellipsis))))),
  );
}

class _SealedBody extends StatelessWidget {
  const _SealedBody({required this.room});
  final WishRoom room;
  @override
  Widget build(BuildContext context) {
    // 원본 `.blur-room { backgroundImage: room-lv10.jpg }` — 배경은 정적 Lv10 일러스트를 흐리게.
    // (RoomThumb 라이브 렌더는 카드 쪽에서만, 배경까지 RoomScene 2중 렌더하면 애니메이션 비용이 커진다.)
    return Stack(children: [
      Positioned.fill(child: ImageFiltered(imageFilter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Image.asset('assets/wishroom/room-lv10.jpg', fit: BoxFit.cover))),
      Positioned.fill(child: Container(color: Colors.black.withValues(alpha: .55))),
      const Positioned.fill(child: IgnorePointer(child: WrPetalRain(n: 14, dur: (7, 10), spread: 6))),
      SafeArea(child: Padding(padding: const EdgeInsets.all(26), child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: 170, height: 210, child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
            Container(
              width: 170, height: 210,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: WrC.glow, width: 2),
                boxShadow: const [BoxShadow(color: Color(0x80F5CF6A), blurRadius: 40)]),
              clipBehavior: Clip.antiAlias,
              child: WrCanvasScaler(child: SizedBox(width: 390, height: 844, child: RoomScene(room: room, items: const [], frozen: true, lowFx: true, hideChar: false, levelOverride: 10))),
            ),
            Positioned(right: -10, bottom: -10, child: Container(
              width: 46, height: 46, alignment: Alignment.center,
              decoration: const BoxDecoration(color: WrC.accent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x80C94A3B), blurRadius: 8)]),
              child: const Text('成', style: TextStyle(fontFamily: 'NotoSerifKRWish', fontWeight: FontWeight.w900, fontSize: 24, color: Color(0xFFFFF9E8))))),
          ])),
          const SizedBox(height: 34),
          Text('소원 기록관에\n영원히 머뭅니다', textAlign: TextAlign.center, style: WrF.display(26, color: Colors.white, height: 1.35)),
          const SizedBox(height: 10),
          Text('완성된 소원은 보관하고,\n이제 새로운 소원을 시작할 수 있어요', textAlign: TextAlign.center, style: WrF.body(13.5, color: WrC.muted, height: 1.7)),
          const SizedBox(height: 28),
          _sealedBtn('+ 새로운 소원방 만들기', WrDeco.btnPink, Colors.white,
            () => Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const WishRoomShell()), (r) => false)),
          const SizedBox(height: 10),
          _sealedBtn('소원 기록관 보기', WrDeco.btnDark, Colors.white,
            () => Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const WishRoomShell(initialIndex: 4)), (r) => false)),
        ],
      ))),
    ]);
  }

  Widget _sealedBtn(String label, BoxDecoration deco, Color color, VoidCallback onTap) => SizedBox(
    width: double.infinity, height: WrSize.btnH,
    child: DecoratedBox(decoration: deco, child: Material(color: Colors.transparent,
      child: InkWell(borderRadius: BorderRadius.circular(16), onTap: onTap,
        child: Center(child: Text(label, style: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: WrSize.btnFont, color: color))))),
    ));
}
