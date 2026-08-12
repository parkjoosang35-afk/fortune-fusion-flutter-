import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 신통방통 소원방 · 판타지 SVG 모티프 → Flutter 위젯 변환
///
/// 출처: 디자인 핸드오프 `design_files/sigils.jsx` (6개 컴포넌트).
/// CustomPainter로 그리되, 원본 JSX의 좌표/투명도/구조를 최대한 그대로 유지한다.

/// ─────────────────────────────────────────────────────────
/// <Sigil> — 마법진 (회전 배경 장식)
/// viewBox -100..100, 36 tick marks + 12 rune glyphs + hexagram + center star
/// ─────────────────────────────────────────────────────────
class WishRoomSigil extends StatelessWidget {
  const WishRoomSigil({
    super.key,
    this.size = 300,
    required this.color,
    this.opacity = 0.5,
  });

  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _SigilPainter(color: color, opacity: opacity)),
    );
  }
}

class _SigilPainter extends CustomPainter {
  _SigilPainter({required this.color, required this.opacity});
  final Color color;
  final double opacity;

  static const _runes = [
    '✧', '✦', '☾', '❋', '◈', '✵', '❈', '✺', '✶', '☆', '◇', '⟡',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // viewBox is -100..100 (200x200) mapped to `size`.
    final scale = size.width / 200.0;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale, scale);

    // radial glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0)],
      ).createShader(const Rect.fromLTWH(-95, -95, 190, 190));
    canvas.drawCircle(Offset.zero, 95, glowPaint);

    // outer rings
    _drawRing(canvas, 90, opacity, 0.6);
    _drawRing(canvas, 86, opacity * 0.5, 0.4);

    // tick marks
    final tickPaint = Paint()
      ..color = color.withValues(alpha: opacity * 0.8)
      ..strokeWidth = 0.5;
    for (int i = 0; i < 36; i++) {
      final a = (i / 36) * math.pi * 2;
      final p1 = Offset(math.cos(a) * 86, math.sin(a) * 86);
      final p2 = Offset(math.cos(a) * 90, math.sin(a) * 90);
      canvas.drawLine(p1, p2, tickPaint);
    }

    // runes
    for (int i = 0; i < 12; i++) {
      final a = (i / 12) * math.pi * 2 - math.pi / 2;
      const r = 78.0;
      final x = math.cos(a) * r;
      final y = math.sin(a) * r;
      final tp = TextPainter(
        text: TextSpan(
          text: _runes[i],
          style: TextStyle(
            color: color.withValues(alpha: opacity),
            fontSize: 6,
            fontFamily: 'serif',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
    }

    // middle ring
    _drawRing(canvas, 60, opacity * 0.6, 0.5);

    // hexagram
    final hexPaint1 = Paint()
      ..color = color.withValues(alpha: opacity * 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;
    _drawPolygon(canvas, const [
      Offset(0, -52), Offset(45, -26), Offset(45, 26),
      Offset(0, 52), Offset(-45, 26), Offset(-45, -26),
    ], hexPaint1);

    final hexPaint2 = Paint()
      ..color = color.withValues(alpha: opacity * 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    _drawPolygon(canvas, const [
      Offset(0, 52), Offset(-45, -26), Offset(45, -26),
    ], hexPaint2);
    _drawPolygon(canvas, const [
      Offset(0, -52), Offset(-45, 26), Offset(45, 26),
    ], hexPaint2);

    // inner circle
    _drawRing(canvas, 26, opacity, 0.6);
    _drawRing(canvas, 22, opacity * 0.5, 0.4);

    // center star
    final starPaint = Paint()..color = color.withValues(alpha: opacity * 0.6);
    final starPath = Path()
      ..moveTo(0, -12)
      ..lineTo(3, -3)
      ..lineTo(12, -3)
      ..lineTo(5, 3)
      ..lineTo(8, 12)
      ..lineTo(0, 7)
      ..lineTo(-8, 12)
      ..lineTo(-5, 3)
      ..lineTo(-12, -3)
      ..lineTo(-3, -3)
      ..close();
    canvas.drawPath(starPath, starPaint);

    canvas.restore();
  }

  void _drawRing(Canvas canvas, double radius, double op, double strokeWidth) {
    final paint = Paint()
      ..color = color.withValues(alpha: op)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(Offset.zero, radius, paint);
  }

  void _drawPolygon(Canvas canvas, List<Offset> points, Paint paint) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SigilPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.opacity != opacity;
}

/// ─────────────────────────────────────────────────────────
/// <Candle> — 촛불 (몸체 그라디언트 + 불꽃 SVG)
/// ─────────────────────────────────────────────────────────
class WishRoomCandle extends StatelessWidget {
  const WishRoomCandle({
    super.key,
    this.size = 60,
    this.color = const Color(0xFFF5D97A),
    this.melted = 0,
    this.lit = true,
  });

  final double size;
  final Color color;
  final double melted;
  final bool lit;

  @override
  Widget build(BuildContext context) {
    final w = size;
    final h = size * 1.8;
    final bodyW = size * 0.55;
    final bodyH = size * 1.1 - melted * 0.4;

    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          if (lit)
            Positioned(
              top: 0,
              child: SizedBox(
                width: size * 0.5,
                height: size * 0.7,
                child: CustomPaint(painter: _FlamePainter(color: color)),
              ),
            ),
          Positioned(
            top: size * 0.68,
            child: Container(
              width: 1.5,
              height: 6,
              decoration: BoxDecoration(
                color: const Color(0xFF3A2515),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
          Positioned(
            top: size * 0.72,
            child: Container(
              width: bodyW,
              height: bodyH < 0 ? 0 : bodyH,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.15),
                    color,
                    color,
                    Colors.black.withValues(alpha: 0.2),
                  ],
                  stops: const [0.0, 0.3, 0.7, 1.0],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(bodyW * 0.15),
                  topRight: Radius.circular(bodyW * 0.15),
                  bottomLeft: const Radius.circular(4),
                  bottomRight: const Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 20,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlamePainter extends CustomPainter {
  _FlamePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 20.0;
    canvas.save();
    canvas.scale(scale, scale);
    final paint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, 0.4),
        radius: 0.5,
        colors: [
          const Color(0xFFFFF8DD),
          const Color(0xFFFFD47A),
          color.withValues(alpha: 0.3),
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(const Rect.fromLTWH(0, 0, 20, 30));
    final path = Path()
      ..moveTo(10, 2)
      ..cubicTo(14, 10, 16, 16, 14, 22)
      ..cubicTo(13, 26, 11, 28, 10, 28)
      ..cubicTo(9, 28, 7, 26, 6, 22)
      ..cubicTo(4, 16, 6, 10, 10, 2)
      ..close();
    canvas.drawPath(path, paint);
    final corePaint = Paint()..color = const Color(0xFF4A2B8A).withValues(alpha: 0.5);
    canvas.drawOval(Rect.fromCenter(center: const Offset(10, 22), width: 6, height: 8), corePaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FlamePainter oldDelegate) => oldDelegate.color != color;
}

/// ─────────────────────────────────────────────────────────
/// <Crystal> — 크리스탈 조각(사용처 적음, sigils.jsx 원본)
/// ─────────────────────────────────────────────────────────
class WishRoomCrystal extends StatelessWidget {
  const WishRoomCrystal({
    super.key,
    this.size = 40,
    this.color = const Color(0xFFA8D5E3),
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 1.5,
      child: CustomPaint(painter: _CrystalPainter(color: color)),
    );
  }
}

class _CrystalPainter extends CustomPainter {
  _CrystalPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 40.0;
    canvas.save();
    canvas.scale(scale, scale);
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.9),
          color.withValues(alpha: 0.85),
          color.withValues(alpha: 0.4),
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(const Rect.fromLTWH(0, 0, 40, 60));
    final strokePaint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    final path = Path()
      ..moveTo(20, 2)
      ..lineTo(32, 20)
      ..lineTo(28, 55)
      ..lineTo(12, 55)
      ..lineTo(8, 20)
      ..close();
    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..strokeWidth = 0.5;
    canvas.drawLine(const Offset(20, 2), const Offset(20, 55), linePaint);
    final linePaint2 = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 0.3;
    canvas.drawLine(const Offset(8, 20), const Offset(20, 55), linePaint2);
    canvas.drawLine(const Offset(32, 20), const Offset(20, 55), linePaint2);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CrystalPainter oldDelegate) => oldDelegate.color != color;
}

/// ─────────────────────────────────────────────────────────
/// <Dust> — 상승하는 먼지 입자(배경 앰비언스)
/// ─────────────────────────────────────────────────────────
class WishRoomDust extends StatefulWidget {
  const WishRoomDust({super.key, this.count = 8, this.color = const Color(0xFFF5D97A)});

  final int count;
  final Color color;

  @override
  State<WishRoomDust> createState() => _WishRoomDustState();
}

class _WishRoomDustState extends State<WishRoomDust> with TickerProviderStateMixin {
  late List<AnimationController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.count, (i) {
      final dur = 6 + (i % 4);
      return AnimationController(
        vsync: this,
        duration: Duration(milliseconds: (dur * 1000).round()),
      )..repeat();
    });
    // stagger start via delayed start emulation using different durations naturally.
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: List.generate(widget.count, (i) {
          final left = ((i * 13 + 7) % 100).toDouble();
          final particleSize = (2 + (i % 3)).toDouble();
          return AnimatedBuilder(
            animation: _controllers[i],
            builder: (context, _) {
              // emulate CSS keyframes dust-float: rise + fade in/out
              final t = _controllers[i].value;
              final delayFrac = (i * 0.7 % 8) / (6 + (i % 4));
              final adjT = (t + delayFrac) % 1.0;
              final riseHeight = 300.0; // approximate travel distance
              final opacity = adjT < 0.1
                  ? adjT / 0.1
                  : adjT > 0.8
                      ? (1 - adjT) / 0.2
                      : 1.0;
              return Positioned(
                left: 0,
                right: 0,
                bottom: -10 + adjT * riseHeight,
                child: Align(
                  alignment: Alignment(left / 50 - 1, 0),
                  child: Opacity(
                    opacity: opacity.clamp(0.0, 1.0),
                    child: Container(
                      width: particleSize,
                      height: particleSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [widget.color, widget.color.withValues(alpha: 0)],
                          stops: const [0.0, 0.6],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────
/// <Scroll> — 한지 두루마리 (소원 작성용 컨테이너)
/// ─────────────────────────────────────────────────────────
class WishRoomScroll extends StatelessWidget {
  const WishRoomScroll({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF3E5C3), Color(0xFFE8D5A3)],
        ),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(fontFamily: 'GowunBatangWish', color: Color(0xFF3A2515)),
        child: child,
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────
/// <Seal> — 인장/도장 (한자 1글자, 회전 -6도)
/// ─────────────────────────────────────────────────────────
class WishRoomSeal extends StatelessWidget {
  const WishRoomSeal({
    super.key,
    this.text = '願',
    this.color = const Color(0xFFC94A3B),
    this.size = 44,
  });

  final String text;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -6 * math.pi / 180,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.black.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.53), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'NotoSerifKRWish',
            fontWeight: FontWeight.w900,
            fontSize: size * 0.55,
            color: const Color(0xFFFFF9E8),
            shadows: [Shadow(color: Colors.black.withValues(alpha: 0.3), offset: const Offset(0, 1), blurRadius: 2)],
          ),
        ),
      ),
    );
  }
}
