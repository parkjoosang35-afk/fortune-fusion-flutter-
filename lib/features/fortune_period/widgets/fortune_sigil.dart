/// [기간별 운세 — Sigil 마법진 포팅]
///
/// `design_handoff_fortune_v4/design_files/sigils.jsx`의 `Sigil` SVG
/// 컴포넌트(viewBox -100..100, 외곽 눈금 36개 · 12개 룬 문자 · 육망성 ·
/// 중앙 별)를 Flutter `CustomPainter`로 1:1 포팅한다.
///
/// [기존 자산과의 관계] 기하 구조는 `core/theme/legacy_wish_room/
/// wish_room_sigil.dart`의 `WishRoomSigilPainter`와 완전히 동일하다 —
/// 다만 그 파일은 소원방(crystal/lavender) 전용 네임스페이스에 있고
/// `fortune_period`가 그 기능에 의존성을 갖는 것은 바람직하지 않으므로
/// (feature 간 결합 방지), 동일한 드로잉 로직을 이 기능 전용 위젯으로
/// 새로 둔다. 색상은 `FortunePeriodColors.sigil`(금빛, #c9a24a)을 쓴다.
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 정적(회전 없음) 마법진. `Sigil size={240} color="var(--sigil)"
/// opacity={0.35}` 와 같은 배경 장식 용도.
class FortuneSigil extends StatelessWidget {
  const FortuneSigil({
    super.key,
    this.size = 240,
    this.color,
    this.opacity = 0.35,
  });

  final double size;
  final Color? color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: FortuneSigilPainter(
          color: color ?? const Color(0xFFC9A24A),
          opacity: opacity,
        ),
      ),
    );
  }
}

/// 자동 회전하는 마법진 — 배경 장식(천천히 도는 `sigil-slow`/`sigil-mid`
/// CSS 애니메이션에 대응).
class FortuneSigilRing extends StatefulWidget {
  const FortuneSigilRing({
    super.key,
    this.size = 420,
    this.color,
    this.opacity = 0.22,
    this.duration = const Duration(seconds: 160),
  });

  final double size;
  final Color? color;
  final double opacity;
  final Duration duration;

  @override
  State<FortuneSigilRing> createState() => _FortuneSigilRingState();
}

class _FortuneSigilRingState extends State<FortuneSigilRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Transform.rotate(
          angle: _ctrl.value * 2 * math.pi,
          child: child,
        );
      },
      child: FortuneSigil(
        size: widget.size,
        color: widget.color,
        opacity: widget.opacity,
      ),
    );
  }
}

/// `sigils.jsx`의 `Sigil` SVG를 그대로 포팅한 CustomPainter.
/// viewBox는 -100..100(200×200)이므로, 실제 캔버스 크기에 맞춰 스케일.
class FortuneSigilPainter extends CustomPainter {
  FortuneSigilPainter({required this.color, required this.opacity});

  final Color color;
  final double opacity;

  static const List<String> _runes = [
    '✧', '✦', '☾', '❋', '◈', '✵', '❈', '✺', '✶', '☆', '◇', '⟡',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final scale = size.width / 200; // viewBox 200×200 → 실제 크기

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale);

    // glow radial gradient (반경 95)
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0)],
      ).createShader(const Rect.fromLTWH(-95, -95, 190, 190));
    canvas.drawCircle(Offset.zero, 95, glowPaint);

    // outer rings
    _strokeCircle(canvas, 90, color, opacity, 0.6);
    _strokeCircle(canvas, 86, color, opacity * 0.5, 0.4);

    // tick marks (36개)
    final tickPaint = Paint()
      ..color = color.withValues(alpha: opacity * 0.8)
      ..strokeWidth = 0.5;
    for (var i = 0; i < 36; i++) {
      final a = (i / 36) * 2 * math.pi;
      final p1 = Offset(math.cos(a) * 86, math.sin(a) * 86);
      final p2 = Offset(math.cos(a) * 90, math.sin(a) * 90);
      canvas.drawLine(p1, p2, tickPaint);
    }

    // runes (12개)
    for (var i = 0; i < 12; i++) {
      final a = (i / 12) * 2 * math.pi - math.pi / 2;
      const r = 78.0;
      final pos = Offset(math.cos(a) * r, math.sin(a) * r);
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
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }

    // middle ring
    _strokeCircle(canvas, 60, color, opacity * 0.6, 0.5);

    // hexagram (육망성 — 큰 육각형 + 두 삼각형)
    _strokePolygon(canvas, const [
      Offset(0, -52), Offset(45, -26), Offset(45, 26),
      Offset(0, 52), Offset(-45, 26), Offset(-45, -26),
    ], color, opacity * 0.8, 0.6);
    _strokePolygon(canvas, const [
      Offset(0, 52), Offset(-45, -26), Offset(45, -26),
    ], color, opacity * 0.5, 0.5);
    _strokePolygon(canvas, const [
      Offset(0, -52), Offset(-45, 26), Offset(45, 26),
    ], color, opacity * 0.5, 0.5);

    // inner rings
    _strokeCircle(canvas, 26, color, opacity, 0.6);
    _strokeCircle(canvas, 22, color, opacity * 0.5, 0.4);

    // center star
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
    canvas.drawPath(
      starPath,
      Paint()..color = color.withValues(alpha: opacity * 0.6),
    );

    canvas.restore();
  }

  void _strokeCircle(
    Canvas canvas,
    double r,
    Color color,
    double alpha,
    double strokeWidth,
  ) {
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = color.withValues(alpha: alpha),
    );
  }

  void _strokePolygon(
    Canvas canvas,
    List<Offset> points,
    Color color,
    double alpha,
    double strokeWidth,
  ) {
    final path = Path()..addPolygon(points, true);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = color.withValues(alpha: alpha),
    );
  }

  @override
  bool shouldRepaint(covariant FortuneSigilPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.opacity != opacity;
  }
}
