// ═══════════════════════════════════════════════════════════════
// FILE: palm_silhouette.dart
// PURPOSE: 손바닥 실루엣 가이드 (촬영 뷰파인더, 결과 맵 안)
// ═══════════════════════════════════════════════════════════════

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/sintong_colors.dart';

class PalmSilhouette extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;
  final bool showLines;

  const PalmSilhouette({
    super.key,
    this.size = 160,
    this.color = SintongColors.sigil,
    this.opacity = 0.85,
    this.showLines = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size, height: size * 1.28,
      child: CustomPaint(painter: _PalmPainter(color: color, opacity: opacity, showLines: showLines)),
    );
  }
}

class _PalmPainter extends CustomPainter {
  final Color color;
  final double opacity;
  final bool showLines;
  _PalmPainter({required this.color, required this.opacity, required this.showLines});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // 정규화 좌표 (0..1) → 픽셀
    Offset p(double x, double y) => Offset(x * w / 220, y * h / 280);

    // 손바닥 + 5손가락 + 손목 윤곽 (svg path 이식)
    //
    // [손가락 4개 버그 수정] 기존에는 이 왼쪽 옆선 구간이 무지구(엄지
    // 두덩이) 융기만 완만한 곡선으로 표현하고, 끝이 둥글게 닫힌 독립된
    // "엄지손가락" 모양이 없어 사용자가 보기에 손가락이 4개(검지~새끼)로만
    // 보이는 버그였다. 검지 기준선 아래쪽에서 옆으로 비스듬히 뻗어나가는
    // 짧은 엄지손가락 lobe를 추가해 실제 손처럼 5손가락이 되도록 한다.
    final palmPath = Path()
      ..moveTo(60 * w / 220, 260 * h / 280)
      ..lineTo(58 * w / 220, 208 * h / 280)
      // 엄지손가락 바깥쪽(손목 쪽) 옆선 — 옆으로 뻗어나가기 시작.
      ..quadraticBezierTo(34 * w / 220, 206 * h / 280, 18 * w / 220, 188 * h / 280)
      // 엄지손가락 끝 라운딩(바깥쪽 절반).
      ..quadraticBezierTo(5 * w / 220, 172 * h / 280, 10 * w / 220, 152 * h / 280)
      // 엄지손가락 끝 라운딩(안쪽 절반) — 손바닥 쪽으로 돌아옴.
      ..quadraticBezierTo(14 * w / 220, 133 * h / 280, 30 * w / 220, 132 * h / 280)
      // 엄지손가락 안쪽(검지 쪽) 옆선 — 손가락 사이 물갈퀴(web) 형성.
      ..quadraticBezierTo(42 * w / 220, 131 * h / 280, 40 * w / 220, 148 * h / 280)
      // 물갈퀴에서 검지(첫 번째 손가락) 밑동까지 손바닥 옆선을 따라 위로.
      ..quadraticBezierTo(38 * w / 220, 115 * h / 280, 48 * w / 220, 55 * h / 280)
      ..quadraticBezierTo(48 * w / 220, 42 * h / 280, 60 * w / 220, 42 * h / 280)
      ..quadraticBezierTo(72 * w / 220, 42 * h / 280, 72 * w / 220, 55 * h / 280)
      ..lineTo(72 * w / 220, 100 * h / 280)
      ..lineTo(82 * w / 220, 98 * h / 280)
      ..lineTo(82 * w / 220, 40 * h / 280)
      ..quadraticBezierTo(82 * w / 220, 26 * h / 280, 96 * w / 220, 26 * h / 280)
      ..quadraticBezierTo(110 * w / 220, 26 * h / 280, 110 * w / 220, 40 * h / 280)
      ..lineTo(110 * w / 220, 96 * h / 280)
      ..lineTo(122 * w / 220, 96 * h / 280)
      ..lineTo(122 * w / 220, 32 * h / 280)
      ..quadraticBezierTo(122 * w / 220, 18 * h / 280, 136 * w / 220, 18 * h / 280)
      ..quadraticBezierTo(150 * w / 220, 18 * h / 280, 150 * w / 220, 32 * h / 280)
      ..lineTo(150 * w / 220, 98 * h / 280)
      ..lineTo(162 * w / 220, 100 * h / 280)
      ..lineTo(162 * w / 220, 55 * h / 280)
      ..quadraticBezierTo(162 * w / 220, 42 * h / 280, 174 * w / 220, 42 * h / 280)
      ..quadraticBezierTo(186 * w / 220, 42 * h / 280, 186 * w / 220, 55 * h / 280)
      ..lineTo(184 * w / 220, 118 * h / 280)
      ..quadraticBezierTo(184 * w / 220, 148 * h / 280, 176 * w / 220, 172 * h / 280)
      ..quadraticBezierTo(168 * w / 220, 200 * h / 280, 160 * w / 220, 260 * h / 280)
      ..close();

    final dashed = Paint()
      ..color = color.withValues(alpha: opacity)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    _drawDashedPath(canvas, palmPath, dashed, 4, 3);

    if (showLines) {
      final line = Paint()
        ..color = color.withValues(alpha: opacity * 0.65)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;

      // 생명선
      final lifeLine = Path()
        ..moveTo(78 * w / 220, 90 * h / 280)
        ..quadraticBezierTo(60 * w / 220, 130 * h / 280, 78 * w / 220, 200 * h / 280)
        ..quadraticBezierTo(90 * w / 220, 220 * h / 280, 100 * w / 220, 240 * h / 280);
      canvas.drawPath(lifeLine, line);

      // 두뇌선
      final brainLine = Path()
        ..moveTo(78 * w / 220, 118 * h / 280)
        ..quadraticBezierTo(110 * w / 220, 138 * h / 280, 155 * w / 220, 145 * h / 280);
      canvas.drawPath(brainLine, line);

      // 감정선
      final heartLine = Path()
        ..moveTo(68 * w / 220, 100 * h / 280)
        ..quadraticBezierTo(110 * w / 220, 92 * h / 280, 168 * w / 220, 108 * h / 280);
      canvas.drawPath(heartLine, line);

      // 운명선
      final destinyLine = Path()
        ..moveTo(110 * w / 220, 250 * h / 280)
        ..quadraticBezierTo(116 * w / 220, 200 * h / 280, 122 * w / 220, 130 * h / 280)
        ..quadraticBezierTo(124 * w / 220, 110 * h / 280, 128 * w / 220, 96 * h / 280);
      canvas.drawPath(destinyLine, line..color = color.withValues(alpha: opacity * 0.55));

      // 8구 마커
      final marker = Paint()..color = color.withValues(alpha: opacity * 0.7)..strokeWidth = 0.6..style = PaintingStyle.stroke;
      final fill = Paint()..color = color.withValues(alpha: opacity);
      final mounts = [
        [70,130], [90,105], [116,100], [142,105],
        [168,118], [156,165], [110,190], [90,205],
      ];
      for (final m in mounts) {
        canvas.drawCircle(p(m[0].toDouble(), m[1].toDouble()), 2.5, marker);
        canvas.drawCircle(p(m[0].toDouble(), m[1].toDouble()), 0.8, fill);
      }
    }
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint, double dash, double gap) {
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final len = math.min(dash, metric.length - distance);
        canvas.drawPath(metric.extractPath(distance, distance + len), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PalmPainter old) => false;
}
