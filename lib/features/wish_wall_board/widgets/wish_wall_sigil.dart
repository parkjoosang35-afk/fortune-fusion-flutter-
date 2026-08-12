import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 마법진(Sigil) — 옛 "신통방통 소원방"(wish_room) 모듈의 대표 배경 장식.
///
/// [디자인 히스토리] 옛 소원방 홈/작성/상세/피드 4개 화면은 모두 화면 상단에
/// 이 회전 마법진(룬 문자 12개 + 육각형 + 눈금 36개)을 은은하게 깔아 "화면이
/// 살짝 신비롭게 움직이는" 느낌을 줬다. 화폐(조각) 시스템과는 무관한 순수
/// 시각 장식이라 그대로 이식한다.
class WishWallSigil extends StatelessWidget {
  const WishWallSigil({
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
      child: CustomPaint(
        painter: _SigilPainter(color: color, opacity: opacity),
      ),
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
    final scale = size.width / 200.0;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale, scale);

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0)],
      ).createShader(const Rect.fromLTWH(-95, -95, 190, 190));
    canvas.drawCircle(Offset.zero, 95, glowPaint);

    _drawRing(canvas, 90, opacity, 0.6);
    _drawRing(canvas, 86, opacity * 0.5, 0.4);

    final tickPaint = Paint()
      ..color = color.withValues(alpha: opacity * 0.8)
      ..strokeWidth = 0.5;
    for (int i = 0; i < 36; i++) {
      final a = (i / 36) * math.pi * 2;
      final p1 = Offset(math.cos(a) * 86, math.sin(a) * 86);
      final p2 = Offset(math.cos(a) * 90, math.sin(a) * 90);
      canvas.drawLine(p1, p2, tickPaint);
    }

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

    _drawRing(canvas, 60, opacity * 0.6, 0.5);

    final hexPaint1 = Paint()
      ..color = color.withValues(alpha: opacity * 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;
    _drawPolygon(canvas, const [
      Offset(0, -52),
      Offset(45, -26),
      Offset(45, 26),
      Offset(0, 52),
      Offset(-45, 26),
      Offset(-45, -26),
    ], hexPaint1);

    final hexPaint2 = Paint()
      ..color = color.withValues(alpha: opacity * 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    _drawPolygon(canvas, const [
      Offset(0, 52),
      Offset(-45, -26),
      Offset(45, -26),
    ], hexPaint2);
    _drawPolygon(canvas, const [
      Offset(0, -52),
      Offset(-45, 26),
      Offset(45, 26),
    ], hexPaint2);

    _drawRing(canvas, 26, opacity, 0.6);
    _drawRing(canvas, 22, opacity * 0.5, 0.4);

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
