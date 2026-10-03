// 신통방통 소원방 · 공용 FX 위젯 — app2/fx2.jsx 1:1 이식
// Hearts(❤ 떠오름) · Burst(링+파티클 터짐) · PetalRain(꽃잎비) · Butterflies(나비 4) ·
// SCR-06/SCR-07/SCR-10 등 여러 화면에서 공용으로 사용.
import 'dart:math' as math;
import 'dart:ui' as ui;
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

/// 특별 효과 9종 (방 전체 지속 연출) — app2/room2.jsx › SpecialFx()/
/// special==='starrain'|'butterfly'|'aura' 분기 1:1 이식. 꾸미기 SPECIAL 슬롯
/// 아이템(s_firefly·s_sakura·s_snow·s_rain·s_butter·s_lantern·s_meteor·
/// s_aurora·s_aura)의 fx 값을 그대로 받아 렌더링한다.
///
/// [버그수정 — 전수 감사로 발견] room_scene.dart L7 상시 파티클에 SpecialFx
/// 분기가 전혀 없어 SPECIAL 아이템을 장착해도 화면에 아무 효과도 나타나지
/// 않았다. CustomPainter 단일 루프(_AmbientPainter)가 아니라 원본처럼
/// fx별 전용 애니메이션 위젯으로 분리 구현(투명도·좌표 보간이 CSS keyframes와
/// 다르므로 Flutter AnimationController 기반으로 재현).
class WrSpecialFx extends StatefulWidget {
  const WrSpecialFx({super.key, required this.fx, this.density = 1, this.canvasW = 390, this.canvasH = 844});
  /// null 또는 's_none' → 아무 것도 그리지 않음(원본 `if (!fx) return null`).
  final String? fx;
  /// 저사양 모드 P(0.5) · 기본 1. app2 lowFx ? .5 : 1.
  final double density;
  final double canvasW, canvasH;
  @override
  State<WrSpecialFx> createState() => _WrSpecialFxState();
}

class _WrSpecialFxState extends State<WrSpecialFx> with SingleTickerProviderStateMixin {
  // 모든 효과를 20초 주기의 단일 루프 시계로 구동(room_scene.dart의 `loop`와 동일 패턴).
  late final AnimationController _loop = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
  @override
  void dispose() { _loop.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final fx = widget.fx;
    if (fx == null || fx.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(child: SizedBox(
      width: widget.canvasW, height: widget.canvasH,
      // Stack으로 감싸야 함: case 'aura'의 _GoldAura가 자체적으로 Positioned를 반환하므로
      // SizedBox가 직접 부모가 되면 "ParentData is not a subtype of StackParentData" 런타임 에러 발생.
      child: Stack(clipBehavior: Clip.none, children: [
        AnimatedBuilder(animation: _loop, builder: (_, __) {
          final t = _loop.value * 20; // 초 단위 경과(루프마다 0→20 반복)
          switch (fx) {
            case 'firefly': return CustomPaint(size: Size(widget.canvasW, widget.canvasH), painter: _FireflyPainter(t: t, density: widget.density));
            case 'sakura': return CustomPaint(size: Size(widget.canvasW, widget.canvasH), painter: _FallPainter(t: t, density: widget.density, kind: _FallKind.sakura));
            case 'snow': return CustomPaint(size: Size(widget.canvasW, widget.canvasH), painter: _FallPainter(t: t, density: widget.density, kind: _FallKind.snow));
            case 'lanterns': return CustomPaint(size: Size(widget.canvasW, widget.canvasH), painter: _LanternPainter(t: t, density: widget.density));
            case 'meteor': return CustomPaint(size: Size(widget.canvasW, widget.canvasH), painter: _MeteorPainter(t: t, density: widget.density));
            case 'aurora': return _AuroraBand(t: t);
            case 'starrain': return CustomPaint(size: Size(widget.canvasW, widget.canvasH), painter: _StarRainPainter(t: t, density: widget.density));
            case 'butterfly': return const _ButterflyRoam();
            case 'aura': return const _GoldAura();
            default: return const SizedBox.shrink();
          }
        }),
      ]),
    ));
  }
}

enum _FallKind { sakura, snow }

double _seedFrac(int i, int salt) => ((math.sin(i * 12.9898 + salt * 78.233) * 43758.5453) % 1).abs();

/// firefly — 반딧불이 18개(밀도 보정), ff 8~14s ease-in-out infinite. 좌표 고정, 밝기만 깜빡임.
class _FireflyPainter extends CustomPainter {
  final double t, density; _FireflyPainter({required this.t, required this.density});
  @override void paint(Canvas c, Size s) {
    final n = (18 * density).round();
    final paint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    for (var i = 0; i < n; i++) {
      final q = _seedFrac(i, 41);
      final dur = 8 + q * 6, delay = -q * 8;
      final ph = ((t + delay) % dur) / dur;
      final op = (math.sin(ph * math.pi * 2) * .5 + .5).clamp(0.0, 1.0);
      final x = 20 + q * 350, y = 300 + ((i * 53) % 320);
      paint.color = const Color(0xFFFFF6B0).withValues(alpha: op);
      c.drawCircle(Offset(x, y.toDouble()), 4, paint);
    }
  }
  @override bool shouldRepaint(covariant _FireflyPainter o) => o.t != t;
}

/// sakura/snow — 꽃잎·눈송이가 위→아래 낙하하며 회전. fall 5~15s linear infinite.
class _FallPainter extends CustomPainter {
  final double t, density; final _FallKind kind; _FallPainter({required this.t, required this.density, required this.kind});
  @override void paint(Canvas c, Size s) {
    final n = (18 * density).round();
    for (var i = 0; i < n; i++) {
      final q = _seedFrac(i, 41);
      final dur = kind == _FallKind.sakura ? 5 + q * 3 : 9 + q * 6;
      final delay = kind == _FallKind.sakura ? q * 6 : q * 9;
      final raw = ((t - delay) % dur) / dur;
      if (raw < 0) continue;
      final dx = kind == _FallKind.sakura ? (q - .3) * 220 : (q - .5) * 60;
      final rot = (kind == _FallKind.sakura ? 540 + q * 540 : 0.0) * raw;
      final x = s.width * q + dx * raw, y = -20 + (s.height + 40) * raw;
      final op = raw < .08 ? raw / .08 : (raw > .85 ? (1 - raw) / .15 : 1.0);
      c.save(); c.translate(x, y); c.rotate(rot * math.pi / 180);
      final paint = Paint();
      if (kind == _FallKind.sakura) {
        paint.shader = const LinearGradient(colors: [Color(0xFFFFE0EA), Color(0xFFF58FB2)]).createShader(const Rect.fromLTWH(-6, -4.5, 12, 9));
        c.drawOval(Rect.fromCenter(center: Offset.zero, width: 12, height: 9), paint..color = paint.color.withValues(alpha: op));
      } else {
        paint.color = Colors.white.withValues(alpha: op);
        c.drawCircle(Offset.zero, 3, paint);
      }
      c.restore();
    }
  }
  @override bool shouldRepaint(covariant _FallPainter o) => o.t != t;
}

/// lanterns — 풍등 7개가 아래→위로 승천. lantern-rise 12~18s linear infinite.
class _LanternPainter extends CustomPainter {
  final double t, density; _LanternPainter({required this.t, required this.density});
  @override void paint(Canvas c, Size s) {
    for (var i = 0; i < 7; i++) {
      final q = _seedFrac(i, 41);
      final dur = 12 + q * 6, delay = q * 10;
      final raw = ((t - delay) % dur) / dur;
      if (raw < 0) continue;
      final w = 30 + (i % 3) * 10.0;
      final x = 20 + q * 330 + (q - .5) * 60 * raw, y = s.height + 60 - (s.height + 120) * raw;
      final op = raw < .1 ? raw / .1 : (raw > .85 ? (1 - raw) / .15 : .95);
      final paint = Paint()..color = const Color(0xFFFFAA50).withValues(alpha: op * .9)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, y), width: w, height: w * 1.3), const Radius.circular(6)), paint);
      final core = Paint()..color = const Color(0xFFFFE6A8).withValues(alpha: op);
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, y), width: w * .8, height: w * 1.1), const Radius.circular(5)), core);
    }
  }
  @override bool shouldRepaint(covariant _LanternPainter o) => o.t != t;
}

/// meteor — 유성 6개가 대각선으로 빠르게 스침. meteor 3~6s ease-in infinite.
class _MeteorPainter extends CustomPainter {
  final double t, density; _MeteorPainter({required this.t, required this.density});
  @override void paint(Canvas c, Size s) {
    for (var i = 0; i < 6; i++) {
      final q = _seedFrac(i, 41);
      final dur = 3 + q * 3, delay = q * 6;
      final raw = ((t - delay) % dur) / dur;
      if (raw < 0 || raw > .4) continue; // 원본은 0~40%에서만 opacity>0(ease-in 급가속 streak)
      final op = (1 - raw / .4).clamp(0.0, 1.0);
      final x0 = 120 + q * 280, y0 = 40 + (i % 3) * 40.0;
      final travel = raw / .4 * 160;
      final dx = travel * math.cos(-35 * math.pi / 180), dy = travel * math.sin(-35 * math.pi / 180);
      final paint = Paint()
        ..shader = LinearGradient(colors: [Colors.transparent, const Color(0xFFFFF6D0).withValues(alpha: op)])
            .createShader(Rect.fromLTWH(x0 + dx - 55, y0 + dy - 1, 110, 2))
        ..strokeWidth = 2 ..strokeCap = StrokeCap.round;
      c.save(); c.translate(x0 + dx, y0 + dy); c.rotate(-35 * math.pi / 180);
      c.drawLine(const Offset(-55, 0), const Offset(55, 0), paint);
      c.restore();
    }
  }
  @override bool shouldRepaint(covariant _MeteorPainter o) => o.t != t;
}

/// aurora — 상단 전체 폭 오로라 띠, 좌우로 흐르는 그라디언트. aurora 12s ease-in-out infinite.
class _AuroraBand extends StatelessWidget {
  final double t; const _AuroraBand({required this.t});
  @override Widget build(BuildContext context) {
    final ph = (t % 12) / 12;
    final shift = math.sin(ph * math.pi * 2) * 50; // backgroundSize 200% 왕복 근사
    return Positioned(left: -40 + shift, right: -40 - shift, top: 20, height: 330, child: Opacity(opacity: .6, child: ImageFiltered(
      imageFilter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
      child: DecoratedBox(decoration: BoxDecoration(gradient: const LinearGradient(
        begin: Alignment.centerLeft, end: Alignment.centerRight,
        colors: [Colors.transparent, Color(0x8C5AFFBE), Color(0x80A078FF), Color(0x7359DCFF), Colors.transparent],
        stops: [0.1, .3, .55, .75, .9],
      ))),
    )));
  }
}

/// starrain — 별똥별 9개가 수직으로 빠르게 떨어짐. star-rain 2~4s linear infinite.
class _StarRainPainter extends CustomPainter {
  final double t, density; _StarRainPainter({required this.t, required this.density});
  @override void paint(Canvas c, Size s) {
    final n = (9 * density).round();
    for (var i = 0; i < n; i++) {
      final q = _seedFrac(i, 41);
      final dur = 2 + q * 2, delay = q * 5;
      final raw = ((t - delay) % dur) / dur;
      if (raw < 0) continue;
      final x = 60 + q * 360;
      final y = 90 + raw * 400;
      final op = raw < .1 ? raw / .1 : (raw > .8 ? (1 - raw) / .2 : 1.0);
      final paint = Paint()
        ..shader = LinearGradient(colors: [Colors.transparent, Colors.white.withValues(alpha: op)], begin: Alignment.topCenter, end: Alignment.bottomCenter)
            .createShader(Rect.fromLTWH(x - 1, y - 22, 2, 22));
      c.drawRect(Rect.fromLTWH(x - 1, y - 22, 2, 22), paint);
    }
  }
  @override bool shouldRepaint(covariant _StarRainPainter o) => o.t != t;
}

/// butterfly — 나비 3마리가 정해진 구역을 배회(bf-roam 10~14s ease-in-out infinite).
/// 응원 FX의 1회성 WrButterflies와 달리, 이 효과는 상시 반복이다.
class _ButterflyRoam extends StatefulWidget {
  const _ButterflyRoam();
  @override State<_ButterflyRoam> createState() => _ButterflyRoamState();
}

class _ButterflyRoamState extends State<_ButterflyRoam> with TickerProviderStateMixin {
  static const _specs = [(Color(0xFFFFD6F0), Color(0xFFC8A8FF), 10.0), (Color(0xFFA8E8FF), Color(0xFFFFC8E8), 12.0), (Color(0xFFFFE8A8), Color(0xFFFFB0D0), 14.0)];
  late final List<AnimationController> _cs = [for (final (_, __, dur) in _specs) AnimationController(vsync: this, duration: Duration(milliseconds: (dur * 1000).round()))];
  @override void initState() { super.initState(); for (var i = 0; i < _cs.length; i++) { Future.delayed(Duration(milliseconds: (i * -3000).abs()), () { if (mounted) _cs[i].repeat(); }); } }
  @override void dispose() { for (final c in _cs) { c.dispose(); } super.dispose(); }
  @override Widget build(BuildContext context) {
    return Stack(children: [
      for (var i = 0; i < _specs.length; i++) AnimatedBuilder(animation: _cs[i], builder: (_, __) {
        final (c1, c2, _) = _specs[i];
        final raw = _cs[i].value;
        // bf-roam: 원 궤도를 ease-in-out으로 느리게 오가는 근사(배회 느낌).
        final ang = raw * math.pi * 2;
        final cx = 90 + i * 90.0, cy = 250 + (i % 2) * 90.0;
        final x = cx + 36 * math.sin(ang), y = cy + 22 * math.cos(ang * 1.3);
        return Positioned(left: x, top: y, child: Transform.rotate(angle: math.sin(ang * 3) * .3,
          child: Text('🦋', style: TextStyle(fontSize: 20, shadows: [Shadow(color: c1, blurRadius: 8), Shadow(color: c2, blurRadius: 4)]))));
      }),
    ]);
  }
}

/// aura — 캐릭터 주변 금빛 오라, pulse 3s ease-in-out infinite.
class _GoldAura extends StatelessWidget {
  const _GoldAura();
  @override Widget build(BuildContext context) {
    return const Positioned(left: 204 - 210, top: 420 - 210, child: IgnorePointer(child: DecoratedBox(
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [Color(0x66FFD782), Colors.transparent], stops: [0, .6])),
      child: SizedBox(width: 420, height: 420),
    )));
  }
}

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
