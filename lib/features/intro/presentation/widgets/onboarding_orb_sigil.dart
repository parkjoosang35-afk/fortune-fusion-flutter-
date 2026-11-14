import 'dart:math' as math;

import 'package:flutter/material.dart';

/// [온보딩 전면 교체 2026-11 — design_handoff_onboarding_v2.zip 반영]
/// `Onboarding v2.html`의 `outer()`/`inner()` 함수(인라인 SVG 마법진)를
/// `CustomPainter`로 1:1 재현한다 — viewBox `-100 -100 200 200` 기준
/// 좌표를 그대로 사용한다. 화면 중심 "Orb"(달+마법진) 그래픽 전용으로,
/// 기존 `onboarding_sigil.dart`(아치 프레임용, 구 디자인 보존)와는 별개의
/// 신규 파일이다.
///
/// 바깥 마법진(`outer`) — README §2 Stage-Orb 표 1행:
/// - 원 r90(선 0.6, opacity `o`)
/// - 눈금 48개: 4개마다 긴 눈금 r84→90(선 .5, op `o*.8`), 나머지는
///   짧은 눈금 r87→90
/// - 룬 12개(r77, serif 6px, opacity `o`):
///   `✧ ✦ ☾ ❋ ◈ ✵ ❈ ✺ ✶ ☆ ◇ ⟡`
/// - 점선 원 r70(dash "1 3", 선 .4, opacity `o*.5`)
class OnboardingOuterSigilPainter extends CustomPainter {
  const OnboardingOuterSigilPainter({
    required this.color,
    this.opacity = 0.6,
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
    final scale = size.width / 200.0;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(rotationRadians);
    canvas.scale(scale, scale);

    final circlePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = color.withValues(alpha: opacity);
    canvas.drawCircle(Offset.zero, 90, circlePaint);

    final tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = color.withValues(alpha: opacity * 0.8);
    for (var i = 0; i < 48; i++) {
      final a = i / 48 * 2 * math.pi;
      final from = i % 4 == 0
          ? Offset(math.cos(a) * 84, math.sin(a) * 84)
          : Offset(math.cos(a) * 87, math.sin(a) * 87);
      final to = Offset(math.cos(a) * 90, math.sin(a) * 90);
      canvas.drawLine(from, to, tickPaint);
    }

    for (var i = 0; i < _runes.length; i++) {
      final a = i / 12 * 2 * math.pi - math.pi / 2;
      final pos = Offset(math.cos(a) * 77, math.sin(a) * 77);
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

    final dashPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.4
      ..color = color.withValues(alpha: opacity * 0.5);
    _drawDashedCircle(canvas, radius: 70, dashPaint: dashPaint);

    canvas.restore();
  }

  void _drawDashedCircle(
    Canvas canvas, {
    required double radius,
    required Paint dashPaint,
    double dashLength = 1,
    double gapLength = 3,
  }) {
    final circumference = 2 * math.pi * radius;
    final segment = dashLength + gapLength;
    final count = (circumference / segment).floor();
    for (var i = 0; i < count; i++) {
      final startAngle = (i * segment) / radius;
      final sweepAngle = dashLength / radius;
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: radius),
        startAngle,
        sweepAngle,
        false,
        dashPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant OnboardingOuterSigilPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.opacity != opacity ||
        oldDelegate.rotationRadians != rotationRadians;
  }
}

/// 안쪽 마법진(`inner`) — README §2 Stage-Orb 표 2행: 육각형 r96
/// (op `o*.7`, 선 .7) + 삼각형 2개(op `o*.45`, 선 .6) = 헥사그램.
class OnboardingInnerSigilPainter extends CustomPainter {
  const OnboardingInnerSigilPainter({
    required this.color,
    this.opacity = 0.5,
    this.rotationRadians = 0,
  });

  final Color color;
  final double opacity;
  final double rotationRadians;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 200.0;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(rotationRadians);
    canvas.scale(scale, scale);

    final hexPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = color.withValues(alpha: opacity * 0.7);
    final triPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = color.withValues(alpha: opacity * 0.45);

    final hexPath = Path()
      ..moveTo(0, -96)
      ..lineTo(83, -48)
      ..lineTo(83, 48)
      ..lineTo(0, 96)
      ..lineTo(-83, 48)
      ..lineTo(-83, -48)
      ..close();
    canvas.drawPath(hexPath, hexPaint);

    final triDownPath = Path()
      ..moveTo(0, 96)
      ..lineTo(-83, -48)
      ..lineTo(83, -48)
      ..close();
    canvas.drawPath(triDownPath, triPaint);

    final triUpPath = Path()
      ..moveTo(0, -96)
      ..lineTo(-83, 48)
      ..lineTo(83, 48)
      ..close();
    canvas.drawPath(triUpPath, triPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant OnboardingInnerSigilPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.opacity != opacity ||
        oldDelegate.rotationRadians != rotationRadians;
  }
}

/// [상시 애니메이션] 마법진을 [periodSeconds] 주기로 linear 360° 회전
/// (무한 반복)시키는 공용 래퍼. `reduceMotion`이면 회전을 멈추고 정지
/// 상태로 그린다. README 상시 애니메이션 표: 바깥 160s(정방향), 안쪽 90s
/// (역방향).
class OnboardingRotatingSigil extends StatefulWidget {
  const OnboardingRotatingSigil({
    super.key,
    required this.painterBuilder,
    required this.periodSeconds,
    this.reverse = false,
    this.reduceMotion = false,
  });

  final CustomPainter Function(double rotationRadians) painterBuilder;
  final int periodSeconds;
  final bool reverse;
  final bool reduceMotion;

  @override
  State<OnboardingRotatingSigil> createState() =>
      _OnboardingRotatingSigilState();
}

class _OnboardingRotatingSigilState extends State<OnboardingRotatingSigil>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.periodSeconds),
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
        final turns = widget.reverse ? -_controller.value : _controller.value;
        return CustomPaint(
          painter: widget.painterBuilder(turns * 2 * math.pi),
          size: Size.infinite,
        );
      },
    );
  }
}
