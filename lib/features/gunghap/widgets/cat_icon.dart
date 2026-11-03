// ═══════════════════════════════════════════════════════════════
// FILE: cat_icon.dart
// [궁합지도 Star Map 디자인 적용] gh-ui.jsx `<CatIcon>` 포팅본 —
// 대분류 8종을 별자리(점+선) 스타일 아이콘으로 표현한다.
// 원본 viewBox 0 0 40 40 기준 좌표를 그대로 사용.
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import '../theme/gh_tokens.dart';

class CatIcon extends StatelessWidget {
  const CatIcon({super.key, required this.kind, this.size = 40, this.active = false});
  final String kind;
  final double size;
  final bool active;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      painter: _CatIconPainter(kind: kind, active: active),
    ),
  );
}

class _CatIconPainter extends CustomPainter {
  _CatIconPainter({required this.kind, required this.active});
  final String kind;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 40;
    canvas.save();
    canvas.scale(k);
    final lineColor = active ? GHColors.gold : GHColors.ivory.withValues(alpha: .55);
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = lineColor;
    const gold = GHColors.gold;
    const violet = GHColors.violet;

    void dot(double x, double y, [double r = 1.6, Color c = GHColors.ivory]) {
      canvas.drawCircle(Offset(x, y), r, Paint()..color = c);
    }

    void loop(List<Offset> pts) {
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final p in pts.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      path.close();
      canvas.drawPath(path, strokePaint);
    }

    void star(double x, double y, double r, Color color) {
      final o = Offset(x, y);
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
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: .9));
      canvas.drawCircle(o, r * .62, Paint()..color = const Color(0xFFFFF8EA));
    }

    void dashedLine(Offset a, Offset b) {
      final dashPaint = Paint()
        ..strokeWidth = 1.15
        ..color = lineColor;
      final len = (b - a).distance;
      if (len == 0) return;
      final dir = (b - a) / len;
      var d = 0.0;
      while (d < len) {
        final end = (d + 1.5).clamp(0, len);
        canvas.drawLine(a + dir * d, a + dir * end.toDouble(), dashPaint);
        d += 4.0;
      }
    }

    switch (kind) {
      case 'heart':
        loop(const [
          Offset(20, 32), Offset(9, 21), Offset(8, 13), Offset(13, 8),
          Offset(20, 13), Offset(27, 8), Offset(32, 13), Offset(31, 21),
        ]);
        for (final p in const [
          Offset(9, 21), Offset(8, 13), Offset(13, 8), Offset(27, 8),
          Offset(32, 13), Offset(31, 21), Offset(20, 32),
        ]) {
          dot(p.dx, p.dy, 1.3);
        }
        star(20, 14, 2.2, gold);
      case 'ring':
        canvas.drawCircle(const Offset(20, 25), 8.5, strokePaint);
        canvas.drawCircle(
          const Offset(20, 25),
          6.2,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.15
            ..color = lineColor.withValues(alpha: .4),
        );
        star(20, 13, 2.4, gold);
        dot(31, 8, 1);
        dot(9, 10, 0.9);
      case 'linked':
        canvas.drawLine(const Offset(11, 27), const Offset(29, 13), strokePaint);
        dot(17, 22.3, 1);
        dot(23, 17.6, 1);
        star(11, 27, 2.4, gold);
        star(29, 13, 2.4, violet);
      case 'moons':
        canvas.drawCircle(const Offset(15, 20), 8, strokePaint);
        canvas.drawCircle(const Offset(25, 20), 8, strokePaint);
        dot(15, 20, 2.2, gold);
        dot(25, 20, 2.2, violet);
      case 'gem':
        loop(const [
          Offset(12, 17), Offset(16, 11), Offset(24, 11), Offset(28, 17), Offset(20, 30),
        ]);
        canvas.drawLine(const Offset(12, 17), const Offset(28, 17), strokePaint);
        star(30, 9, 2, gold);
      case 'rise':
        final path = Path()
          ..moveTo(8, 31)
          ..lineTo(15, 24)
          ..lineTo(21, 26)
          ..lineTo(30, 12);
        canvas.drawPath(path, strokePaint);
        dot(8, 31, 1.3);
        dot(15, 24, 1.3);
        dot(21, 26, 1.3);
        star(30, 12, 2.6, gold);
        canvas.drawLine(
          const Offset(30, 12),
          const Offset(33, 7),
          Paint()
            ..strokeWidth = 1.15
            ..color = lineColor.withValues(alpha: .4),
        );
      case 'friends':
        dashedLine(const Offset(12, 22), const Offset(20, 10));
        dashedLine(const Offset(20, 10), const Offset(28, 22));
        star(12, 23, 2.4, gold);
        star(28, 23, 2.4, gold);
        dot(20, 31, 1);
      case 'family':
        loop(const [
          Offset(20, 9), Offset(30, 17), Offset(26, 30), Offset(14, 30), Offset(10, 17),
        ]);
        canvas.drawLine(
          const Offset(20, 9),
          const Offset(20, 21),
          Paint()
            ..strokeWidth = 1.15
            ..color = lineColor.withValues(alpha: .45),
        );
        for (final p in const [Offset(30, 17), Offset(26, 30), Offset(14, 30), Offset(10, 17)]) {
          dot(p.dx, p.dy, 1.5);
        }
        star(20, 9, 2.2, gold);
        dot(20, 21, 1.8, violet);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CatIconPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.active != active;
}
