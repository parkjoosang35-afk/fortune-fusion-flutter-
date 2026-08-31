// ═══════════════════════════════════════════════════════════════
// FILE: face_silhouette.dart
// PURPOSE: 얼굴 실루엣 가이드 (촬영 뷰파인더 안, 결과 맵 안)
// ═══════════════════════════════════════════════════════════════

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/sintong_colors.dart';

class FaceSilhouette extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;
  final bool showLandmarks;  // 오관 랜드마크 점 표시

  const FaceSilhouette({
    super.key,
    this.size = 160,
    this.color = SintongColors.sigil,
    this.opacity = 0.85,
    this.showLandmarks = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 1.28,
      child: CustomPaint(painter: _FacePainter(color: color, opacity: opacity, showLandmarks: showLandmarks)),
    );
  }
}

class _FacePainter extends CustomPainter {
  final Color color;
  final double opacity;
  final bool showLandmarks;
  _FacePainter({required this.color, required this.opacity, required this.showLandmarks});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cx = w / 2, cy = h / 2;

    final dashed = Paint()
      ..color = color.withValues(alpha: opacity)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    // 달걀형 얼굴 (대시 오프셋으로 dashed 표현)
    _drawDashedEllipse(canvas, Offset(cx, cy), w * 0.35, h * 0.375, dashed, 4, 3);

    // 삼정 가이드선 (상/중/하)
    final subtle = Paint()
      ..color = color.withValues(alpha: opacity * 0.35)
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(w * 0.19, h * 0.32), Offset(w * 0.81, h * 0.32), subtle);
    canvas.drawLine(Offset(w * 0.17, h * 0.61), Offset(w * 0.83, h * 0.61), subtle);
    canvas.drawLine(Offset(cx, h * 0.16), Offset(cx, h * 0.87), subtle..color = color.withValues(alpha: opacity * 0.25));

    // 랜드마크 (눈썹/눈/코/입/귀)
    final feature = Paint()
      ..color = color.withValues(alpha: opacity * 0.75)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // 눈썹
    final leftBrow = Path()..moveTo(w * 0.31, h * 0.36)..quadraticBezierTo(w * 0.37, h * 0.33, w * 0.44, h * 0.36);
    final rightBrow = Path()..moveTo(w * 0.56, h * 0.36)..quadraticBezierTo(w * 0.63, h * 0.33, w * 0.69, h * 0.36);
    canvas.drawPath(leftBrow, feature);
    canvas.drawPath(rightBrow, feature);

    // 눈
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.37, h * 0.42), width: 18, height: 8), feature);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.63, h * 0.42), width: 18, height: 8), feature);
    canvas.drawCircle(Offset(w * 0.37, h * 0.42), 1.5, Paint()..color = color.withValues(alpha: opacity * 0.7));
    canvas.drawCircle(Offset(w * 0.63, h * 0.42), 1.5, Paint()..color = color.withValues(alpha: opacity * 0.7));

    // 코
    final nose = Path()
      ..moveTo(w * 0.49, h * 0.46)
      ..quadraticBezierTo(w * 0.47, h * 0.54, w * 0.455, h * 0.60)
      ..quadraticBezierTo(cx, h * 0.615, w * 0.545, h * 0.60)
      ..quadraticBezierTo(w * 0.53, h * 0.54, w * 0.51, h * 0.46);
    canvas.drawPath(nose, feature..color = color.withValues(alpha: opacity * 0.5));

    // 입
    final mouth = Path()
      ..moveTo(w * 0.41, h * 0.71)
      ..quadraticBezierTo(cx, h * 0.74, w * 0.59, h * 0.71);
    canvas.drawPath(mouth, feature..color = color.withValues(alpha: opacity * 0.7));

    // 랜드마크 마커
    if (showLandmarks) {
      final marker = Paint()..color = color.withValues(alpha: opacity)..strokeWidth = 0.6..style = PaintingStyle.stroke;
      final fill = Paint()..color = color.withValues(alpha: opacity);
      final points = [
        Offset(w * 0.37, h * 0.36),  // 왼 눈썹
        Offset(w * 0.63, h * 0.36),  // 오른 눈썹
        Offset(w * 0.37, h * 0.42),  // 왼 눈
        Offset(w * 0.63, h * 0.42),  // 오른 눈
        Offset(cx, h * 0.54),        // 코
        Offset(cx, h * 0.71),        // 입
        Offset(w * 0.15, h * 0.53),  // 왼 귀
        Offset(w * 0.85, h * 0.53),  // 오른 귀
      ];
      for (final p in points) {
        canvas.drawCircle(p, 2.5, marker);
        canvas.drawCircle(p, 0.8, fill);
      }
    }
  }

  void _drawDashedEllipse(Canvas canvas, Offset center, double rx, double ry, Paint paint, double dash, double gap) {
    final path = Path()..addOval(Rect.fromCenter(center: center, width: rx * 2, height: ry * 2));
    _drawDashedPath(canvas, path, paint, dash, gap);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint, double dash, double gap) {
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final len = math.min(dash, metric.length - distance);
        final extract = metric.extractPath(distance, distance + len);
        canvas.drawPath(extract, paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FacePainter old) => false;
}
