import 'dart:math' as math;

import 'package:flutter/material.dart';

/// [온보딩 v2 리디자인 2026-10-18] `온보딩 v2.html`의 `sigil()` 함수(인라인
/// SVG 마법진)를 `CustomPainter`로 1:1 재현한다 — viewBox `-100 -100 200
/// 200` 기준 좌표를 그대로 사용한다.
///
/// [v1→v2 변경] v1(`Onboarding.html`)은 점선 원 + 육각형 1개였지만, v2는
/// README §3 지시("가운데 원과 별은 빼고 바깥 링, 룬, 육각성만")에 따라
/// 점선 원을 제거하고 **육각성(Star of David류, 정삼각형 2개 겹침) 1조**로
/// 교체했다. 호출부([OnboardingSigil])가 히어로 2겹(A/B) 각각 다른 색·opacity·
/// 회전 방향으로 이 Painter를 재사용한다.
///
/// 구성(바깥→안쪽):
/// - 바깥 원 r90(선 0.6, opacity `op`)
/// - 원 r86(선 0.4, opacity `op*.5`)
/// - 눈금 36개(r86→90, 선 0.5, opacity `op*.8`)
/// - 룬 12개(r78 위치, serif 6px, opacity `op`):
///   `✧ ✦ ☾ ❋ ◈ ✵ ❈ ✺ ✶ ☆ ◇ ⟡`
/// - 원 r60(선 0.5, opacity `op*.6`)
/// - 육각성(정삼각형 2개, r52, opacity `op*.8`/`op*.5`)
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

    // 원 r60(v2: 점선 대신 실선 — `<circle r="60" .../>`).
    final midCirclePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = color.withValues(alpha: opacity * 0.6);
    canvas.drawCircle(Offset.zero, 60, midCirclePaint);

    // 육각성 — 정삼각형 2개 겹침(r52), v2 신규. 첫 번째 삼각형이 더 진하다(op*.8).
    final hexPaintStrong = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = color.withValues(alpha: opacity * 0.8);
    final hexPaintSoft = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = color.withValues(alpha: opacity * 0.5);

    // `polygon points="0,-52 45,-26 45,26 0,52 -45,26 -45,-26"` — 육각형
    // 꼭짓점 좌표 그대로(정육각형처럼 보이지만 실제로는 6점 폴리곤).
    final hexPath = Path();
    const hexPoints = [
      Offset(0, -52),
      Offset(45, -26),
      Offset(45, 26),
      Offset(0, 52),
      Offset(-45, 26),
      Offset(-45, -26),
    ];
    hexPath.moveTo(hexPoints[0].dx, hexPoints[0].dy);
    for (var i = 1; i < hexPoints.length; i++) {
      hexPath.lineTo(hexPoints[i].dx, hexPoints[i].dy);
    }
    hexPath.close();
    canvas.drawPath(hexPath, hexPaintStrong);

    // `polygon points="0,52 -45,-26 45,-26"` — 아래쪽 꼭짓점 삼각형.
    final triDownPath = Path()
      ..moveTo(0, 52)
      ..lineTo(-45, -26)
      ..lineTo(45, -26)
      ..close();
    canvas.drawPath(triDownPath, hexPaintSoft);

    // `polygon points="0,-52 -45,26 45,26"` — 위쪽 꼭짓점 삼각형(Star of
    // David 형태를 완성하는 2번째 역삼각형).
    final triUpPath = Path()
      ..moveTo(0, -52)
      ..lineTo(-45, 26)
      ..lineTo(45, 26)
      ..close();
    canvas.drawPath(triUpPath, hexPaintSoft);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant OnboardingSigilPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.opacity != opacity ||
        oldDelegate.rotationRadians != rotationRadians;
  }
}

/// [앰비언트] 마법진이 [periodSeconds] 주기로 linear 360° 회전(무한 반복)하는
/// 위젯 래퍼. `reduceMotion`이면 회전을 멈추고 정지 상태로 그린다.
///
/// [v1→v2 변경] v1은 140s 고정·항상 시계방향 1겹이었지만, v2(README §3)는
/// 히어로 안에 2겹을 겹쳐 쓴다 — A(420×420, 200s 시계방향)·B(280×280, 140s
/// 반시계방향). 이를 위해 [periodSeconds]/[reverse] 파라미터를 추가했다
/// (기본값은 v1 호환을 위해 140s·정방향 유지).
class OnboardingSigil extends StatefulWidget {
  const OnboardingSigil({
    super.key,
    this.color = const Color(0xFFE8C8F5),
    this.opacity = 0.7,
    this.reduceMotion = false,
    this.periodSeconds = 140,
    this.reverse = false,
  });

  final Color color;
  final double opacity;
  final bool reduceMotion;

  /// 1회전 소요 시간(초). v2 Sigil A=200, Sigil B=140.
  final int periodSeconds;

  /// true면 반시계방향(v2 Sigil B).
  final bool reverse;

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
          painter: OnboardingSigilPainter(
            color: widget.color,
            opacity: widget.opacity,
            rotationRadians: turns * 2 * math.pi,
          ),
        );
      },
    );
  }
}
