// 신통방통 소원방 · 공용 FX 위젯 — app2/fx2.jsx 1:1 이식
// Hearts(❤ 떠오름) · Burst(링+파티클 터짐) — SCR-06/SCR-07 등 여러 화면에서 공용으로 사용.
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Hearts({x,y,n}) — 하트 n개가 위로 떠오르며 사라짐. heart-up 2.2s
class WrHearts extends StatefulWidget {
  const WrHearts({super.key, required this.x, required this.y, this.n = 10});
  final double x, y;
  final int n;
  @override
  State<WrHearts> createState() => _WrHeartsState();
}

class _WrHeartsState extends State<WrHearts> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..forward();
  late final List<_HeartSpec> _hs;

  @override
  void initState() {
    super.initState();
    final rnd = math.Random();
    _hs = List.generate(widget.n, (_) => _HeartSpec(
      hx: -70 + rnd.nextDouble() * 140,
      hr: -30 + rnd.nextDouble() * 60,
      dl: rnd.nextDouble() * .5,
      s: 16 + rnd.nextDouble() * 14,
    ));
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Positioned(left: widget.x, top: widget.y, child: IgnorePointer(child: SizedBox(
      width: 1, height: 1,
      child: Stack(clipBehavior: Clip.none, children: [
        for (final h in _hs) AnimatedBuilder(animation: _c, builder: (_, __) {
          final raw = ((_c.value - h.dl) / (1 - h.dl)).clamp(0.0, 1.0);
          final t = Curves.easeOutCubic.transform(raw);
          final opacity = raw <= 0 ? 0.0 : (1 - t).clamp(0.0, 1.0);
          return Positioned(
            left: -h.s / 2 + h.hx * t,
            top: -h.s / 2 - 90 * t,
            child: Opacity(opacity: opacity, child: Transform.rotate(angle: h.hr * t * math.pi / 180,
              child: Text('❤', style: TextStyle(fontSize: h.s, color: const Color(0xFFFF6F9A),
                shadows: const [Shadow(color: Color(0xFFFF6F9A), blurRadius: 14)])))),
          );
        }),
      ]),
    )));
  }
}

class _HeartSpec { final double hx, hr, dl, s; _HeartSpec({required this.hx, required this.hr, required this.dl, required this.s}); }

/// Burst({x,y,n,spread,color,glyph,dur}) — 링 확산 + 파티클(또는 글리프) 분산. burst 1.3s / ring 1.3s
class WrBurst extends StatefulWidget {
  const WrBurst({super.key, required this.x, required this.y, this.n = 18, this.spread = 130, this.color = const Color(0xFFFFE08A), this.glyph, this.dur = 1300});
  final double x, y, spread;
  final int n;
  final Color color;
  final String? glyph; // 이모지/텍스트 글리프 대용(원본은 이미지)
  final int dur;
  @override
  State<WrBurst> createState() => _WrBurstState();
}

class _WrBurstState extends State<WrBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: Duration(milliseconds: widget.dur))..forward();
  late final List<_BurstParticle> _ps;

  @override
  void initState() {
    super.initState();
    final rnd = math.Random();
    _ps = List.generate(widget.n, (i) {
      final a = i / widget.n * math.pi * 2 + rnd.nextDouble() * .5;
      final d = widget.spread * (.5 + rnd.nextDouble() * .6);
      return _BurstParticle(bx: math.cos(a) * d, by: math.sin(a) * d - widget.spread * .3, s: 4 + rnd.nextDouble() * 5, dl: rnd.nextDouble() * .12);
    });
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Positioned(left: widget.x, top: widget.y, child: IgnorePointer(child: SizedBox(
      width: 1, height: 1,
      child: Stack(clipBehavior: Clip.none, children: [
        // ring
        AnimatedBuilder(animation: _c, builder: (_, __) {
          final t = Curves.easeOut.transform(_c.value);
          final size = 120.0 * (1 + t * .6);
          final op = (1 - t).clamp(0.0, 1.0);
          return Positioned(left: -size / 2, top: -size / 2, child: Opacity(opacity: op, child: Container(width: size, height: size,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: widget.color, width: 2),
              boxShadow: [BoxShadow(color: widget.color, blurRadius: 20), BoxShadow(color: widget.color.withValues(alpha: .53), blurRadius: 20, spreadRadius: -4)]))));
        }),
        for (final p in _ps) AnimatedBuilder(animation: _c, builder: (_, __) {
          final raw = ((_c.value - p.dl) / (1 - p.dl)).clamp(0.0, 1.0);
          final t = const Cubic(.22, 1, .36, 1).transform(raw);
          final op = raw <= 0 ? 0.0 : (1 - t * .8).clamp(0.0, 1.0);
          final dx = p.bx * t, dy = p.by * t;
          return Positioned(left: dx - p.s / 2, top: dy - p.s / 2, child: Opacity(opacity: op,
            child: widget.glyph != null
              ? Text(widget.glyph!, style: TextStyle(fontSize: p.s * 3))
              : Container(width: p.s, height: p.s, decoration: BoxDecoration(shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [Colors.white, widget.color, widget.color.withValues(alpha: 0)], stops: const [0, .45, .7]),
                  boxShadow: [BoxShadow(color: widget.color, blurRadius: 10)]))));
        }),
      ]),
    )));
  }
}

class _BurstParticle { final double bx, by, s, dl; _BurstParticle({required this.bx, required this.by, required this.s, required this.dl}); }
