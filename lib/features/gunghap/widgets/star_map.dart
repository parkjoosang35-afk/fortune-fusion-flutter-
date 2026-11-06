// ═══════════════════════════════════════════════════════════════
// FILE: star_map.dart
// [궁합지도 Star Map 디자인 적용] `flutter_starter/.../star_map.dart`
// 포팅본 — 두 사람의 별이 하나의 별자리로 이어지는 핵심 그래픽.
// Logical canvas 320×240, scales to width (AspectRatio 4:3).
// ═══════════════════════════════════════════════════════════════
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../theme/gh_tokens.dart';

const _a = Offset(62, 150), _b = Offset(258, 82);
const _path = [
  Offset(62, 150),
  Offset(102, 108),
  Offset(144, 130),
  Offset(182, 88),
  Offset(220, 110),
  Offset(258, 82),
];
const _branches = [
  [Offset(144, 130), Offset(150, 182)],
  [Offset(182, 88), Offset(172, 44)],
  [Offset(102, 108), Offset(88, 66)],
  [Offset(220, 110), Offset(236, 160)],
];

class StarMap extends StatefulWidget {
  const StarMap({
    super.key,
    this.aName,
    this.bName,
    this.rings = true,
    this.big = false,
    this.draw = true,
    this.labels = true,
  });
  final String? aName, bName;
  final bool rings, big, draw, labels;
  @override
  State<StarMap> createState() => _StarMapState();
}

class _StarMapState extends State<StarMap> with TickerProviderStateMixin {
  late final AnimationController _draw = AnimationController(
    vsync: this,
    duration:
        GHMotion.lineSegment +
        GHMotion.lineStagger * (_path.length - 2) +
        const Duration(milliseconds: 400),
  );
  late final AnimationController _ring = AnimationController(
    vsync: this,
    duration: GHMotion.ringRevolution,
  )..repeat();

  @override
  void initState() {
    super.initState();
    widget.draw ? _draw.forward() : _draw.value = 1;
  }

  @override
  void dispose() {
    _draw.dispose();
    _ring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 4 / 3,
    child: AnimatedBuilder(
      animation: Listenable.merge([_draw, _ring]),
      builder: (_, _) => CustomPaint(
        painter: _StarMapPainter(
          progress: _draw.value,
          ringTurn: _ring.value,
          rings: widget.rings,
          big: widget.big,
          aName: widget.labels ? widget.aName : null,
          bName: widget.labels ? widget.bName : null,
        ),
      ),
    ),
  );
}

class _StarMapPainter extends CustomPainter {
  _StarMapPainter({
    required this.progress,
    required this.ringTurn,
    required this.rings,
    required this.big,
    this.aName,
    this.bName,
  });
  final double progress, ringTurn;
  final bool rings, big;
  final String? aName, bName;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 320;
    canvas.save();
    canvas.scale(k);
    const center = Offset(160, 120);

    // rotating chart ring
    if (rings) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(ringTurn * 2 * pi);
      canvas.translate(-center.dx, -center.dy);
      final rp = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .6
        ..color = GHColors.gold.withValues(alpha: .16);
      canvas.drawCircle(center, 104, rp);
      canvas.drawCircle(center, 78, rp..color = GHColors.gold.withValues(alpha: .10));
      final tp = Paint()
        ..strokeWidth = .5
        ..color = GHColors.gold.withValues(alpha: .28);
      for (var i = 0; i < 48; i++) {
        final a = i / 48 * 2 * pi, r1 = i % 4 == 0 ? 98.0 : 101.0;
        canvas.drawLine(
          center + Offset(cos(a) * r1, sin(a) * r1),
          center + Offset(cos(a) * 104, sin(a) * 104),
          tp,
        );
      }
      canvas.restore();
    }
    // core glow
    canvas.drawCircle(
      const Offset(163, 112),
      70,
      Paint()
        ..shader = ui.Gradient.radial(const Offset(163, 112), 70, [
          GHColors.ivory.withValues(alpha: .35),
          GHColors.gold.withValues(alpha: .08),
          GHColors.gold.withValues(alpha: 0),
        ], const [0, .6, 1]),
    );
    // dotted branches
    final bp = Paint()
      ..strokeWidth = .6
      ..color = GHColors.ivory.withValues(alpha: .22);
    for (final br in _branches) {
      _dashed(canvas, br[0], br[1], bp);
      canvas.drawCircle(br[1], 1.1, Paint()..color = GHColors.ivory.withValues(alpha: .6));
    }
    // main path (draw-on)
    final lp = Paint()
      ..strokeWidth = big ? 1.6 : 1.1
      ..strokeCap = StrokeCap.round
      ..shader = ui.Gradient.linear(_a, _b, [GHColors.gold, GHColors.violet]);
    final segs = _path.length - 1;
    for (var i = 0; i < segs; i++) {
      final t = ((progress * (segs + 1)) - i).clamp(0.0, 1.0);
      if (t <= 0) continue;
      canvas.drawLine(_path[i], Offset.lerp(_path[i], _path[i + 1], t)!, lp);
    }
    for (final p in _path.sublist(1, _path.length - 1)) {
      _star(canvas, p, 1.6, const Color(0xFFE8DCC4), glow: false);
    }
    final r = big ? 6.6 : 5.2;
    _star(canvas, _a, r, GHColors.gold);
    _star(canvas, _b, r, GHColors.violet);
    if (aName != null) {
      _label(canvas, aName!, _a + const Offset(0, 30), GHColors.gold, big);
    }
    if (bName != null) {
      _label(canvas, bName!, _b + const Offset(0, -30), GHColors.violetText, big);
    }
    canvas.restore();
  }

  void _star(Canvas c, Offset o, double r, Color color, {bool glow = true}) {
    if (glow) {
      c.drawCircle(
        o,
        r * 4.5,
        Paint()
          ..shader = ui.Gradient.radial(o, r * 4.5, [
            color.withValues(alpha: .55),
            color.withValues(alpha: 0),
          ]),
      );
    }
    final length = r * 2.6, w = r * .42;
    final path = Path()
      ..moveTo(o.dx, o.dy - length)
      ..lineTo(o.dx + w, o.dy - w)
      ..lineTo(o.dx + length, o.dy)
      ..lineTo(o.dx + w, o.dy + w)
      ..lineTo(o.dx, o.dy + length)
      ..lineTo(o.dx - w, o.dy + w)
      ..lineTo(o.dx - length, o.dy)
      ..lineTo(o.dx - w, o.dy - w)
      ..close();
    c.drawPath(path, Paint()..color = color.withValues(alpha: .9));
    c.drawCircle(o, r * .62, Paint()..color = const Color(0xFFFFF8EA));
  }

  void _dashed(Canvas c, Offset a, Offset b, Paint p) {
    final len = (b - a).distance;
    final dir = (b - a) / len;
    for (double d = 0; d < len; d += 4.5) {
      c.drawLine(a + dir * d, a + dir * min(d + 1.5, len), p);
    }
  }

  void _label(Canvas c, String s, Offset at, Color color, bool badge) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: badge ? 11 : 12.5,
          fontWeight: FontWeight.w700,
          color: badge ? color : GHColors.ivory,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    if (badge) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: at, width: tp.width + 22, height: 19),
        const Radius.circular(9.5),
      );
      c.drawRRect(rect, Paint()..color = const Color(0xD910172D));
      c.drawRRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .7
          ..color = color.withValues(alpha: .75),
      );
    }
    tp.paint(c, at - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_StarMapPainter o) =>
      o.progress != progress ||
      o.ringTurn != ringTurn ||
      o.aName != aName ||
      o.bName != bName;
}
