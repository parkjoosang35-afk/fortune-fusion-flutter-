/// [BirthdayPickerModal 포팅 — 3/4: Sigil(마법진) 장식]
///
/// 원본: `handoff-extract/sigils.jsx`의 `Sigil({size,color,opacity})` SVG를
/// Flutter `CustomPainter`로 재현. 외곽 링 + 36개 틱마크 + 12개 룬 문자
/// + 육각별 + 중앙 별 구조를 그대로 옮긴다. viewBox가 -100~100(폭 200)
/// 이므로 draw 시 200 기준으로 스케일한다.
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';

class BirthdaySigil extends StatelessWidget {
  const BirthdaySigil({
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

  // 원본 SVG viewBox="-100 -100 200 200" → 반지름 값들은 그 스케일 기준.
  static const List<String> _runes = [
    '✧', '✦', '☾', '❋', '◈', '✵', '❈', '✺', '✶', '☆', '◇', '⟡',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 200.0;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);

    // glow (radial gradient) — outer ~95
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: 0.15),
          color.withValues(alpha: 0),
        ],
      ).createShader(const Rect.fromLTWH(-95, -95, 190, 190));
    canvas.drawCircle(Offset.zero, 95, glowPaint);

    // outer rings
    _strokeCircle(canvas, 90, color.withValues(alpha: opacity), 0.6);
    _strokeCircle(canvas, 86, color.withValues(alpha: opacity * 0.5), 0.4);

    // tick marks (36)
    final tickPaint = Paint()
      ..color = color.withValues(alpha: opacity * 0.8)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < 36; i++) {
      final a = (i / 36) * math.pi * 2;
      final x1 = math.cos(a) * 86, y1 = math.sin(a) * 86;
      final x2 = math.cos(a) * 90, y2 = math.sin(a) * 90;
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), tickPaint);
    }

    // runes (12)
    for (var i = 0; i < 12; i++) {
      final a = (i / 12) * math.pi * 2 - math.pi / 2;
      const r = 78.0;
      final x = math.cos(a) * r, y = math.sin(a) * r;
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
    _strokeCircle(canvas, 60, color.withValues(alpha: opacity * 0.6), 0.5);

    // hexagram
    final hexPaint = Paint()
      ..color = color.withValues(alpha: opacity * 0.8)
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;
    final hexPath = Path()
      ..moveTo(0, -52)
      ..lineTo(45, -26)
      ..lineTo(45, 26)
      ..lineTo(0, 52)
      ..lineTo(-45, 26)
      ..lineTo(-45, -26)
      ..close();
    canvas.drawPath(hexPath, hexPaint);

    final tri1Paint = Paint()
      ..color = color.withValues(alpha: opacity * 0.5)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    final tri1 = Path()
      ..moveTo(0, 52)
      ..lineTo(-45, -26)
      ..lineTo(45, -26)
      ..close();
    canvas.drawPath(tri1, tri1Paint);

    final tri2 = Path()
      ..moveTo(0, -52)
      ..lineTo(-45, 26)
      ..lineTo(45, 26)
      ..close();
    canvas.drawPath(tri2, tri1Paint);

    // inner circles
    _strokeCircle(canvas, 26, color.withValues(alpha: opacity), 0.6);
    _strokeCircle(canvas, 22, color.withValues(alpha: opacity * 0.5), 0.4);

    // center star (8-point-ish)
    final starPaint = Paint()
      ..color = color.withValues(alpha: opacity * 0.6)
      ..style = PaintingStyle.fill;
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

  void _strokeCircle(Canvas canvas, double r, Color c, double strokeWidth) {
    final paint = Paint()
      ..color = c
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset.zero, r, paint);
  }

  @override
  bool shouldRepaint(covariant _SigilPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.opacity != opacity;
  }
}
