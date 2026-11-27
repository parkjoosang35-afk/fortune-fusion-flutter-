// ═══════════════════════════════════════════════════════════════
// FILE: cat_icon.dart
// [궁합지도 전면 리디자인 v4] design_handoff_gunghap_map_v4
// `00_DEV_MAPPING.md` §2-4 + `flutter_starter/lib/gunghap/widgets/
// cat_icon.dart`(v3 참고 구현) 완전 포팅 — 대분류 8종을 별자리(점+선)
// 스타일 아이콘으로 표현한다. viewBox 40×40 · stroke 1.7 · 선 = c1 ·
// 점 = c2 · 4각 별 = c1(linked 둘째 별은 c2).
//
// [신규] `white` 파라미터 — DestinyBurst의 분야 네모(선택 시 c1 배경 +
// 흰 아이콘)에서 사용한다. 기존 호출부(`CatIcon(kind:, size:, active:)`)는
// `white` 생략 시 기본값 false로 그대로 호환된다.
// ═══════════════════════════════════════════════════════════════
import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/gh_tokens.dart';

const _iconColors = <String, (Color, Color)>{
  'heart': (Color(0xFFFF4D8D), Color(0xFFFF9A8B)),
  'ring': (Color(0xFFF59E0B), Color(0xFFFB7185)),
  'linked': (Color(0xFFEC4899), Color(0xFF8B5CF6)),
  'moons': (Color(0xFF6366F1), Color(0xFF22D3EE)),
  'gem': (Color(0xFFF59E0B), Color(0xFFEAB308)),
  'rise': (Color(0xFF0EA5E9), Color(0xFF6366F1)),
  'friends': (Color(0xFF10B981), Color(0xFF22D3EE)),
  'family': (Color(0xFFF97316), Color(0xFFEC4899)),
};

class CatIcon extends StatelessWidget {
  const CatIcon({
    super.key,
    required this.kind,
    this.size = 40,
    this.active = false,
    this.white = false,
  });
  final String kind;
  final double size;
  final bool active;

  /// 분야 네모(CatIconPainter 사용처) 선택 상태 — true면 아이콘 전체를
  /// 흰색으로 그린다(배경이 이미 c1로 채워진 경우에만 사용).
  final bool white;

  @override
  Widget build(BuildContext context) {
    final c1 = (_iconColors[kind] ?? (GHColors.accent, GHColors.violet)).$1;
    return Container(
      decoration: active && !white
          ? BoxDecoration(
              boxShadow: [
                BoxShadow(color: c1.withValues(alpha: .4), blurRadius: 6, offset: const Offset(0, 2)),
              ],
              shape: BoxShape.circle,
            )
          : null,
      child: CustomPaint(size: Size.square(size), painter: CatIconPainter(kind, white: white)),
    );
  }
}

class CatIconPainter extends CustomPainter {
  CatIconPainter(this.kind, {this.white = false});
  final String kind;
  final bool white;

  @override
  void paint(Canvas canvas, Size size) {
    final (c1raw, c2raw) = _iconColors[kind] ?? (GHColors.accent, GHColors.violet);
    final c1 = white ? Colors.white : c1raw;
    final c2 = white ? Colors.white : c2raw;
    canvas.save();
    canvas.scale(size.width / 40);
    final st = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = c1;
    Paint stA(double a) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = c1.withValues(alpha: a);
    void dot(double x, double y, [double r = 1.6, Color? c]) =>
        canvas.drawCircle(Offset(x, y), r, Paint()..color = c ?? c2);
    void star(double x, double y, double r, Color c) {
      final p = Path();
      for (var i = 0; i < 8; i++) {
        final a = i * pi / 4 - pi / 2;
        final rr = i.isEven ? r * 2.2 : r * .55;
        final pt = Offset(x + cos(a) * rr, y + sin(a) * rr);
        i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
      }
      canvas.drawPath(p..close(), Paint()..color = c);
    }

    Path poly(List<List<double>> pts, {bool close = false}) {
      final p = Path()..moveTo(pts[0][0], pts[0][1]);
      for (final q in pts.skip(1)) {
        p.lineTo(q[0], q[1]);
      }
      if (close) p.close();
      return p;
    }

    switch (kind) {
      case 'heart':
        final pts = [
          [20.0, 32.0], [9.0, 21.0], [8.0, 13.0], [13.0, 8.0],
          [20.0, 13.0], [27.0, 8.0], [32.0, 13.0], [31.0, 21.0],
        ];
        canvas.drawPath(poly(pts, close: true), st);
        for (final q in [
          [9.0, 21.0], [8.0, 13.0], [13.0, 8.0], [27.0, 8.0],
          [32.0, 13.0], [31.0, 21.0], [20.0, 32.0],
        ]) {
          dot(q[0], q[1], 1.3);
        }
        star(20, 14, 2.2, c1);
      case 'ring':
        canvas.drawCircle(const Offset(20, 25), 8.5, st);
        canvas.drawCircle(const Offset(20, 25), 6.2, stA(.4));
        star(20, 13, 2.4, c1);
        dot(31, 8, 1);
        dot(9, 10, .9);
      case 'linked':
        canvas.drawLine(const Offset(11, 27), const Offset(29, 13), st);
        dot(17, 22.3, 1);
        dot(23, 17.6, 1);
        star(11, 27, 2.4, c1);
        star(29, 13, 2.4, c2);
      case 'moons':
        canvas.drawCircle(const Offset(15, 20), 8, st);
        canvas.drawCircle(const Offset(25, 20), 8, st);
        canvas.drawCircle(const Offset(15, 20), 2.2, Paint()..color = c1);
        canvas.drawCircle(const Offset(25, 20), 2.2, Paint()..color = c2);
      case 'gem':
        canvas.drawPath(
          poly([
            [12, 17], [16, 11], [24, 11], [28, 17], [20, 30],
          ], close: true),
          st,
        );
        canvas.drawLine(const Offset(12, 17), const Offset(28, 17), st);
        canvas.drawPath(
          poly([
            [16, 11], [18, 17], [20, 30], [22, 17], [24, 11],
          ]),
          stA(.45),
        );
        star(30, 9, 2, c1);
      case 'rise':
        canvas.drawPath(
          poly([
            [8, 31], [15, 24], [21, 26], [30, 12],
          ]),
          st,
        );
        dot(8, 31, 1.3);
        dot(15, 24, 1.3);
        dot(21, 26, 1.3);
        star(30, 12, 2.6, c1);
        canvas.drawLine(const Offset(30, 12), const Offset(33, 7), stA(.4));
      case 'friends':
        final arc = Path()
          ..moveTo(12, 22)
          ..quadraticBezierTo(20, 10, 28, 22);
        for (final m in arc.computeMetrics()) {
          for (double d = 0; d < m.length; d += 4) {
            canvas.drawPath(m.extractPath(d, min(d + 1.5, m.length)), st);
          }
        }
        star(12, 23, 2.4, c1);
        star(28, 23, 2.4, c1);
        dot(20, 31, 1);
      case 'family':
        canvas.drawPath(
          poly([
            [20, 9], [30, 17], [26, 30], [14, 30], [10, 17],
          ], close: true),
          st,
        );
        canvas.drawLine(const Offset(20, 9), const Offset(20, 21), stA(.45));
        for (final q in [
          [30.0, 17.0], [26.0, 30.0], [14.0, 30.0], [10.0, 17.0],
        ]) {
          dot(q[0], q[1], 1.5);
        }
        star(20, 9, 2.2, c1);
        dot(20, 21, 1.8, c2);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CatIconPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.white != white;
}
