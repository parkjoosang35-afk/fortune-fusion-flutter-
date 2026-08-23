import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/wish_room_theme.dart';

/// [디자인 핸드오프 적용 — "마법진이 소환되는 신전"] 마법진(Sigil) 위젯.
///
/// `design_handoff/sigils.jsx`의 `Sigil({size, color, opacity})` SVG를
/// Flutter `CustomPainter`로 재구현했다. 원본 SVG viewBox가 `-100 -100 200
/// 200`(중심 원점)이므로, 페인터도 캔버스 중심을 원점으로 잡고 동일한
/// 반지름 비율(r=90/86/78/60/52/26/22)을 그대로 사용해 시각적으로 1:1
/// 대응시켰다.
///
/// 구성(중심에서 바깥쪽 순, 실제로는 바깥→안쪽 순으로 그림):
/// - 외곽 발광(radial gradient, r≈95)
/// - 외곽 이중 원(r=90, r=86) + 36개 tick mark + 12개 룬 글리프
/// - 중간 원(r=60) + 육각형(r=52) + 육망성(역삼각형 2개)
/// - 내부 이중 원(r=26, r=22) + 10각 별 중심
///
/// [애니메이션 — anim-dramatic] README/`wish-animations.css`의 V2 스펙:
/// - 정회전 40s / 역회전(reverse) 55s, linear, 무한 반복 — 이 위젯 자체는
///   회전하지 않고 [WishRoomSigilRing]이 회전을 담당한다(회전 축과 그리기
///   로직을 분리해 재사용성을 높임).
/// - 진입 시 `sigil-draw`: opacity 0→1 + scale 0.85→1 + blur 2px→0,
///   3.5s ease-out, 1회. 이 진입 연출은 [WishRoomSigilSummon]이 담당한다.
class WishRoomSigilPainter extends CustomPainter {
  final Color color;
  final double opacity;
  final double drawProgress; // 0~1, stroke-draw 진행도(1이면 완전히 그려짐)

  const WishRoomSigilPainter({
    required this.color,
    this.opacity = 0.5,
    this.drawProgress = 1.0,
  });

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
    final center = size.center(Offset.zero);
    // 원본 SVG viewBox 200×200(반경 100)에 맞춰 스케일 계산.
    final scale = size.shortestSide / 200.0;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale);

    // stroke-draw 애니메이션: 진행도가 낮을수록 바깥 링부터 점차 옅게
    // 나타나는 것이 아니라, 원본 CSS 스펙(opacity+scale+blur)을 단순화해
    // "전체가 함께 옅게/작게 시작해 목표 크기로 커지며 진해지는" 방식으로
    // 근사한다(개별 stroke path animation은 Flutter Canvas에서 PathMetric
    // 기반으로도 가능하지만, 이 위젯은 배경 장식 요소이므로 과한 복잡도를
    // 피하고 opacity/scale 조합으로 동일한 "소환되는" 느낌을 낸다).
    final t = drawProgress.clamp(0.0, 1.0);
    final localOpacity = opacity * t;
    if (t < 1.0) {
      final drawScale = 0.85 + 0.15 * t;
      canvas.scale(drawScale);
    }

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: 0.15 * t),
          color.withValues(alpha: 0),
        ],
      ).createShader(const Rect.fromLTWH(-95, -95, 190, 190));
    canvas.drawCircle(Offset.zero, 95, glowPaint);

    void ring(double r, double strokeOpacity, double strokeWidth) {
      final paint = Paint()
        ..color = color.withValues(alpha: strokeOpacity * localOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawCircle(Offset.zero, r, paint);
    }

    ring(90, 1.0, 0.6);
    ring(86, 0.5, 0.4);

    // 36개 tick mark
    final tickPaint = Paint()
      ..color = color.withValues(alpha: 0.8 * localOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    for (int i = 0; i < 36; i++) {
      final a = (i / 36) * 2 * pi;
      final p1 = Offset(cos(a) * 86, sin(a) * 86);
      final p2 = Offset(cos(a) * 90, sin(a) * 90);
      canvas.drawLine(p1, p2, tickPaint);
    }

    // 12개 룬 글리프
    for (int i = 0; i < 12; i++) {
      final a = (i / 12) * 2 * pi - pi / 2;
      final x = cos(a) * 78;
      final y = sin(a) * 78;
      final tp = TextPainter(
        text: TextSpan(
          text: _runes[i],
          style: TextStyle(
            color: color.withValues(alpha: localOpacity),
            fontSize: 6,
            fontFamily: 'serif',
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
    }

    ring(60, 0.6, 0.5);

    Paint polyPaint(double strokeOpacity, double strokeWidth) => Paint()
      ..color = color.withValues(alpha: strokeOpacity * localOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    // 육각형
    final hexPath = Path()
      ..moveTo(0, -52)
      ..lineTo(45, -26)
      ..lineTo(45, 26)
      ..lineTo(0, 52)
      ..lineTo(-45, 26)
      ..lineTo(-45, -26)
      ..close();
    canvas.drawPath(hexPath, polyPaint(0.8, 0.6));

    // 육망성 삼각형 2개
    final tri1 = Path()
      ..moveTo(0, 52)
      ..lineTo(-45, -26)
      ..lineTo(45, -26)
      ..close();
    canvas.drawPath(tri1, polyPaint(0.5, 0.5));

    final tri2 = Path()
      ..moveTo(0, -52)
      ..lineTo(-45, 26)
      ..lineTo(45, 26)
      ..close();
    canvas.drawPath(tri2, polyPaint(0.5, 0.5));

    ring(26, 1.0, 0.6);
    ring(22, 0.5, 0.4);

    // 중심 10각 별
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
    final starPaint = Paint()
      ..color = color.withValues(alpha: 0.6 * localOpacity)
      ..style = PaintingStyle.fill;
    canvas.drawPath(starPath, starPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant WishRoomSigilPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.opacity != opacity ||
        oldDelegate.drawProgress != drawProgress;
  }
}

/// 정지된(회전 없는) 단일 마법진. 회전이 필요한 경우 [WishRoomSigilRing]을
/// 사용한다.
class WishRoomSigil extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;
  final double drawProgress;

  const WishRoomSigil({
    super.key,
    this.size = 300,
    this.color = WishRoomColors.sigil,
    this.opacity = 0.5,
    this.drawProgress = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: WishRoomSigilPainter(
          color: color,
          opacity: opacity,
          drawProgress: drawProgress,
        ),
      ),
    );
  }
}

/// [anim-dramatic] 무한히 회전하는 마법진 링.
///
/// README 애니메이션 타이밍표(V2 열): 정회전 40s / 역회전 55s, linear,
/// 무한 반복. [reverse]가 true면 역방향(-360deg)으로 회전한다.
///
/// 성능: 자체 [AnimationController]로 회전만 갱신하고, 실제 마법진 페인팅은
/// [WishRoomSigilPainter](정적 셰이더/패스)에 맡긴다. 상위에서
/// RepaintBoundary로 감싸 배경 전체 리페인트와 분리하는 것을 권장한다
/// (사용처인 [WishRoomBackground]에서 이미 그렇게 처리).
class WishRoomSigilRing extends StatefulWidget {
  final double size;
  final Color color;
  final double opacity;
  final bool reverse;
  final double drawProgress;

  const WishRoomSigilRing({
    super.key,
    this.size = 300,
    this.color = WishRoomColors.sigil,
    this.opacity = 0.5,
    this.reverse = false,
    this.drawProgress = 1.0,
  });

  @override
  State<WishRoomSigilRing> createState() => _WishRoomSigilRingState();
}

class _WishRoomSigilRingState extends State<WishRoomSigilRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // anim-dramatic: 정회전 40s, 역회전 55s.
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.reverse ? 55 : 40),
    )..repeat();
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
        final angle =
            _controller.value * 2 * pi * (widget.reverse ? -1 : 1);
        return Transform.rotate(
          angle: angle,
          child: WishRoomSigil(
            size: widget.size,
            color: widget.color,
            opacity: widget.opacity,
            drawProgress: widget.drawProgress,
          ),
        );
      },
    );
  }
}

/// [anim-dramatic] `sigil-draw` 소환 진입 애니메이션 래퍼.
///
/// README: opacity 0→1, scale 0.85→1, blur 2px→0, 3.5s ease-out, 1회.
/// 화면(스크린)이 처음 마운트될 때 마법진이 "그려지며 소환되는" 느낌을
/// 낸다. `drawProgress`를 [WishRoomSigilRing]/[WishRoomSigil]에 전달해
/// 페인터 자체의 축소 연출과 결합하고, 여기서는 추가로 Opacity +
/// ImageFiltered(blur)를 감싸 CSS `filter: blur()` 효과를 근사한다.
class WishRoomSigilSummon extends StatefulWidget {
  final Widget Function(BuildContext context, double drawProgress) builder;
  final Duration duration;

  const WishRoomSigilSummon({
    super.key,
    required this.builder,
    this.duration = const Duration(milliseconds: 3500),
  });

  @override
  State<WishRoomSigilSummon> createState() => _WishRoomSigilSummonState();
}

class _WishRoomSigilSummonState extends State<WishRoomSigilSummon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curved;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _curved = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curved,
      builder: (context, _) {
        final t = _curved.value;
        final blurSigma = (1 - t) * 2.0;
        Widget child = widget.builder(context, t);
        if (blurSigma > 0.01) {
          child = ImageFiltered(
            imageFilter: ui.ImageFilter.blur(
              sigmaX: blurSigma,
              sigmaY: blurSigma,
            ),
            child: child,
          );
        }
        return Opacity(opacity: t, child: child);
      },
    );
  }
}
