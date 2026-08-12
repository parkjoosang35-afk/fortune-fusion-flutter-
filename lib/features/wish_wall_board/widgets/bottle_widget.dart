import 'package:flutter/material.dart';
import '../domain/wish_wall_models.dart';

/// 소원병(유리병) 시각화 위젯.
///
/// [handoff.zip] design/bottle.jsx의 SVG 병 컴포넌트를 Flutter [CustomPainter]로
/// 이식했다. viewBox 100x155 좌표계를 그대로 사용해 path 좌표를 유지한다.
/// - [glow] 0.0~1.0: 응원(support) 비례 내부 불빛 강도
/// - [sealed] true면 병 속에 접힌 종이(소원지) 실루엣을 그림
/// - [tilt] 도(degree) 단위 기울임(내 소원병 화면의 나만보기 항목에서 사용)
class BottleWidget extends StatelessWidget {
  const BottleWidget({
    super.key,
    required this.category,
    this.size = 120,
    this.glow = 0,
    this.tilt = 0,
    this.sealed = true,
    this.label,
  });

  final WishCategory category;
  final double size;
  final double glow;
  final double tilt;
  final bool sealed;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final w = size;
    final h = size * 1.55;
    return SizedBox(
      width: w,
      height: h,
      child: Transform.rotate(
        angle: tilt * 3.1415926535 / 180,
        alignment: Alignment.bottomCenter,
        child: CustomPaint(
          size: Size(w, h),
          painter: _BottlePainter(
            category: category,
            glow: glow.clamp(0.0, 1.0),
            sealed: sealed,
            label: label,
          ),
        ),
      ),
    );
  }
}

class _BottlePainter extends CustomPainter {
  _BottlePainter({
    required this.category,
    required this.glow,
    required this.sealed,
    this.label,
  });

  final WishCategory category;
  final double glow;
  final bool sealed;
  final String? label;

  // viewBox 0 0 100 155 -> scale factor
  double _sx(Size size) => size.width / 100;
  double _sy(Size size) => size.height / 155;

  Offset _p(Size size, double x, double y) => Offset(x * _sx(size), y * _sy(size));

  @override
  void paint(Canvas canvas, Size size) {
    final sx = _sx(size);
    final sy = _sy(size);
    final glass = category.glassColor;
    final cork = category.corkColor;
    final light = category.lightColor;

    // Bottle body path (long neck + rounded shoulder), viewBox coords.
    final path = Path();
    path.moveTo(40 * sx, 5 * sy);
    path.lineTo(60 * sx, 5 * sy);
    path.lineTo(60 * sx, 30 * sy);
    path.cubicTo(60 * sx, 34 * sy, 65 * sx, 36 * sy, 68 * sx, 40 * sy);
    path.cubicTo(72 * sx, 44 * sy, 78 * sx, 50 * sy, 80 * sx, 62 * sy);
    path.lineTo(80 * sx, 138 * sy);
    path.cubicTo(80 * sx, 145 * sy, 75 * sx, 150 * sy, 68 * sx, 150 * sy);
    path.lineTo(32 * sx, 150 * sy);
    path.cubicTo(25 * sx, 150 * sy, 20 * sx, 145 * sy, 20 * sx, 138 * sy);
    path.lineTo(20 * sx, 62 * sy);
    path.cubicTo(22 * sx, 50 * sy, 28 * sx, 44 * sy, 32 * sx, 40 * sy);
    path.cubicTo(35 * sx, 36 * sy, 40 * sx, 34 * sy, 40 * sx, 30 * sy);
    path.close();

    // Drop shadow.
    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.10), 6, false);

    // Glass body fill — vertical gradient tint.
    final glassPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          glass.withValues(alpha: 0.4),
          glass.withValues(alpha: 0.85),
          glass.withValues(alpha: 0.65),
          glass.withValues(alpha: 0.85),
          glass.withValues(alpha: 0.4),
        ],
        stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(path, glassPaint);

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 * sx
      ..color = cork.withValues(alpha: 0.22);
    canvas.drawPath(path, strokePaint);

    // Inner light halo (below cork) — only if glow > 0.
    if (glow > 0) {
      final haloCenter = _p(size, 50, 100);
      final haloPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            light.withValues(alpha: (glow * 0.85).clamp(0.0, 1.0)),
            light.withValues(alpha: (glow * 0.30).clamp(0.0, 1.0)),
            light.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(
          Rect.fromCenter(
            center: haloCenter,
            width: 60 * sx,
            height: 90 * sy,
          ),
        );
      canvas.save();
      canvas.clipPath(path);
      canvas.drawOval(
        Rect.fromCenter(center: haloCenter, width: 60 * sx, height: 90 * sy),
        haloPaint,
      );
      canvas.restore();
    }

    // Wish content silhouette — folded paper inside.
    if (sealed) {
      final paperPath = Path()
        ..moveTo(35 * sx, 90 * sy)
        ..lineTo(65 * sx, 90 * sy)
        ..lineTo(63 * sx, 130 * sy)
        ..lineTo(37 * sx, 130 * sy)
        ..close();
      canvas.save();
      canvas.clipPath(path);
      final paperPaint = Paint()
        ..color = const Color(0xFFFAFAFA).withValues(alpha: 0.55);
      canvas.drawPath(paperPath, paperPaint);
      final paperStroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6 * sx
        ..color = cork.withValues(alpha: 0.3 * 0.55);
      canvas.drawPath(paperPath, paperStroke);
      final linePaint = Paint()
        ..strokeWidth = 0.6 * sy
        ..color = cork.withValues(alpha: 0.35 * 0.55);
      canvas.drawLine(_p(size, 40, 100), _p(size, 60, 100), linePaint);
      canvas.drawLine(_p(size, 40, 108), _p(size, 58, 108), linePaint);
      canvas.drawLine(_p(size, 40, 116), _p(size, 55, 116), linePaint);
      canvas.restore();
    }

    // Tiny flame inside (only if lit).
    if (glow > 0.3) {
      canvas.save();
      canvas.clipPath(path);
      final flamePath = Path()
        ..moveTo(50 * sx, 70 * sy)
        ..cubicTo(53 * sx, 74 * sy, 54 * sx, 78 * sy, 52.5 * sx, 82 * sy)
        ..cubicTo(51.5 * sx, 84 * sy, 50.5 * sx, 85 * sy, 50 * sx, 85 * sy)
        ..cubicTo(49.5 * sx, 85 * sy, 48.5 * sx, 84 * sy, 47.5 * sx, 82 * sy)
        ..cubicTo(46 * sx, 78 * sy, 47 * sx, 74 * sy, 50 * sx, 70 * sy)
        ..close();
      canvas.drawPath(flamePath, Paint()..color = const Color(0xFFFEF3C7));
      canvas.drawOval(
        Rect.fromCenter(
          center: _p(size, 50, 82),
          width: 3 * sx,
          height: 4 * sy,
        ),
        Paint()..color = light.withValues(alpha: 0.75),
      );
      canvas.restore();
    }

    // Cork (lid).
    final corkRect = Rect.fromLTWH(38 * sx, 0, 24 * sx, 10 * sy);
    final corkRRect = RRect.fromRectAndRadius(corkRect, Radius.circular(1.5 * sx));
    canvas.drawRRect(corkRRect, Paint()..color = cork.withValues(alpha: 0.85));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(38 * sx, 0, 24 * sx, 2 * sy),
        Radius.circular(1 * sx),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.15),
    );

    // Highlight streak (glass shine).
    final shinePath = Path()
      ..moveTo(28 * sx, 55 * sy)
      ..lineTo(28 * sx, 130 * sy)
      ..cubicTo(28 * sx, 133 * sy, 30 * sx, 135 * sy, 32 * sx, 135 * sy);
    final shinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * sx
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: [Colors.white.withValues(alpha: 0.7), Colors.white.withValues(alpha: 0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(shinePath, shinePaint);
    canvas.drawOval(
      Rect.fromCenter(center: _p(size, 28, 60), width: 4 * sx, height: 16 * sy),
      Paint()..color = Colors.white.withValues(alpha: 0.5),
    );

    // Bottom shadow.
    canvas.drawOval(
      Rect.fromCenter(center: _p(size, 50, 150), width: 40 * sx, height: 3 * sy),
      Paint()..color = cork.withValues(alpha: 0.15),
    );

    // Label band with category text.
    if (label != null) {
      final rect = Rect.fromLTWH(24 * sx, 102 * sy, 52 * sx, 18 * sy);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(2 * sx)),
        Paint()..color = Colors.white.withValues(alpha: 0.9),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(2 * sx)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5 * sx
          ..color = cork.withValues(alpha: 0.25),
      );
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 8 * sx,
            fontWeight: FontWeight.w700,
            color: cork,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(
          rect.center.dx - textPainter.width / 2,
          rect.center.dy - textPainter.height / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BottlePainter oldDelegate) {
    return oldDelegate.category != category ||
        oldDelegate.glow != glow ||
        oldDelegate.sealed != sealed ||
        oldDelegate.label != label;
  }
}

/// 병 목에 매달린 리본(매듭) — 받은 복주머니 수를 시각화 (최대 3개).
class BottleRibbons extends StatelessWidget {
  const BottleRibbons({super.key, required this.count, required this.color});
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final n = count.clamp(0, 3);
    return Positioned(
      top: 12,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: List.generate(n, (i) {
          return Transform.rotate(
            angle: (i - 1) * 8 * 3.1415926535 / 180,
            child: Container(
              width: 4,
              height: 14,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(1),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [color, color.withValues(alpha: 0.53)],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// 병 옆에 매달린 잎사귀 — 받은 기도 수를 시각화 (최대 5개).
class BottleLeaves extends StatelessWidget {
  const BottleLeaves({super.key, required this.count, this.rightSide = true});
  final int count;
  final bool rightSide;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final n = count.clamp(0, 5);
    return Positioned(
      top: 26,
      left: rightSide ? null : -8,
      right: rightSide ? -8 : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(n, (i) {
          final angle = (rightSide ? 20 - i * 4 : -20 + i * 4) * 3.1415926535 / 180;
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Transform.rotate(
              angle: angle,
              child: SizedBox(
                width: 14,
                height: 10,
                child: CustomPaint(painter: _LeafPainter()),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _LeafPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(1, 5)
      ..cubicTo(4, 1, 10, 1, 13, 5)
      ..cubicTo(10, 9, 4, 9, 1, 5)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFF10B981).withValues(alpha: 0.75));
    canvas.drawLine(
      const Offset(1, 5),
      const Offset(13, 5),
      Paint()
        ..color = const Color(0xFF065F46).withValues(alpha: 0.4)
        ..strokeWidth = 0.5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
