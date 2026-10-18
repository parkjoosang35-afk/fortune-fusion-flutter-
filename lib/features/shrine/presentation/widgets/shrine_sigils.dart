// shrine_sigils.dart — ② 주문·부호 도상. 신당 디자인 핸드오프(widgets/sigils.dart)를
// 로직 변경 없이 그대로 이식했다(go_router/riverpod 의존 없는 순수 CustomPaint 레이어).
// 상단 viewBox 100×64 · 하단 viewBox 100×100. 선 굵기 2.6(viewBox 단위).
import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import '../../domain/shrine_tokens.dart';

const _sw = 2.6;

Paint _stroke(double k, [double w = _sw]) => Paint()
  ..style = PaintingStyle.stroke
  ..color = ShrineColor.jusa
  ..strokeWidth = w * k
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;
Paint get _fill => Paint()..color = ShrineColor.jusa;

/// 상단: 작은 두 글자 + 가로획 + 납작한 큰 글자(파자 결합).
class SigilTop extends StatelessWidget {
  final List<String> chars;
  const SigilTop({super.key, required this.chars});
  @override
  Widget build(BuildContext context) =>
      AspectRatio(aspectRatio: 100 / 64, child: CustomPaint(painter: _TopP(chars)));
}

class _TopP extends CustomPainter {
  final List<String> c;
  _TopP(this.c);
  void _t(Canvas cv, String s, double x, double y, double size, double k, {double sx = 1, double sy = 1}) {
    final tp = TextPainter(
        text: TextSpan(text: s, style: ShrineType.display(size * k, c: ShrineColor.jusa).copyWith(height: 1)),
        textDirection: TextDirection.ltr)
      ..layout();
    cv.save();
    cv.translate(x * k, y * k);
    cv.scale(sx, sy);
    tp.paint(cv, Offset(-tp.width / 2, -tp.height * .88));
    cv.restore();
  }

  @override
  void paint(Canvas cv, Size s) {
    final k = s.width / 100;
    _t(cv, c[0], 31, 20, 17, k);
    _t(cv, c[1], 69, 20, 17, k);
    cv.drawPath(Path()..moveTo(14 * k, 27 * k)..quadraticBezierTo(50 * k, 22 * k, 86 * k, 27 * k), _stroke(k));
    cv.drawLine(Offset(86 * k, 27 * k), Offset(82 * k, 33 * k), _stroke(k, _sw * .8));
    _t(cv, c[2], 50, 59, 30, k, sx: 1.55, sy: .78);
    cv.drawLine(Offset(50 * k, 2 * k), Offset(50 * k, 8 * k), _stroke(k));
  }

  @override
  bool shouldRepaint(_TopP o) => o.c.join() != c.join();
}

/// 하단: 주제별 도상 + 공통 나선 끝맺음.
/// 命/春 칠성 · 緣 매듭 · 財 엽전 · 流/災 삼재를 베는 획 · 至 동지.
class SigilBottom extends StatelessWidget {
  final String topic;
  const SigilBottom({super.key, required this.topic});
  @override
  Widget build(BuildContext context) => AspectRatio(aspectRatio: 1, child: CustomPaint(painter: _BotP(topic)));
}

class _BotP extends CustomPainter {
  final String t;
  _BotP(this.t);
  @override
  void paint(Canvas c, Size s) {
    final k = s.width / 100;
    Offset o(double x, double y) => Offset(x * k, y * k);
    final st = _stroke(k);
    switch (t) {
      case '命':
      case '春':
        const pts = [
          [30, 10],
          [52, 6],
          [56, 26],
          [32, 30],
          [66, 40],
          [74, 54],
          [70, 68]
        ];
        final bowl = Path()..moveTo(30 * k, 10 * k);
        for (final p in pts.sublist(1, 4)) {
          bowl.lineTo(p[0] * k, p[1] * k);
        }
        bowl.close();
        c.drawPath(bowl, st);
        final handle = Path()..moveTo(56 * k, 26 * k);
        for (final p in pts.sublist(4)) {
          handle.lineTo(p[0] * k, p[1] * k);
        }
        c.drawPath(handle, st);
        for (final p in pts) {
          c.drawCircle(o(p[0].toDouble(), p[1].toDouble()), 3.6 * k, _fill);
        }
        c.drawPath(
            Path()
              ..moveTo(22 * k, 50 * k)
              ..relativeLineTo(6 * k, -2 * k)
              ..relativeLineTo(2 * k, -6 * k)
              ..relativeLineTo(2 * k, 6 * k)
              ..relativeLineTo(6 * k, 2 * k)
              ..relativeLineTo(-6 * k, 2 * k)
              ..relativeLineTo(-2 * k, 6 * k)
              ..relativeLineTo(-2 * k, -6 * k)
              ..close(),
            _fill);
        c.drawPath(Path()..moveTo(70 * k, 68 * k)..quadraticBezierTo(60 * k, 74 * k, 50 * k, 76 * k), st);
      case '緣':
        c.drawPath(Path()..moveTo(50 * k, 0)..cubicTo(40 * k, 8 * k, 60 * k, 12 * k, 50 * k, 20 * k), st);
        for (final y in [24.0, 42.0, 60.0]) {
          c.drawPath(
              Path()
                ..moveTo(50 * k, (y - 4) * k)
                ..cubicTo(30 * k, (y - 14) * k, 30 * k, (y + 10) * k, 50 * k, (y + 2) * k)
                ..cubicTo(70 * k, (y + 10) * k, 70 * k, (y - 14) * k, 50 * k, (y - 4) * k)
                ..close(),
              st);
        }
        c.drawPath(Path()..moveTo(50 * k, 64 * k)..cubicTo(46 * k, 70 * k, 54 * k, 72 * k, 50 * k, 77 * k), st);
        final th = _stroke(k, _sw * .7);
        for (final y in [33.0, 51.0]) {
          c.drawLine(o(26, y), o(32, y), th);
          c.drawLine(o(68, y), o(74, y), th);
        }
      case '財':
        c.drawLine(o(50, 0), o(50, 77), _stroke(k, _sw * .8));
        for (final y in [14.0, 36.0, 58.0]) {
          c.drawCircle(o(50, y), 10.5 * k, st);
          c.drawCircle(o(50, y), 7.6 * k, _stroke(k, _sw * .5));
          final r = Rect.fromLTWH(46.4 * k, (y - 3.6) * k, 7.2 * k, 7.2 * k);
          c.drawRect(r, Paint()..color = const Color(0xFFE8D6AE));
          c.drawRect(r, _stroke(k, _sw * .7));
        }
        for (final y in [25.0, 47.0]) {
          c.drawLine(o(28, y), o(22, y), st);
          c.drawLine(o(72, y), o(78, y), st);
        }
      case '流':
      case '災':
        for (var i = 0; i < 3; i++) {
          final y = 8.0 + i * 14;
          c.drawPath(
              Path()
                ..moveTo((30 + i * 2) * k, y * k)
                ..quadraticBezierTo(50 * k, (y - 3) * k, (70 - i * 2) * k, y * k),
              st);
        }
        c.drawLine(o(74, 2), o(26, 42), _stroke(k, _sw * 1.1));
        c.drawPath(Path()..moveTo(50 * k, 44 * k)..lineTo(50 * k, 70 * k)..relativeLineTo(-8 * k, -6 * k), st);
        c.drawLine(o(40, 54), o(60, 54), _stroke(k, _sw * .8));
        c.drawLine(o(43, 60), o(57, 60), _stroke(k, _sw * .8));
        c.drawCircle(o(22, 22), 2.6 * k, _fill);
        c.drawCircle(o(78, 22), 2.6 * k, _fill);
      default: // 至
        c.drawCircle(o(50, 18), 12 * k, st);
        c.drawCircle(o(50, 18), 3 * k, _fill);
        c.drawPath(Path()..moveTo(30 * k, 40 * k)..quadraticBezierTo(50 * k, 26 * k, 70 * k, 40 * k), st);
        final th = _stroke(k, _sw * .85);
        c.drawLine(o(40, 44), o(40, 70), th);
        c.drawLine(o(60, 44), o(60, 70), th);
        for (final y in [52.0, 60.0, 68.0]) {
          c.drawLine(o(40, y), o(60, y), th);
        }
    }
    // 공통 나선(2.1회전, 반지름 9 → 15%).
    final sp = Path();
    for (var i = 0; i <= 60; i++) {
      final tt = i / 60, a = tt * 2.1 * math.pi * 2, r = 9 * (1 - tt * .85);
      final p = o(50 + math.cos(a) * r, 88 + math.sin(a) * r);
      i == 0 ? sp.moveTo(p.dx, p.dy) : sp.lineTo(p.dx, p.dy);
    }
    c.drawPath(sp, _stroke(k, _sw * .85));
  }

  @override
  bool shouldRepaint(_BotP o) => o.t != t;
}
