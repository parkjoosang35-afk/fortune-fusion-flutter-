// app2/capsule2.jsx › UnsealBanner / CapsuleOpen 1:1 이식 — 소원 봉인(타임캡슐) 날짜 도착 후
// "소원 열어보기" → 인장 깨짐 → 두루마리 펼침 → "이 소원은 어떻게 되었나요?" 세 가지 선택.
// docs/CHANGELOG.md "소원 봉인(타임캡슐)" 5·6단계. main_room_screen.dart에서 room.capsuleDue일 때 띄운다.
// FULFILLED 선택 시 app2/review2.jsx AchieveFlow(AchieveCinematic → ReviewWrite → ReviewReward)로 이어진다.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../application/wishroom_provider.dart';
import '../../data/models.dart';
import '../../data/wr_catalog.dart';
import '../../core/theme/wr_theme.dart';
import '../../core/fx/wr_fx.dart';
import '../../core/motion/wr_motion.dart';
import '../review/review_write_screen.dart';
import '../compose/compose_screen.dart' show WrSealDatePicker, WrSealConfirm;

Color _hex(String h) => Color(int.parse('FF${h.replaceFirst('#', '')}', radix: 16));
String _fmtDot(String? d) => d == null ? '' : d.replaceAll('-', '.');
String _fmtK(String? d) {
  if (d == null) return '';
  final p = d.split('-').map(int.parse).toList();
  return '${p[0]}년 ${p[1]}월 ${p[2]}일';
}

/// app2/capsule2.jsx › UnsealBanner — 메인 화면 위에 뜨는 "봉인이 풀렸습니다" 안내 오버레이.
class WrUnsealBanner extends StatelessWidget {
  const WrUnsealBanner({super.key, required this.room, required this.onOpen});
  final WishRoom room;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned.fill(child: Container(color: const Color(0x9E080308))),
      Positioned(left: 22, right: 22, top: 200, child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1), duration: const Duration(milliseconds: 700), curve: WrCurves.overshoot,
        builder: (_, t, child) => Opacity(opacity: t.clamp(0.0, 1.0), child: Transform.scale(scale: .7 + .3 * t, child: child)),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0x66FFDC96)),
            gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xF5461E38), Color(0xF81A0812)]),
            boxShadow: const [BoxShadow(color: Color(0x40FFC878), blurRadius: 60), BoxShadow(color: Color(0x99000000), blurRadius: 50, offset: Offset(0, 24))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const _BobIcon(icon: '🎁', fontSize: 62),
            const SizedBox(height: 10),
            Text('소원 봉인이 풀렸습니다.', style: WrF.display(21), textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text('예전에 내가 빌었던 소원을\n다시 확인해보세요.', textAlign: TextAlign.center, style: WrF.body(13.5, color: WrC.muted, height: 1.7)),
            const SizedBox(height: 12),
            Text('SEALED ${_fmtDot(room.sealedOn)} → ${_fmtDot(room.sealUntil)}', style: WrF.mono(size: 10, color: const Color(0xFFFFE08A))),
            const SizedBox(height: 18),
            SizedBox(width: double.infinity, height: 54, child: DecoratedBox(decoration: WrDeco.btnGold,
              child: Material(color: Colors.transparent, child: InkWell(borderRadius: BorderRadius.circular(16), onTap: onOpen,
                child: const Center(child: Text('🔓 소원 열어보기', style: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF4A2A10)))))))),
          ]),
        ),
      )),
    ]);
  }
}

class _BobIcon extends StatefulWidget {
  const _BobIcon({required this.icon, required this.fontSize});
  final String icon; final double fontSize;
  @override
  State<_BobIcon> createState() => _BobIconState();
}
class _BobIconState extends State<_BobIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))..repeat(reverse: true);
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: _c, builder: (_, __) =>
    Transform.translate(offset: Offset(0, -6 * Curves.easeInOut.transform(_c.value)), child: Text(widget.icon, style: TextStyle(fontSize: widget.fontSize))));
}

/// app2/capsule2.jsx › CapsuleOpen — 전체 흐름 컨트롤러.
/// pop 결과 없음(void) — onClose 콜백으로 종료, 호출부가 provider.room을 reload.
class CapsuleOpenScreen extends StatefulWidget {
  const CapsuleOpenScreen({super.key, required this.room});
  final WishRoom room;
  @override
  State<CapsuleOpenScreen> createState() => _CapsuleOpenScreenState();
}

enum _CapStep { open, ask, rewish, sealed, ongoing }

class _CapsuleOpenScreenState extends State<CapsuleOpenScreen> {
  _CapStep _step = _CapStep.open;
  late String _text = widget.room.text;
  DateTime? _date;
  bool _confirm = false;
  bool _busy = false;
  bool _sealBreakDone = false;

  @override
  void initState() {
    super.initState();
    // 원본: unseal() POST 호출 + 3초 뒤 open→ask 자동 전환.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final p = context.read<WishRoomProvider>();
      await p.unseal(widget.room.id);
    });
    Timer(const Duration(milliseconds: 1300), () { if (mounted) setState(() => _sealBreakDone = true); });
    Timer(const Duration(milliseconds: 3000), () { if (mounted && _step == _CapStep.open) setState(() => _step = _CapStep.ask); });
  }

  Future<void> _choose(Outcome o) async {
    if (o == Outcome.REWISH) { setState(() => _step = _CapStep.rewish); return; }
    if (_busy) return;
    setState(() => _busy = true);
    final p = context.read<WishRoomProvider>();
    final ok = await p.outcome(widget.room.id, o);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      if (p.lastError != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(p.lastError!.message)));
      return;
    }
    if (o == Outcome.FULFILLED) {
      final room = p.room ?? widget.room;
      if (!mounted) return;
      Navigator.of(context).pop(); // CapsuleOpen 닫기
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => AchieveFlowScreen(room: room)));
    } else {
      setState(() => _step = _CapStep.ongoing);
    }
  }

  Future<void> _rewish() async {
    if (_date == null || _text.trim().isEmpty) return;
    setState(() => _busy = true);
    final p = context.read<WishRoomProvider>();
    final iso = '${_date!.year.toString().padLeft(4, '0')}-${_date!.month.toString().padLeft(2, '0')}-${_date!.day.toString().padLeft(2, '0')}';
    final ok = await p.outcome(widget.room.id, Outcome.REWISH, text: _text.trim(), sealUntil: iso);
    if (!mounted) return;
    if (ok) {
      setState(() { _confirm = false; _step = _CapStep.sealed; });
    } else {
      setState(() => _busy = false);
      if (p.lastError != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(p.lastError!.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final cat = WrCatalog.I;
    final w = cat.wishColors.firstWhere((e) => e['id'] == room.wishColor, orElse: () => cat.wishColors.first);
    final pp = cat.papers.firstWhere((e) => e['id'] == room.paper, orElse: () => cat.papers.first);
    final color = _hex(w['color'] as String), deep = _hex(w['deep'] as String), hanja = w['hanja'] as String;
    final kept = (room.sealTotalDays ?? 1).clamp(1, 100000);

    if (_step == _CapStep.sealed) {
      return _SealedDoneBody(date: _date!, text: _text, wishColor: room.wishColor, onGo: () => Navigator.of(context).pop());
    }
    if (_step == _CapStep.ongoing) {
      return Theme(data: wrThemeData(), child: Scaffold(backgroundColor: const Color(0xFF0C0408), body: Stack(children: [
        Container(decoration: const BoxDecoration(gradient: RadialGradient(center: Alignment(0, -.45), radius: 1.1, colors: [Color(0xFF3A1A34), Color(0xFF0C0408)], stops: [0, .78]))),
        const Positioned.fill(child: IgnorePointer(child: WrPetalRain(n: 6, dur: (9, 13), spread: 8))),
        Positioned(left: 26, right: 26, top: 240, child: Column(children: [
          const _BobIcon(icon: '🙏', fontSize: 44),
          const SizedBox(height: 14),
          Text('아직 소원이 진행 중이군요.', style: WrF.display(21), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text('소원이 이루어지는 그날까지\n소중하게 간직해 주세요.', textAlign: TextAlign.center, style: WrF.body(14, color: WrC.muted, height: 1.8)),
        ])),
        Positioned(left: 20, right: 20, bottom: 44, child: SizedBox(width: double.infinity, height: WrSize.btnH, child: DecoratedBox(decoration: WrDeco.btnPink,
          child: Material(color: Colors.transparent, child: InkWell(borderRadius: BorderRadius.circular(16), onTap: () => Navigator.of(context).pop(),
            child: const Center(child: Text('🕯 소원방으로 돌아가기', style: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white)))))))),
      ])));
    }

    return Theme(data: wrThemeData(), child: Scaffold(backgroundColor: const Color(0xFF0C0408), body: Stack(children: [
      Container(decoration: const BoxDecoration(gradient: RadialGradient(center: Alignment(0, -.5), radius: 1.1, colors: [Color(0xFF4A2040), Color(0xFF0C0408)], stops: [0, .78]))),
      const Positioned.fill(child: IgnorePointer(child: WrPetalRain(n: 7, dur: (8, 12), spread: 8))),
      const Positioned.fill(child: IgnorePointer(child: WrPetalRain(n: 10, dur: (9, 13), spread: 8))),
      // 깨지는 인장
      if (_step == _CapStep.open) Positioned(left: 0, right: 0, top: 220, child: Center(child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1), duration: const Duration(milliseconds: 1200), curve: const Cubic(.6, 0, .4, 1),
        builder: (_, t, __) {
          final scale = t < .45 ? 1.0 + t / .45 * .15 : t < .6 ? 1.15 - (t - .45) / .15 * .1 : 1.05 + (t - .6) / .4 * .55;
          final op = t < .6 ? 1.0 : (1 - (t - .6) / .4).clamp(0.0, 1.0);
          return Opacity(opacity: op, child: Transform.scale(scale: scale, child: Container(
            width: 64, height: 64, alignment: Alignment.center,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color, deep]),
              boxShadow: [BoxShadow(color: color, blurRadius: 30)]),
            child: Text(hanja, style: const TextStyle(fontFamily: 'NotoSerifKRWish', fontWeight: FontWeight.w900, fontSize: 32, color: Color(0xFFFFF4E0))),
          )));
        },
      ))),
      if (_sealBreakDone) const Positioned(left: 195, top: 220, child: WrBurst(x: 0, y: 0, n: 26, spread: 170, color: Color(0xFFFFE0A0))),
      Positioned(left: 0, right: 0, top: 86, child: Column(children: [
        Text('UNSEALED · ${_fmtDot(room.sealUntil)}', style: WrF.mono(size: 10, color: const Color(0xFFFFE08A))),
        const SizedBox(height: 6),
        Text('${_fmtK(room.sealedOn)}에 봉인한 소원 · $kept일 동안 간직했어요', style: WrF.body(12.5, color: WrC.muted)),
      ])),
      // 펼쳐지는 두루마리
      Positioned(left: 26, right: 26, top: 150, child: Column(children: [
        Container(height: 14, decoration: BoxDecoration(borderRadius: BorderRadius.circular(7),
          gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF8A5A34), Color(0xFF5A3418)]))),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_hex((pp['bg'] as List)[0] as String), _hex((pp['bg'] as List)[1] as String)]),
            boxShadow: [BoxShadow(color: color.withValues(alpha: .27), blurRadius: 30), const BoxShadow(color: Color(0x80000000), blurRadius: 30, offset: Offset(0, 14))],
          ),
          child: _step == _CapStep.rewish
            ? TextField(controller: TextEditingController(text: _text)..selection = TextSelection.collapsed(offset: _text.length),
                maxLength: 100, maxLines: 4, onChanged: (v) => _text = v,
                style: const TextStyle(fontFamily: 'GowunBatangWish', fontWeight: FontWeight.w700, fontSize: 16, height: 1.65, color: Color(0xFF4A2A1C)),
                decoration: const InputDecoration(border: InputBorder.none, counterText: ''))
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(room.text, style: const TextStyle(fontFamily: 'GowunBatangWish', fontWeight: FontWeight.w700, fontSize: 17, height: 1.75, color: Color(0xFF4A2A1C))),
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: Container(width: 30, height: 30, alignment: Alignment.center,
                  decoration: BoxDecoration(color: deep.withValues(alpha: .85), borderRadius: BorderRadius.circular(6)),
                  child: Text(hanja, style: const TextStyle(fontFamily: 'NotoSerifKRWish', fontWeight: FontWeight.w900, fontSize: 15, color: Colors.white)))),
              ]),
        ),
        Container(height: 14, decoration: BoxDecoration(borderRadius: BorderRadius.circular(7),
          gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF5A3418), Color(0xFF8A5A34)]))),
      ])),
      // 선택
      if (_step == _CapStep.ask) Positioned(left: 20, right: 20, bottom: 40, child: Column(children: [
        Text('이 소원은 어떻게 되었나요?', style: WrF.display(19), textAlign: TextAlign.center),
        const SizedBox(height: 14),
        _choiceBtn('😊', '소원이 이루어졌어요', WrDeco.btnGold, const Color(0xFF4A2A10), () => _choose(Outcome.FULFILLED)),
        const SizedBox(height: 8),
        _choiceBtn('🙏', '아직 진행 중이에요', WrDeco.btnDark, Colors.white, () => _choose(Outcome.ONGOING)),
        const SizedBox(height: 8),
        _choiceBtn('🔄', '다시 소원을 빌어요', WrDeco.btnDark, Colors.white, () => _choose(Outcome.REWISH)),
      ])),
      if (_step == _CapStep.rewish) Positioned(left: 0, right: 0, bottom: 0, child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 34),
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xF50C0408)], stops: [0, .18])),
        child: SingleChildScrollView(child: Column(children: [
          Text('위 두루마리의 소원을 고쳐 써도 좋아요', style: WrF.body(12, color: WrC.muted), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          WrSealDatePicker(value: _date, onChange: (d) => setState(() => _date = d)),
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, height: WrSize.btnH, child: DecoratedBox(decoration: (_date == null || _text.trim().isEmpty) ? WrDeco.btnDark : WrDeco.btnPink,
            child: Material(color: Colors.transparent, child: InkWell(borderRadius: BorderRadius.circular(16),
              onTap: (_date == null || _text.trim().isEmpty) ? null : () => setState(() => _confirm = true),
              child: const Center(child: Text('🔐 소원 봉인하기', style: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white))))))),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, height: WrSize.btnH, child: DecoratedBox(decoration: WrDeco.btnDark,
            child: Material(color: Colors.transparent, child: InkWell(borderRadius: BorderRadius.circular(16), onTap: () => setState(() => _step = _CapStep.ask),
              child: const Center(child: Text('돌아가기', style: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white))))))),
        ])),
      )),
      if (_confirm) WrSealConfirm(date: _date!, busy: _busy, onCancel: () => setState(() => _confirm = false), onOk: _rewish),
    ])));
  }

  Widget _choiceBtn(String emoji, String label, BoxDecoration deco, Color color, VoidCallback onTap) => SizedBox(
    width: double.infinity, height: 52,
    child: DecoratedBox(decoration: deco, child: Material(color: Colors.transparent,
      child: InkWell(borderRadius: BorderRadius.circular(16), onTap: _busy ? null : onTap,
        child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 18)), const SizedBox(width: 8),
          Text(label, style: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 15, color: color)),
        ]))))));
}

/// app2/capsule2.jsx › SealedDone (REWISH 경로) — 전체화면 Scaffold로 감싼 축약 버전.
/// compose_screen의 SealedDoneScreen과 연출은 동일하되, 여기선 CapsuleOpen 흐름 안에서 간단히 재사용한다.
class _SealedDoneBody extends StatelessWidget {
  const _SealedDoneBody({required this.date, required this.text, required this.wishColor, required this.onGo});
  final DateTime date; final String text; final String wishColor; final VoidCallback onGo;
  @override
  Widget build(BuildContext context) {
    final cat = WrCatalog.I;
    final w = cat.wishColors.firstWhere((e) => e['id'] == wishColor, orElse: () => cat.wishColors.first);
    final hanja = w['hanja'] as String;
    final color = _hex(w['color'] as String);
    final dateK = '${date.year}년 ${date.month}월 ${date.day}일';
    return Theme(data: wrThemeData(), child: Scaffold(backgroundColor: const Color(0xFF0C0408), body: Container(
      decoration: const BoxDecoration(gradient: RadialGradient(center: Alignment(0, -.42), radius: 1.1, colors: [Color(0xFF3A1A34), Color(0xFF0C0408)], stops: [0, .75])),
      child: Stack(children: [
        const Positioned.fill(child: IgnorePointer(child: WrPetalRain(n: 8, dur: (8, 12), spread: 8))),
        Positioned(left: 0, right: 0, top: 260, child: Center(child: Container(width: 100, height: 100, alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)])),
          child: Text(hanja, style: const TextStyle(fontFamily: 'NotoSerifKRWish', fontWeight: FontWeight.w900, fontSize: 40, color: Colors.white))))),
        Positioned(left: 24, right: 24, top: 390, child: Column(children: [
          const Text('🔐', style: TextStyle(fontSize: 30)),
          const SizedBox(height: 8),
          Text('소원이 다시 봉인되었습니다.', style: WrF.display(22), textAlign: TextAlign.center),
          const SizedBox(height: 14),
          Text(dateK, style: const TextStyle(fontFamily: 'NotoSerifKRWish', fontWeight: FontWeight.w900, fontSize: 22, color: Color(0xFFFFE08A))),
          const SizedBox(height: 12),
          Text('그날까지 소원을 소중히 간직하세요. ✨', textAlign: TextAlign.center, style: WrF.body(14, color: WrC.muted, height: 1.7)),
        ])),
        Positioned(left: 20, right: 20, bottom: 44, child: SizedBox(width: double.infinity, height: WrSize.btnH, child: DecoratedBox(decoration: WrDeco.btnPink,
          child: Material(color: Colors.transparent, child: InkWell(borderRadius: BorderRadius.circular(16), onTap: onGo,
            child: const Center(child: Text('소원방 들어가기', style: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white)))))))),
      ]),
    )));
  }
}

// ============================================================
// app2/review2.jsx › AchieveCinematic + AchieveFlow 1:1 이식
// 타임캡슐 FULFILLED 전용 ~7초 성취 연출 → ReviewWrite → ReviewReward.
// (주의: screens-c2.jsx Complete()/Sealed() 화면과는 다른 플로우 — 거긴 일반 완료 흐름.)
// ============================================================
class AchieveFlowScreen extends StatefulWidget {
  const AchieveFlowScreen({super.key, required this.room});
  final WishRoom room;
  @override
  State<AchieveFlowScreen> createState() => _AchieveFlowScreenState();
}

class _AchieveFlowScreenState extends State<AchieveFlowScreen> {
  late final bool _showReview = !(widget.room.wishStatus == WishStatus.ACHIEVED); // reviewRewardGranted 근사(서버 필드 미노출 시 기본 true)
  bool _cinematicDone = false;

  @override
  Widget build(BuildContext context) {
    if (!_cinematicDone) {
      return AchieveCinematicScreen(room: widget.room, onDone: () => setState(() => _cinematicDone = true));
    }
    if (_showReview) {
      return ReviewWriteScreen(room: widget.room);
    }
    // 이미 보상을 받은 경우(재방문 등) — 곧바로 종료.
    return const SizedBox.shrink();
  }
}

/// app2/review2.jsx › AchieveCinematic — STEP1 봉인 등장 → STEP2 해제 → STEP3 소원 공개 → STEP4 축하(총 ~7s).
class AchieveCinematicScreen extends StatefulWidget {
  const AchieveCinematicScreen({super.key, required this.room, required this.onDone});
  final WishRoom room; final VoidCallback onDone;
  @override
  State<AchieveCinematicScreen> createState() => _AchieveCinematicScreenState();
}

class _AchieveCinematicScreenState extends State<AchieveCinematicScreen> with SingleTickerProviderStateMixin {
  int _t = 0;
  final List<Timer> _timers = [];
  late final AnimationController _rot = AnimationController(vsync: this, duration: const Duration(seconds: 36))..repeat();

  @override
  void initState() {
    super.initState();
    const steps = [1400, 2800, 4000, 5200, 7200];
    for (var i = 0; i < steps.length; i++) {
      _timers.add(Timer(Duration(milliseconds: steps[i]), () {
        if (!mounted) return;
        setState(() => _t = i + 1);
        if (_t == 5) widget.onDone();
      }));
    }
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _rot.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final cat = WrCatalog.I;
    final w = cat.wishColors.firstWhere((e) => e['id'] == room.wishColor, orElse: () => cat.wishColors.first);
    final pp = cat.papers.firstWhere((e) => e['id'] == room.paper, orElse: () => cat.papers.first);
    final color = _hex(w['color'] as String), deep = _hex(w['deep'] as String), hanja = w['hanja'] as String;
    return GestureDetector(
      onTap: () { if (_t >= 4) widget.onDone(); },
      child: Theme(data: wrThemeData(), child: Scaffold(backgroundColor: const Color(0xFF080306), body: Stack(children: [
        AnimatedContainer(duration: const Duration(milliseconds: 1600), decoration: BoxDecoration(gradient: RadialGradient(
          center: const Alignment(0, -.56), radius: 1.1, colors: [_t >= 2 ? const Color(0xFF5A3040) : const Color(0xFF2A1020), const Color(0xFF080306)], stops: const [0, .76]))),
        AnimatedOpacity(duration: const Duration(milliseconds: 1400), opacity: _t >= 2 ? 1 : 0, child: Container(decoration: const BoxDecoration(
          gradient: RadialGradient(center: Alignment(0, -.56), radius: .6, colors: [Color(0x61FFD78C), Colors.transparent])))),
        // 회전 빛줄기
        Positioned(left: 0, right: 0, top: 40, child: Center(child: AnimatedOpacity(duration: const Duration(milliseconds: 1400), opacity: _t >= 2 ? .55 : .12,
          child: AnimatedBuilder(animation: _rot, builder: (_, __) => Transform.rotate(angle: _rot.value * 2 * 3.14159, child: SizedBox(
            width: 520, height: 520, child: Stack(children: [
              for (var i = 0; i < 20; i++) Positioned(left: 259, top: 260, child: Transform.rotate(angle: i * 18 * 3.14159 / 180, alignment: Alignment.topCenter,
                child: Container(width: i.isOdd ? 1.5 : 3, height: 260, decoration: BoxDecoration(gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [const Color(0xCCFFE1A0), Colors.transparent]))))),
            ]),
          ))))),
        ),
        // STEP1·2 — 봉인(말린 두루마리 + 인장)
        if (_t < 3) Positioned(left: 0, right: 0, top: 160, child: Center(child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1), duration: Duration(milliseconds: _t >= 2 ? 900 : 1200), curve: _t >= 2 ? const Cubic(.6, 0, .4, 1) : WrCurves.out,
          builder: (_, raw, __) {
            final t = _t >= 2 ? raw : raw; // unroll-out: scaleY→0, 아니면 등장(scale/opacity)
            if (_t >= 2) {
              final scaleY = 1.0 - t * .9;
              final op = (1 - t).clamp(0.0, 1.0);
              return Opacity(opacity: op, child: Transform.scale(scaleY: scaleY.clamp(.05, 1), child: Container(
                width: 240, height: 40, decoration: BoxDecoration(borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF7EAD0), Color(0xFFD8BF8E), Color(0xFFA8865A)], stops: [0, .6, 1]),
                  boxShadow: const [BoxShadow(color: Color(0x8C000000), blurRadius: 24, offset: Offset(0, 10))]))));
            }
            final scale = .4 + t * .6; final op = t;
            return Opacity(opacity: op, child: Transform.scale(scale: scale, child: Container(
              width: 240, height: 40, decoration: BoxDecoration(borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF7EAD0), Color(0xFFD8BF8E), Color(0xFFA8865A)], stops: [0, .6, 1]),
                boxShadow: const [BoxShadow(color: Color(0x8C000000), blurRadius: 24, offset: Offset(0, 10))]))));
          },
        ))),
        if (_t < 3) Positioned(left: 0, right: 0, top: 266, child: Center(child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1), duration: Duration(milliseconds: _t >= 2 ? 1100 : 1200), curve: const Cubic(.6, 0, .4, 1),
          builder: (_, raw, __) {
            double scale; double op = 1; double glow = _t >= 1 ? 50 : 20;
            if (_t >= 2) { scale = raw < .375 ? 1 + raw / .375 * .15 : raw < .5 ? 1.15 - (raw - .375) / .125 * .1 : 1.6 * ((raw - .5) / .5).clamp(0.0, 1.0) + 1.05 * (1 - ((raw - .5) / .5).clamp(0.0, 1.0)); op = raw < .5 ? 1 : (1 - (raw - .5) / .5).clamp(0.0, 1.0); }
            else { scale = .3 + raw * .7; op = raw; }
            return Opacity(opacity: op.clamp(0.0, 1.0), child: Transform.scale(scale: scale.clamp(0.1, 2.0), child: Container(
              width: 68, height: 68, alignment: Alignment.center,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color, deep]),
                boxShadow: [BoxShadow(color: color, blurRadius: glow)]),
              child: Text(hanja, style: const TextStyle(fontFamily: 'NotoSerifKRWish', fontWeight: FontWeight.w900, fontSize: 34, color: Color(0xFFFFF4E0))))));
          },
        ))),
        if (_t < 2) const Positioned(left: 0, right: 0, top: 370, child: Center(child: Text('🔐 봉인된 소원', style: TextStyle(fontFamily: 'GowunBatangWish', fontSize: 13, color: Color(0xB3FFEBD2))))),
        // STEP2 — 해제의 빛
        if (_t >= 2 && _t < 4) ...[
          Positioned(left: 0, right: 0, top: 100, child: Center(child: Container(width: 400, height: 400, decoration: const BoxDecoration(
            shape: BoxShape.circle, gradient: RadialGradient(colors: [Colors.white, Color(0xB3FFE6AA), Colors.transparent], stops: [0, .22, .62]))))),
          for (final d in [0.0, .25, .5]) _DelayedRing(delaySeconds: d),
          const Positioned(left: 195, top: 300, child: WrBurst(x: 0, y: 0, n: 30, spread: 190, color: Color(0xFFFFE6B0))),
        ],
        // STEP3 — 소원 공개
        if (_t >= 3) Positioned(left: 26, right: 26, top: 190, child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1), duration: const Duration(milliseconds: 1200), curve: const Cubic(.22, 1, .36, 1),
          builder: (_, t, child) => Opacity(opacity: t, child: Transform.scale(scaleY: .1 + t * .9, alignment: Alignment.topCenter, child: child)),
          child: Column(children: [
            Container(height: 12, decoration: BoxDecoration(borderRadius: BorderRadius.circular(6),
              gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF8A5A34), Color(0xFF5A3418)]))),
            Container(margin: const EdgeInsets.symmetric(horizontal: 8), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
              decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [_hex((pp['bg'] as List)[0] as String), _hex((pp['bg'] as List)[1] as String)]),
                boxShadow: [BoxShadow(color: color.withValues(alpha: .53), blurRadius: 40), const BoxShadow(color: Color(0x80000000), blurRadius: 30, offset: Offset(0, 14))]),
              child: Text('"${room.text}"', textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'GowunBatangWish', fontWeight: FontWeight.w700, fontSize: 17, height: 1.7, color: Color(0xFF4A2A1C)))),
            Container(height: 12, decoration: BoxDecoration(borderRadius: BorderRadius.circular(6),
              gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF5A3418), Color(0xFF8A5A34)]))),
          ]),
        )),
        if (_t >= 3) Positioned(left: 0, right: 0, top: 420, child: Center(child: ShaderMask(
          shaderCallback: (b) => const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFF8E0), Color(0xFFFFD98A), Color(0xFFF5A86A)]).createShader(b),
          child: const Text('✨ 소원이 이루어졌어요', style: TextStyle(fontFamily: 'NotoSerifKRWish', fontWeight: FontWeight.w900, fontSize: 30, color: Colors.white, letterSpacing: -.5))))),
        // STEP4 — 축하
        if (_t >= 4) Positioned(left: 24, right: 24, top: 480, child: Column(children: [
          Text('정말 축하합니다.', style: WrF.display(19), textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Text('오랫동안 간직했던 소원이\n현실이 되었습니다. 💛', textAlign: TextAlign.center, style: WrF.body(14, color: const Color(0xD9FFEEDC), height: 1.75)),
        ])),
        if (_t >= 4) const Positioned.fill(child: IgnorePointer(child: WrPetalRain(n: 16, dur: (5, 8), spread: 4))),
      ]))),
    );
  }
}

/// STEP2 "해제의 빛" ring 애니메이션 — wr2.css `ring 1.8s cubic-bezier(.22,1,.36,1) ${d}s both`의
/// 지연시작(delay)을 재현하기 위한 헬퍼. d(초) 만큼 기다린 뒤 1800ms 스케일/페이드 애니메이션을 시작한다.
class _DelayedRing extends StatefulWidget {
  const _DelayedRing({required this.delaySeconds});
  final double delaySeconds;

  @override
  State<_DelayedRing> createState() => _DelayedRingState();
}

class _DelayedRingState extends State<_DelayedRing> {
  bool _start = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(Duration(milliseconds: (widget.delaySeconds * 1000).round()), () {
      if (mounted) setState(() => _start = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      top: 200,
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: _start ? 1 : 0),
          duration: const Duration(milliseconds: 1800),
          curve: const Cubic(.22, 1, .36, 1),
          builder: (_, raw, __) {
            return Opacity(
              opacity: (1 - raw).clamp(0.0, 1.0),
              child: Transform.scale(
                scale: .2 + raw * 2.4,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xD9FFE1A0), width: 1.5),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
