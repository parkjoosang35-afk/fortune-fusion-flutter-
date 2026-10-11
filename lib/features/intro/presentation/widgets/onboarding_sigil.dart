import 'dart:math' as math;

import 'package:flutter/material.dart';

/// [온보딩 화면 교체 2026-10-11] `Onboarding.html`의 `sigil()` 함수(인라인
/// SVG 마법진)를 `CustomPainter`로 1:1 재현한다 — viewBox `-100 -100 200
/// 200` 기준 좌표를 그대로 사용한다.
///
/// 구성(바깥→안쪽):
/// - 바깥 원 r90(선 0.6, opacity `op`)
/// - 원 r86(선 0.4, opacity `op*.5`)
/// - 눈금 36개(r86→90, 선 0.5, opacity `op*.8`)
/// - 룬 12개(r78 위치, serif 6px, opacity `op`):
///   `✧ ✦ ☾ ❋ ◈ ✵ ❈ ✺ ✶ ☆ ◇ ⟡`
/// - 점선 원 r66(opacity `op*.6`, dash `1 3`)
/// - 육각형(r62, opacity `op*.4`)
class OnboardingSigilPainter extends CustomPainter {
  const OnboardingSigilPainter({
    required this.color,
    this.opacity = 0.7,
    this.rotationRadians = 0,
  });

  final Color color;
  final double opacity;
  final double rotationRadians;

  static const List<String> _runes = [
    '✧',
    '✦',
    '☾',
    '❋',
    '◈',
    '✵',
    '❈',
    '✺',
    '✶',
    '☆',
    '◇',
    '⟡',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // viewBox -100..100(가로세로 200) → 실제 size로 스케일.
    final scale = size.width / 200.0;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(rotationRadians);
    canvas.scale(scale, scale);

    final outerCircle = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = color.withValues(alpha: opacity);
    canvas.drawCircle(Offset.zero, 90, outerCircle);

    final innerCircle = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.4
      ..color = color.withValues(alpha: opacity * 0.5);
    canvas.drawCircle(Offset.zero, 86, innerCircle);

    // 눈금 36개 — r86→90.
    final tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = color.withValues(alpha: opacity * 0.8);
    for (var i = 0; i < 36; i++) {
      final a = i / 36 * 2 * math.pi;
      final from = Offset(math.cos(a) * 86, math.sin(a) * 86);
      final to = Offset(math.cos(a) * 90, math.sin(a) * 90);
      canvas.drawLine(from, to, tickPaint);
    }

    // 룬 12개 — r78, serif 6px(viewBox 좌표 기준이므로 실제 스케일은
    // canvas.scale이 이미 적용한 상태).
    for (var i = 0; i < _runes.length; i++) {
      final a = i / 12 * 2 * math.pi - math.pi / 2;
      final pos = Offset(math.cos(a) * 78, math.sin(a) * 78);
      final tp = TextPainter(
        text: TextSpan(
          text: _runes[i],
          style: TextStyle(
            fontFamily: 'serif',
            fontSize: 6,
            color: color.withValues(alpha: opacity),
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }

    // 점선 원 r66, dash '1 3'.
    _drawDashedCircle(
      canvas,
      radius: 66,
      paint: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5
        ..color = color.withValues(alpha: opacity * 0.6),
      dashLength: 1,
      gapLength: 3,
    );

    // 육각형(r62).
    final hexPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = color.withValues(alpha: opacity * 0.4);
    final hexPath = Path();
    const hexPoints = [
      Offset(0, -62),
      Offset(54, -31),
      Offset(54, 31),
      Offset(0, 62),
      Offset(-54, 31),
      Offset(-54, -31),
    ];
    hexPath.moveTo(hexPoints[0].dx, hexPoints[0].dy);
    for (var i = 1; i < hexPoints.length; i++) {
      hexPath.lineTo(hexPoints[i].dx, hexPoints[i].dy);
    }
    hexPath.close();
    canvas.drawPath(hexPath, hexPaint);

    canvas.restore();
  }

  void _drawDashedCircle(
    Canvas canvas, {
    required double radius,
    required Paint paint,
    required double dashLength,
    required double gapLength,
  }) {
    final circumference = 2 * math.pi * radius;
    final dashCount = (circumference / (dashLength + gapLength)).floor();
    final dashAngle = (dashLength / radius);
    final gapAngle = (gapLength / radius);
    var angle = 0.0;
    for (var i = 0; i < dashCount; i++) {
      final path = Path();
      path.addArc(
        Rect.fromCircle(center: Offset.zero, radius: radius),
        angle,
        dashAngle,
      );
      canvas.drawPath(path, paint);
      angle += dashAngle + gapAngle;
    }
  }

  @override
  bool shouldRepaint(covariant OnboardingSigilPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.opacity != opacity ||
        oldDelegate.rotationRadians != rotationRadians;
  }
}

/// [B1 앰비언트] 마법진이 140s 주기로 linear 360° 회전(무한 반복)하는
/// 위젯 래퍼. `reduceMotion`이면 회전을 멈추고 정지 상태로 그린다.
class OnboardingSigil extends StatefulWidget {
  const OnboardingSigil({
    super.key,
    this.color = const Color(0xFFE8C8F5),
    this.opacity = 0.7,
    this.reduceMotion = false,
  });

  final Color color;
  final double opacity;
  final bool reduceMotion;

  @override
  State<OnboardingSigil> createState() => _OnboardingSigilState();
}

class _OnboardingSigilState extends State<OnboardingSigil>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 140), // B1 "rotate 360° / 140s".
    );
    if (!widget.reduceMotion) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: OnboardingSigilPainter(
            color: widget.color,
            opacity: widget.opacity,
            rotationRadians: _controller.value * 2 * math.pi,
          ),
        );
      },
    );
  }
}
