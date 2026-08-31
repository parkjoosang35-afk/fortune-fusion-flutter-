// ═══════════════════════════════════════════════════════════════
// FILE: face_sigil.dart
// PURPOSE: 관상용 마법진 (십이궁 + 오관 하자 배치)
// USED IN: 홈 카드 배경, 촬영 뷰파인더 오버레이, 로딩 화면 중앙, 결과 맵 배경
//
// CustomPainter로 SVG 없이 100% Flutter Canvas 렌더 — 성능/일관성 유리
// ═══════════════════════════════════════════════════════════════

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/sintong_colors.dart';
import '../theme/sintong_typography.dart';

class FaceSigil extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;

  const FaceSigil({
    super.key,
    this.size = 260,
    this.color = SintongColors.stampGuan,
    this.opacity = 0.55,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _FaceSigilPainter(color: color, opacity: opacity)),
    );
  }
}

class _FaceSigilPainter extends CustomPainter {
  final Color color;
  final double opacity;
  _FaceSigilPainter({required this.color, required this.opacity});

  static const List<String> _palaces = [
    '命','兄','夫','子','財','疾','遷','奴','官','田','福','父',
  ];
  static const List<Map<String, dynamic>> _wugan = [
    {'x': 0.0,  'y': -0.42, 'ch': '眉'},
    {'x': 0.3,  'y': -0.18, 'ch': '目'},
    {'x': 0.42, 'y': 0.0,   'ch': '耳'},
    {'x': 0.3,  'y': 0.18,  'ch': '鼻'},
    {'x': 0.0,  'y': 0.42,  'ch': '口'},
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;

    // 배경 글로우
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: opacity * 0.35),
          color.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r * 0.95, glowPaint);

    // 외곽 이중원
    canvas.drawCircle(center, r * 0.92, paint);
    canvas.drawCircle(center, r * 0.88, paint..color = color.withValues(alpha: opacity * 0.6));

    // 12궁 눈금
    paint..color = color.withValues(alpha: opacity)..strokeWidth = 0.5;
    for (int i = 0; i < 12; i++) {
      final a = (i / 12) * math.pi * 2 - math.pi / 2;
      canvas.drawLine(
        center + Offset(math.cos(a) * r * 0.88, math.sin(a) * r * 0.88),
        center + Offset(math.cos(a) * r * 0.92, math.sin(a) * r * 0.92),
        paint,
      );
    }

    // 12궁 이름
    for (int i = 0; i < 12; i++) {
      final a = (i / 12) * math.pi * 2 - math.pi / 2;
      final pos = center + Offset(math.cos(a) * r * 0.80, math.sin(a) * r * 0.80);
      _drawText(canvas, _palaces[i], pos, r * 0.055);
    }

    // 내부 팔각형
    paint..color = color.withValues(alpha: opacity * 0.8)..strokeWidth = 0.5;
    final poly = Path();
    for (int i = 0; i < 8; i++) {
      final a = (i / 8) * math.pi * 2 - math.pi / 2;
      final p = center + Offset(math.cos(a) * r * 0.55, math.sin(a) * r * 0.55);
      if (i == 0) poly.moveTo(p.dx, p.dy);
      else poly.lineTo(p.dx, p.dy);
    }
    poly.close();
    canvas.drawPath(poly, paint);

    // 오관 하자
    for (final w in _wugan) {
      final pos = center + Offset(w['x'] * r, w['y'] * r);
      _drawText(canvas, w['ch'], pos, r * 0.06);
    }

    // 중앙 원 + 별
    canvas.drawCircle(center, r * 0.16, paint..color = color.withValues(alpha: opacity));
    final starPath = Path()
      ..moveTo(center.dx, center.dy - r * 0.1)
      ..lineTo(center.dx + r * 0.025, center.dy - r * 0.025)
      ..lineTo(center.dx + r * 0.1, center.dy)
      ..lineTo(center.dx + r * 0.025, center.dy + r * 0.025)
      ..lineTo(center.dx, center.dy + r * 0.1)
      ..lineTo(center.dx - r * 0.025, center.dy + r * 0.025)
      ..lineTo(center.dx - r * 0.1, center.dy)
      ..lineTo(center.dx - r * 0.025, center.dy - r * 0.025)
      ..close();
    canvas.drawPath(starPath, Paint()..color = color.withValues(alpha: opacity * 0.7));
  }

  void _drawText(Canvas canvas, String text, Offset pos, double fontSize) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: SintongType.display,
          fontWeight: FontWeight.w900,
          fontSize: fontSize,
          color: color.withValues(alpha: opacity * 0.9),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _FaceSigilPainter old) =>
    old.color != color || old.opacity != opacity;
}
