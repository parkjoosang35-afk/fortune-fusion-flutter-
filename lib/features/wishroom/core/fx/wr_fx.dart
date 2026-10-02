// 신통방통 소원방 · 공용 FX 위젯 — app2/fx2.jsx 1:1 이식
// Hearts(❤ 떠오름) · Burst(링+파티클 터짐) · PetalRain(꽃잎비) · Butterflies(나비 4) ·
// SCR-06/SCR-07/SCR-10 등 여러 화면에서 공용으로 사용.
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

/// PetalRain({n, dur, spread}) — 꽃잎 n장이 위에서 떨어짐(1회, 끝나면 멈춤). fall ~dur[0]-dur[1]s linear.
/// spread = 지연 분산(초). app2/fx2.jsx › PetalRain() 1:1 이식(이미지 대신 그라디언트 잎 모양).
class WrPetalRain extends StatefulWidget {
  const WrPetalRain({super.key, this.n = 22, this.dur = const (3.0, 4.6), this.spread = .9});
  final int n;
  final (double, double) dur;
  final double spread;
  @override
  State<WrPetalRain> createState() => _WrPetalRainState();
}

class _WrPetalRainState extends State<WrPetalRain> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final List<_PetalSpec> _ps;

  @override
  void initState() {
    super.initState();
    final rnd = math.Random();
    _ps = List.generate(widget.n, (_) {
      final d = widget.dur.$1 + rnd.nextDouble() * (widget.dur.$2 - widget.dur.$1);
      return _PetalSpec(
        l: rnd.nextDouble() * 100, dx: -80 + rnd.nextDouble() * 160, r: 360 + rnd.nextDouble() * 540,
        d: d, dl: rnd.nextDouble() * widget.spread, s: 9 + rnd.nextDouble() * 6,
      );
    });
    final maxTotal = _ps.map((p) => p.d + p.dl).fold<double>(0, math.max);
    _c = AnimationController(vsync: this, duration: Duration(milliseconds: (maxTotal * 1000).round()))..forward();
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(child: IgnorePointer(child: LayoutBuilder(builder: (context, c) {
      final total = _c.duration!.inMilliseconds / 1000.0;
      return AnimatedBuilder(animation: _c, builder: (_, __) {
        final now = _c.value * total;
        return Stack(clipBehavior: Clip.none, children: [
          for (final p in _ps) () {
            final raw = ((now - p.dl) / p.d).clamp(0.0, 1.0);
            final opacity = raw <= 0 ? 0.0 : raw < .08 ? raw / .08 * .95 : (.95 - raw * .65);
            return Positioned(
              left: c.maxWidth * p.l / 100 + p.dx * raw, top: -20 + (c.maxHeight + 40) * raw,
              child: Opacity(opacity: opacity.clamp(0.0, 1.0), child: Transform.rotate(angle: p.r * raw * math.pi / 180,
                child: Container(width: p.s, height: p.s * .7, decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(p.s * .5),
                  gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFE0EA), Color(0xFFF07AA2)]),
                  boxShadow: const [BoxShadow(color: Color(0xCCFF96BE), blurRadius: 8)])))),
            );
          }(),
        ]);
      });
    })));
  }
}

class _PetalSpec { final double l, dx, r, d, dl, s; _PetalSpec({required this.l, required this.dx, required this.r, required this.d, required this.dl, required this.s}); }

/// Butterflies({x, y}) — 나비 4마리가 서로 다른 경로로 위로 날아오르며 사라짐(1회). bf-path ~3-3.8s.
/// app2/fx2.jsx › Butterflies()/Butterfly() 1:1 이식(SVG 대신 이모지 글리프로 대체).
class WrButterflies extends StatefulWidget {
  const WrButterflies({super.key, this.x = 204, this.y = 380});
  final double x, y;
  @override
  State<WrButterflies> createState() => _WrButterfliesState();
}

class _WrButterfliesState extends State<WrButterflies> with SingleTickerProviderStateMixin {
  static const _specs = [(Color(0xFFFFD6F0), -90.0, 3200), (Color(0xFFA8E8FF), 80.0, 3600), (Color(0xFFFFE8A8), -30.0, 3000), (Color(0xFFC8F0FF), 40.0, 3800)];
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 4500))..forward();

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Positioned(left: widget.x, top: widget.y, child: IgnorePointer(child: SizedBox(width: 1, height: 1,
      child: Stack(clipBehavior: Clip.none, children: [
        for (var i = 0; i < _specs.length; i++) AnimatedBuilder(animation: _c, builder: (_, __) {
          final (color, dx, durMs) = _specs[i];
          final dl = i * .18;
          final total = _c.duration!.inMilliseconds / 1000.0;
          final raw = (((_c.value * total) - dl) / (durMs / 1000.0)).clamp(0.0, 1.0);
          double opacity, prog, scale;
          if (raw < .15) { opacity = raw / .15; prog = raw / .15 * .3; scale = .3 + .7 * (raw / .15); }
          else if (raw < .6) { final k = (raw - .15) / .45; opacity = 1; prog = .3 + k * .7; scale = 1; }
          else { final k = (raw - .6) / .4; opacity = 1 - k; prog = 1 + k * .4; scale = 1 - k * .3; }
          final left = (i.isOdd ? 10.0 : -20.0) + dx * prog;
          final top = -150.0 * math.min(1, prog / .6) - (prog > .6 ? (prog - .6) * 275 : 0);
          return Positioned(left: left, top: top, child: Opacity(opacity: opacity.clamp(0.0, 1.0),
            child: Transform.scale(scale: scale, child: Text('🦋', style: TextStyle(fontSize: 22, shadows: [Shadow(color: color, blurRadius: 10)])))));
        }),
      ]),
    )));
  }
}
