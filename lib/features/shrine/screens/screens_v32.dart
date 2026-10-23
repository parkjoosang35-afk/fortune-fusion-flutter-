// v3.2 — 열리는 문(/shrine/door) · 부적 설명서(showTalisManual)
// 웹 shrine-screens-e.jsx · shrine-screens-c.jsx(TalisManual) 와 1:1.
// [provider+Navigator 1.0 포팅] screens.dart와 동일한 규칙으로 기계적으로 치환했다.
//  · ConsumerStatefulWidget/ConsumerState → StatefulWidget/State
//  · ref.watch(shrineProvider)            → context.watch<ShrineSessionProvider>().state
//  · ref.read(shrineProvider)             → context.read<ShrineSessionProvider>().state
//  · context.go('$kShrineBase/id')        → ShrineNav.go(context, 'id')
//  · showTalisManual(context, ref, {...}) → showTalisManual(context, {...}) (ref 매개변수 제거)
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../engine/shrine_engine.dart';
import '../state/shrine_session_provider.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/shrine_video.dart';
import '../widgets/bujeok.dart';
import '../widgets/shrine_nav.dart';
import '../shrine_module.dart' show shrine;

// ※ 00 신통방통 소원방 홈 목업(StbHomeScreen)은 삭제 — 실제 신통방통 앱의 홈·하단바를 그대로 쓰고,
//   하단바의 「신당 부적」 탭이 이 모듈의 진입점(ShrineTab)이다. integration/ 참고.

// ═══════════ 02 문 열림 (/door) — 두 문짝이 원근으로 열리고 카메라가 안으로 ═══════════
// 0 닫힘(0.5s) → 1 문틈 빛+진동(1.4s) → 2 문짝 열림 rotateY ±84°(2.2s) → 3 진입 scale 1.35→1, 문틀 1.8배(1.4s) → 4 붉은 섬광(.8s) → /hall
class DoorScreenV32 extends StatefulWidget { const DoorScreenV32({super.key}); @override State<DoorScreenV32> createState() => _DoorV32State(); }
class _DoorV32State extends State<DoorScreenV32> with TickerProviderStateMixin {
  int ph = 0; final _ts = <Timer>[];
  late final _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 120))..repeat();
  @override
  void initState() {
    super.initState();
    if (context.read<ShrineSessionProvider>().state.reduce) { _ts.add(Timer(const Duration(milliseconds: 500), _go)); return; }
    for (final (ms, p) in [(500, 1), (1900, 2), (3500, 3), (4900, 4)]) { _ts.add(Timer(Duration(milliseconds: ms), () => mounted ? setState(() => ph = p) : null)); }
    _ts.add(Timer(const Duration(milliseconds: 5700), _go));
  }
  void _go() { if (mounted) ShrineNav.go(context, 'hall', replace: true); }
  @override void dispose() { for (final x in _ts) { x.cancel(); } _shake.dispose(); super.dispose(); }
  Widget _leaf(bool left) => AnimatedBuilder(animation: _shake, builder: (_, child) {
      final j = ph == 1 ? (math.sin(_shake.value * math.pi * 2) * .6) : 0.0;
      return Transform.translate(offset: Offset(j, -j * .6), child: child);
    },
    child: TweenAnimationBuilder<double>(tween: Tween(begin: 0, end: ph >= 2 ? 1 : 0), duration: const Duration(milliseconds: 2200), curve: const Cubic(.55, 0, .2, 1),
      builder: (_, v, child) => Transform(alignment: left ? Alignment.centerLeft : Alignment.centerRight,
        transform: Matrix4.identity()..setEntry(3, 2, .0011)..rotateY((left ? 1 : -1) * v * 84 * math.pi / 180), child: child),
      child: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1A0503), Color(0xFF3A0D08), Color(0xFF5A140C), Color(0xFF3A0D08), Color(0xFF1A0503)], stops: [0, .18, .5, .82, 1]),
          boxShadow: [BoxShadow(color: Color(0xD9000000), blurRadius: 60, spreadRadius: -20)]),
        child: Stack(children: [
          Positioned.fill(child: FractionallySizedBox(widthFactor: .72, heightFactor: .76, child: Container(decoration: BoxDecoration(border: Border.all(color: const Color(0x59D6AA64), width: 2))))),
          Align(alignment: Alignment(left ? .8 : -.8, 0), child: Container(width: 34, height: 34, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFB08A3E), width: 4)))),
          Align(alignment: Alignment(left ? .98 : -.98, -.55), child: Transform.rotate(angle: left ? -.05 : .07, child: Container(width: 30, height: 96, alignment: Alignment.center,
            decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF2C100), Color(0xFFE0A800)])),
            child: Text('敕\n令', textAlign: TextAlign.center, style: T(1).display(15, w: FontWeight.w900, c: const Color(0xFFC8170F)).copyWith(height: 1.4))))),
        ]))));
  @override
  Widget build(BuildContext context) {
    final t = T(context.watch<ShrineSessionProvider>().state.ts);
    return Scaffold(backgroundColor: Colors.black, body: Stack(fit: StackFit.expand, children: [
      // 문 너머 — 영상(문)이 비치다가 진입하며 신당 내부로
      AnimatedScale(scale: ph >= 3 ? 1 : 1.35, duration: const Duration(milliseconds: 2600), curve: const Cubic(.3, 0, .2, 1), child: Stack(fit: StackFit.expand, children: [
        const ShrineVideo(name: 'door', poster: 'door', loop: false),
        AnimatedOpacity(opacity: ph >= 3 ? 1 : 0, duration: const Duration(milliseconds: 1400), child: Image.asset('assets/shrine/img/hall.jpg', fit: BoxFit.cover)),
        AnimatedContainer(duration: const Duration(milliseconds: 2000), color: Colors.black.withValues(alpha: ph >= 3 ? 0 : ph >= 2 ? .2 : .75)),
      ])),
      AnimatedScale(scale: ph >= 3 ? 1.8 : 1, duration: const Duration(milliseconds: 2600), curve: const Cubic(.3, 0, .2, 1), child: Row(children: [Expanded(child: _leaf(true)), Expanded(child: _leaf(false))])),
      // 문틈 빛
      Center(child: AnimatedOpacity(opacity: ph == 1 ? 1 : 0, duration: const Duration(milliseconds: 600), child: Container(width: 2, decoration: const BoxDecoration(color: Color(0xFFFFCFAA),
        boxShadow: [BoxShadow(color: Color(0xE6FF5032), blurRadius: 14, spreadRadius: 4), BoxShadow(color: Color(0x99E0412F), blurRadius: 70, spreadRadius: 24), BoxShadow(color: Color(0x73A11D19), blurRadius: 180, spreadRadius: 60)])))),
      // 현판
      AnimatedSlide(offset: ph >= 3 ? const Offset(0, -1.2) : Offset.zero, duration: const Duration(milliseconds: 2600), child: Align(alignment: Alignment.topCenter, child: Container(height: 64, width: double.infinity, alignment: const Alignment(0, .6),
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF120302), Color(0xFF2A0806)]), border: Border(bottom: BorderSide(color: Color(0x66D6AA64), width: 2))),
        child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2), decoration: BoxDecoration(color: const Color(0xFF1A0503), border: Border.all(color: const Color(0x99D6AA64), width: 1.5)),
          child: Text('神堂', style: t.display(15, w: FontWeight.w900, c: C.gold).copyWith(letterSpacing: 6)))))),
      const Embers(count: 16),
      Positioned(left: 0, right: 0, bottom: 70, child: Text(ph < 2 ? '문 너머에서, 무언가 숨을 고릅니다.' : ph < 4 ? '들어오십시오.' : '', textAlign: TextAlign.center, style: t.body(14, c: C.muted))),
      // 섬광
      IgnorePointer(child: AnimatedOpacity(opacity: ph >= 4 ? 1 : 0, duration: const Duration(milliseconds: 800), child: const DecoratedBox(decoration: BoxDecoration(gradient: RadialGradient(colors: [Color(0xE6FF8C64), Color(0xB3E0412F), C.bg], stops: [0, .3, .8]))))),
      Positioned(top: 54, right: 16, child: GestureDetector(onTap: _go, child: Container(height: 32, padding: const EdgeInsets.symmetric(horizontal: 14), alignment: Alignment.center,
        decoration: BoxDecoration(color: const Color(0x80080404), borderRadius: BorderRadius.circular(999), border: Border.all(color: C.goldLine)), child: Text('SKIP ›', style: t.mono.copyWith(letterSpacing: 2.5, color: C.muted))))),
    ]));
  }
}

// ═══════════ 부적 설명서 — 부적을 누르면 (부적함 · 받기 · 결과 공통) ═══════════
void showTalisManual(BuildContext context, {required TalismanSpec spec, BoxItem? item, List<(String, String, VoidCallback)>? actions}) {
  showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, barrierColor: const Color(0x99000000), builder: (_) => _TalisManual(spec: spec, item: item, actions: actions));
}
class _TalisManual extends StatefulWidget { final TalismanSpec spec; final BoxItem? item; final List<(String, String, VoidCallback)>? actions;
  const _TalisManual({required this.spec, this.item, this.actions}); @override State<_TalisManual> createState() => _TMState(); }
class _TMState extends State<_TalisManual> {
  String tab = 'what';
  @override
  Widget build(BuildContext context) {
    final st = context.watch<ShrineSessionProvider>().state; final t = T(st.ts); final sp = widget.spec; final cp = shrine.talismans.copy[sp.type] as Map;
    final fl = shrine.talismans.flavors[sp.flavor] as Map?;
    final name = nameShown(st.name, widget.item?.mode ?? 'full');
    Widget h(String s) => Padding(padding: const EdgeInsets.fromLTRB(0, 16, 0, 8), child: Text(s, style: t.mono.copyWith(color: C.gold)));
    return ConstrainedBox(constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .88), child: Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 26),
      decoration: const BoxDecoration(borderRadius: BorderRadius.vertical(top: Radius.circular(22)), gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF1B0D0B), Color(0xFF0A0505)]), border: Border(top: BorderSide(color: C.goldLine))),
      child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          BujeokSheet(w: 92, name: name, spec: sp), const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${sp.head}${widget.item != null ? ' · ${widget.item!.no}' : ''}', style: t.mono.copyWith(color: C.gold)),
            Text(sp.name, style: t.display(24, w: FontWeight.w900, h: 1.2)),
            Text.rich(TextSpan(children: [TextSpan(text: '${sp.phrase}  ', style: t.display(15, w: FontWeight.w900, c: C.redHot).copyWith(letterSpacing: 4)), TextSpan(text: sp.phraseMeaning, style: t.body(13, c: C.muted))])),
            if (fl != null) Text('${fl['k']} ${fl['label']}에서 나온 부적', style: t.ui(11.5, c: C.faint)),
            const SizedBox(height: 8),
            BjOneBadge(name: name, spec: sp, serial: widget.item != null ? '神堂 · ${widget.item!.no}' : null, compact: true),
          ])),
          IconButton(onPressed: () => Navigator.pop(context), icon: const Text('✕', style: TextStyle(color: C.fg))),
        ]),
        const SizedBox(height: 16),
        Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: const Color(0x0DEFE4D2), borderRadius: BorderRadius.circular(12), border: Border.all(color: C.line)),
          child: Row(children: [for (final x in [('what', '어떤 부적'), ('use', '간직하는 법'), ('end', '삼갈 것 · 보내는 법')]) Expanded(child: GestureDetector(onTap: () => setState(() => tab = x.$1), child: Container(height: 36, alignment: Alignment.center,
            decoration: BoxDecoration(color: tab == x.$1 ? C.red : null, borderRadius: BorderRadius.circular(9), boxShadow: tab == x.$1 ? Glow.red(14) : null), child: Text(x.$2, style: t.ui(12.5, w: FontWeight.w600, c: tab == x.$1 ? C.btnText : C.muted)))))])),
        const SizedBox(height: 12),
        if (tab == 'what') ...[
          Text(cp['what'], style: t.body(14, c: const Color(0xE0EFE4D2), h: 1.8)),
          h('뜻하는 바'),
          for (final (i, e) in (cp['effects'] as List).indexed) Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: const Color(0xD90E0706), borderRadius: BorderRadius.circular(10), border: Border.all(color: C.line)),
            child: Row(children: [Container(width: 24, height: 24, alignment: Alignment.center, decoration: BoxDecoration(color: const Color(0xFFEFB800), borderRadius: BorderRadius.circular(6)),
              child: Text(['一', '二', '三'][i], style: t.display(12, w: FontWeight.w900, c: const Color(0xFFC81A10)))), const SizedBox(width: 10), Expanded(child: Text(e, style: t.body(14, w: FontWeight.w700, h: 1.4)))])),
          h('이럴 때 지니십시오'),
          for (final e in cp['when'] as List) Text('·  $e', style: t.body(13.5, c: const Color(0xD9EFE4D2), h: 1.8)),
        ],
        if (tab == 'use') ...[
          Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2), decoration: BoxDecoration(color: const Color(0xD90E0706), borderRadius: BorderRadius.circular(12), border: Border.all(color: C.goldLine)),
            child: Column(children: [for (final (i, u) in (cp['use'] as List).indexed) Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(border: i == 0 ? null : const Border(top: BorderSide(color: C.line))),
              child: Row(children: [Container(width: 30, height: 30, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: C.goldDim)),
                child: Text(['壹', '貳', '參'][i], style: t.display(13, w: FontWeight.w900, c: C.gold))), const SizedBox(width: 12), Expanded(child: Text(u, style: t.body(14.5, w: FontWeight.w700, h: 1.45)))]))])),
          Padding(padding: const EdgeInsets.only(top: 16), child: Center(child: Text('"${cp['line']}"', textAlign: TextAlign.center, style: t.body(14, c: C.muted)))),
        ],
        if (tab == 'end') ...[
          h('삼갈 것'), for (final e in cp['avoid'] as List) Text('✕  $e', style: t.body(13.5, c: const Color(0xD9EFE4D2), h: 1.8)),
          h('보내는 법'), Text(cp['end'], style: t.body(14, c: const Color(0xE0EFE4D2), h: 1.8)),
        ],
        Padding(padding: const EdgeInsets.only(top: 14), child: Text('신당의 부적은 이야기 속 창작 부적입니다. 질병 · 사고 · 금전 문제의 해결을 약속하지 않습니다.', style: t.ui(11, c: C.faint))),
        if (widget.actions != null) Padding(padding: const EdgeInsets.only(top: 12), child: Container(clipBehavior: Clip.antiAlias, decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: C.goldLine)),
          child: Row(children: [for (final a in widget.actions!) Expanded(child: GestureDetector(onTap: a.$3, child: Container(color: const Color(0xF20E0706), margin: const EdgeInsets.symmetric(horizontal: .5), padding: const EdgeInsets.fromLTRB(0, 13, 0, 11),
            child: Column(children: [Text(a.$1, style: t.display(16, w: FontWeight.w900, c: C.gold)), const SizedBox(height: 7), Text(a.$2, style: t.ui(12))]))))]))),
      ]))));
  }
}
