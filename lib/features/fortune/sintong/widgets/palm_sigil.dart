// ═══════════════════════════════════════════════════════════════
// FILE: palm_sigil.dart
// PURPOSE: 손금용 마법진 (8구 + 4대선 하자)
// USED IN: 손금 촬영 뷰파인더, 손금 로딩 화면, 손금 결과 맵 배경
// ═══════════════════════════════════════════════════════════════

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/sintong_colors.dart';
import '../theme/sintong_typography.dart';

class PalmSigil extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;

  const PalmSigil({
    super.key,
    this.size = 260,
    this.color = SintongColors.stampGuan,
    this.opacity = 0.55,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size, height: size,
      child: CustomPaint(painter: _PalmSigilPainter(color: color, opacity: opacity)),
    );
  }
}

class _PalmSigilPainter extends CustomPainter {
  final Color color;
  final double opacity;
  _PalmSigilPainter({required this.color, required this.opacity});

  static const List<String> _mounts = ['金','木','土','太','水','火','月','地'];
  static const List<Map<String, dynamic>> _lines = [
    {'x': 0.0,  'y': -0.55, 'ch': '感'},
    {'x': 0.4,  'y': -0.2,  'ch': '智'},
    {'x': 0.4,  'y': 0.3,   'ch': '命'},
    {'x': 0.0,  'y': 0.55,  'ch': '運'},
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // 배경 글로우
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [color.withValues(alpha: opacity * 0.35), color.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r * 0.95, glowPaint);

    final paint = Paint()..color = color.withValues(alpha: opacity)..strokeWidth = 0.5..style = PaintingStyle.stroke;

    canvas.drawCircle(center, r * 0.92, paint);
    canvas.drawCircle(center, r * 0.88, paint..color = color.withValues(alpha: opacity * 0.6));

    // 8구 각도
    paint..color = color.withValues(alpha: opacity * 0.4)..strokeWidth = 0.4;
    for (int i = 0; i < 8; i++) {
      final a = (i / 8) * math.pi * 2 - math.pi / 2;
      canvas.drawLine(
        center + Offset(math.cos(a) * r * 0.3, math.sin(a) * r * 0.3),
        center + Offset(math.cos(a) * r * 0.88, math.sin(a) * r * 0.88),
        paint,
      );
    }

    // 8구 이름
    for (int i = 0; i < 8; i++) {
      final a = (i / 8) * math.pi * 2 - math.pi / 2;
      final pos = center + Offset(math.cos(a) * r * 0.80, math.sin(a) * r * 0.80);
      _drawText(canvas, _mounts[i], pos, r * 0.06, opacity * 0.9);
    }

    // 4대선 하자 (원 안에)
    for (final l in _lines) {
      final pos = center + Offset(l['x'] * r, l['y'] * r);
      final circlePaint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..strokeWidth = 0.5
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(pos, r * 0.08, circlePaint);
      _drawText(canvas, l['ch'], pos, r * 0.07, opacity);
    }

    // 중앙 掌 (손바닥)
    final centerPaint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, r * 0.14, centerPaint);
    _drawText(canvas, '掌', center, r * 0.12, opacity);
  }

  void _drawText(Canvas canvas, String text, Offset pos, double fontSize, double op) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: SintongType.display,
          fontWeight: FontWeight.w900,
          fontSize: fontSize,
          color: color.withValues(alpha: op),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _PalmSigilPainter old) =>
    old.color != color || old.opacity != opacity;
}
