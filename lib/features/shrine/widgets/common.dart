// 공통 위젯: 빨강 버튼 · 주제 버튼 · 필 · 화자 배지 · 상단바 · 타자기 · 파티클 · 그레인
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/tokens.dart';

/// 빨강 버튼 — h56, r12, 금테(.7) + 안쪽 4px 금 이중선(.28), 붉은 글로우, 누르면 scale .97
class RedButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final double ts;
  const RedButton(this.label, {super.key, this.onTap, this.ts = 1});
  @override
  State<RedButton> createState() => _RedButtonState();
}
class _RedButtonState extends State<RedButton> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) { setState(() => _down = false); widget.onTap?.call(); },
      child: AnimatedScale(scale: _down ? .97 : 1, duration: const Duration(milliseconds: 200),
        child: Container(
          height: 56,
          decoration: BoxDecoration(gradient: redButtonGradient, borderRadius: BorderRadius.circular(R.btn),
            border: Border.all(color: const Color(0xB3D6AA64)), boxShadow: Glow.btnRed),
          child: Stack(alignment: Alignment.center, children: [
            Positioned.fill(child: Container(margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(9), border: Border.all(color: const Color(0x47D6AA64))))),
            Text(widget.label, style: T(widget.ts).body(16, w: FontWeight.w700, c: C.btnText, h: 1.2)),
            const Positioned(right: 18, child: Text('›', style: TextStyle(fontSize: 18, color: Color(0xD9F8EAD6)))),
          ]),
        )),
    );
  }
}

/// 주제 버튼 — h54, r11, 좌측 34px 원형 한자 인장
class TopicButton extends StatelessWidget {
  final String sig, label, desc;
  final VoidCallback onTap;
  final double ts;
  const TopicButton({super.key, required this.sig, required this.label, required this.desc, required this.onTap, this.ts = 1});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap, child: Container(
    constraints: const BoxConstraints(minHeight: 54), padding: const EdgeInsets.fromLTRB(12, 8, 18, 8),
    decoration: BoxDecoration(gradient: optGradient, borderRadius: BorderRadius.circular(R.opt), border: Border.all(color: const Color(0x8CD6AA64))),
    child: Row(children: [
      Container(width: 34, height: 34, alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0x40000000), border: Border.all(color: const Color(0x8CD6AA64))),
        child: Text(sig, style: T(1).display(15, w: FontWeight.w900, c: C.gold))),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: T(ts).body(15, w: FontWeight.w700, c: C.btnText, h: 1.3)),
        Text(desc, style: T(ts).ui(11.5, c: const Color(0x99F8EAD6))),
      ])),
      const Text('›', style: TextStyle(color: Color(0x99F8EAD6))),
    ]),
  ));
}

/// 필 — h50, r999, 반투명 + blur
class Pill extends StatelessWidget {
  final String label; final VoidCallback onTap; final double ts;
  const Pill(this.label, {super.key, required this.onTap, this.ts = 1});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap, child: Container(
    height: 50, alignment: Alignment.center,
    decoration: BoxDecoration(color: const Color(0x1AEFE4D2), borderRadius: BorderRadius.circular(R.pill), border: Border.all(color: const Color(0x47EFE4D2))),
    child: Text(label, style: T(ts).ui(14.5)),
  ));
}

/// 화자 배지 "월화 月華"
class SpeakerBadge extends StatelessWidget {
  final String name; final String? hanja; final bool voice;
  const SpeakerBadge(this.name, {super.key, this.hanja, this.voice = false});
  @override
  Widget build(BuildContext context) => Container(
    height: 24, padding: const EdgeInsets.symmetric(horizontal: 11),
    decoration: BoxDecoration(color: voice ? const Color(0xFF2A2424) : C.red, borderRadius: BorderRadius.circular(R.badge),
      border: Border.all(color: voice ? C.line : const Color(0x80D6AA64))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(name, style: T(1).body(12.5, w: FontWeight.w700, c: voice ? C.muted : C.btnText, h: 1)),
      if (hanja != null) ...[const SizedBox(width: 7), Text(hanja!, style: T(1).display(10, w: FontWeight.w900, c: const Color(0xB3F8EAD6)))],
    ]),
  );
}

/// 상단바 — 좌 뒤로 / 가운데 slot / 우 소리·설정 (38px 원형 아이콘 버튼)
class TopBar extends StatelessWidget {
  final VoidCallback? onBack; final Widget? center; final Widget? trailing;
  final bool soundOn; final VoidCallback onSound, onSettings;
  const TopBar({super.key, this.onBack, this.center, this.trailing, required this.soundOn, required this.onSound, required this.onSettings});
  Widget _ib(String g, VoidCallback f, {bool dim = false}) => GestureDetector(onTap: f, child: Container(
    width: 38, height: 38, alignment: Alignment.center,
    decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0x80080404), border: Border.all(color: C.goldLine)),
    child: Text(g, style: TextStyle(fontSize: 14, color: dim ? C.faint : C.fg))));
  @override
  Widget build(BuildContext context) => SafeArea(bottom: false, child: Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: Row(children: [
      onBack != null ? _ib('←', onBack!) : const SizedBox(width: 38),
      Expanded(child: Center(child: center ?? const SizedBox())),
      if (trailing != null) ...[trailing!, const SizedBox(width: 8)],
      _ib('♪', onSound, dim: !soundOn), const SizedBox(width: 8), _ib('⋯', onSettings),
    ]),
  ));
}

/// 타자기 — 탭하면 즉시 완성
class Typewriter extends StatefulWidget {
  final String text; final int msPerChar; final TextStyle style; final VoidCallback? onDone; final TextAlign align;
  const Typewriter(this.text, {super.key, required this.msPerChar, required this.style, this.onDone, this.align = TextAlign.start});
  @override
  State<Typewriter> createState() => TypewriterState();
}
class TypewriterState extends State<Typewriter> {
  int _n = 0; Timer? _t;
  bool get done => _n >= widget.text.length;
  void finish() { _t?.cancel(); setState(() => _n = widget.text.length); widget.onDone?.call(); }
  @override
  void initState() { super.initState(); _start(); }
  @override
  void didUpdateWidget(covariant Typewriter o) { super.didUpdateWidget(o); if (o.text != widget.text) { _n = 0; _start(); } }
  void _start() {
    _t?.cancel();
    if (widget.msPerChar <= 0) { _n = widget.text.length; WidgetsBinding.instance.addPostFrameCallback((_) => widget.onDone?.call()); return; }
    _t = Timer.periodic(Duration(milliseconds: widget.msPerChar), (t) {
      setState(() => _n++);
      if (done) { t.cancel(); widget.onDone?.call(); }
    });
  }
  @override
  void dispose() { _t?.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Text(widget.text.substring(0, _n.clamp(0, widget.text.length)), style: widget.style, textAlign: widget.align);
}

/// 필름 그레인 / 붉은 숨결 / 불씨 — 모두 IgnorePointer (보이지만 만질 수 없다)
class RedBreath extends StatefulWidget {
  const RedBreath({super.key});
  @override
  State<RedBreath> createState() => _RedBreathState();
}
class _RedBreathState extends State<RedBreath> with SingleTickerProviderStateMixin {
  late final _a = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat(reverse: true);
  @override
  void dispose() { _a.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => IgnorePointer(child: AnimatedBuilder(animation: _a, builder: (_, __) => Opacity(
    opacity: .6 + _a.value * .4,
    child: const DecoratedBox(decoration: BoxDecoration(gradient: RadialGradient(center: Alignment(0, 1), radius: .9,
      colors: [Color(0x80A11D19), Colors.transparent]))))));
}

class Embers extends StatefulWidget {
  final int count;
  const Embers({super.key, this.count = 14});
  @override
  State<Embers> createState() => _EmbersState();
}
class _EmbersState extends State<Embers> with SingleTickerProviderStateMixin {
  late final _a = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
  late final _seeds = List.generate(widget.count, (i) => (math.Random(i * 7).nextDouble(), math.Random(i * 13).nextDouble(), math.Random(i * 31).nextDouble() - .5));
  @override
  void dispose() { _a.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => IgnorePointer(child: AnimatedBuilder(animation: _a, builder: (_, __) => CustomPaint(
    size: Size.infinite, painter: _EmberPainter(_a.value, _seeds))));
}
class _EmberPainter extends CustomPainter {
  final double t; final List<(double, double, double)> s;
  _EmberPainter(this.t, this.s);
  @override
  void paint(Canvas c, Size z) {
    for (final (x, off, dx) in s) {
      final p = (t + off) % 1;
      final o = p < .15 ? p / .15 : (1 - p);
      final pos = Offset(x * z.width + dx * 90 * p, z.height * (1 - p) );
      c.drawCircle(pos, 4, Paint()..color = const Color(0xFFFF7840).withOpacity(o * .35)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      c.drawCircle(pos, 1.5, Paint()..color = const Color(0xFFFFB070).withOpacity(o));
    }
  }
  @override
  bool shouldRepaint(_EmberPainter o) => o.t != t;
}

/// 하단 그라데이션 (영상/그림 아래를 먹색으로 녹인다)
class BottomShade extends StatelessWidget {
  final List<double> stops; final List<Color> colors;
  const BottomShade({super.key, this.stops = const [0, .18, .46, .7, .88],
    this.colors = const [Color(0x73070404), Colors.transparent, Colors.transparent, Color(0xD9070404), C.bg]});
  @override
  Widget build(BuildContext context) => IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(
    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors, stops: stops))));
}
