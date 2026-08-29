import 'dart:math';
import 'package:flutter/material.dart';

/// [Phase C - 03_Welcome_Reward.html 반영] `.pouch-hero` 안의 인라인 SVG
/// 복주머니(福)를 `CustomPainter`로 1:1 이식한 것. 원본 SVG viewBox가
/// `0 0 100 110`이므로 페인터도 동일 좌표계를 그대로 사용해 시각적으로
/// 대응시켰다(그라디언트 body/neck/glow, 끈 매듭 2개, 세로 접힘선 3개,
/// 하이라이트 곡선, "福" 글자, 아래쪽 술 장식까지 포함).
///
/// [범위 격리 원칙] 이 위젯은 웰컴 리워드 팝업(Phase C) 전용이며 색상은
/// 핸드오프 원문 hex(#e8c8f5/#a8b5e8/#3d3568/#f5d97a)를 그대로 하드코딩해
/// 앱 전역 메인 컬러 파일을 참조하지 않는다.
class WelcomeRewardPouchPainter extends CustomPainter {
  const WelcomeRewardPouchPainter();

  static const _lavender = Color(0xFFE8C8F5);
  static const _periwinkle = Color(0xFFA8B5E8);
  static const _deepIndigo = Color(0xFF3D3568);
  static const _gold = Color(0xFFF5D97A);

  @override
  void paint(Canvas canvas, Size size) {
    // 원본 viewBox 100x110 → 실제 캔버스 크기로 스케일.
    final scaleX = size.width / 100.0;
    final scaleY = size.height / 110.0;
    canvas.save();
    canvas.scale(scaleX, scaleY);

    // 배경 원형 glow(radialGradient #wp-glow).
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          _gold.withValues(alpha: 0.45),
          _gold.withValues(alpha: 0),
        ],
      ).createShader(const Rect.fromLTWH(-5, 5, 110, 110));
    canvas.drawCircle(const Offset(50, 60), 55, glowPaint);

    // 끈 매듭 2개(좌/우 상단 loop).
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = _periwinkle.withValues(alpha: 0.85)
      ..strokeCap = StrokeCap.round;
    final leftLoop = Path()
      ..moveTo(32, 20)
      ..quadraticBezierTo(30, 10, 40, 10)
      ..quadraticBezierTo(45, 10, 45, 18);
    final rightLoop = Path()
      ..moveTo(68, 20)
      ..quadraticBezierTo(70, 10, 60, 10)
      ..quadraticBezierTo(55, 10, 55, 18);
    canvas.drawPath(leftLoop, strokePaint);
    canvas.drawPath(rightLoop, strokePaint);

    // 목 부분 상단 곡선(연보라, opacity 0.9).
    final neckTopPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = _lavender.withValues(alpha: 0.9)
      ..strokeCap = StrokeCap.round;
    final neckTopCurve = Path()
      ..moveTo(25, 26)
      ..quadraticBezierTo(50, 18, 75, 26);
    canvas.drawPath(neckTopCurve, neckTopPaint);

    // 목(neck) 그라디언트 밴드.
    final neckPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          _deepIndigo.withValues(alpha: 0.7),
          _periwinkle.withValues(alpha: 0.85),
        ],
      ).createShader(const Rect.fromLTWH(28, 32, 44, 8));
    final neckPath = Path()
      ..moveTo(28, 32)
      ..quadraticBezierTo(50, 26, 72, 32)
      ..lineTo(68, 40)
      ..quadraticBezierTo(50, 36, 32, 40)
      ..close();
    canvas.drawPath(neckPath, neckPaint);
    final neckBorderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = _periwinkle.withValues(alpha: 0.7);
    canvas.drawPath(neckPath, neckBorderPaint);

    // 목 주름선 3개(검정 옅은 opacity).
    final creasePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = Colors.black.withValues(alpha: 0.2);
    canvas.drawLine(const Offset(38, 30), const Offset(37, 40), creasePaint);
    canvas.drawLine(const Offset(50, 28), const Offset(50, 40), creasePaint);
    canvas.drawLine(const Offset(62, 30), const Offset(63, 40), creasePaint);

    // 몸통(body) 그라디언트(0.3, 1 방향 - 대각선에 가까운 세로).
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: const Alignment(0, -1),
        end: const Alignment(0.3, 1),
        colors: [
          _lavender.withValues(alpha: 0.5),
          _periwinkle.withValues(alpha: 0.9),
          _deepIndigo.withValues(alpha: 0.85),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(const Rect.fromLTWH(18, 40, 64, 60));
    final bodyPath = Path()
      ..moveTo(32, 40)
      ..quadraticBezierTo(50, 36, 68, 40)
      ..lineTo(78, 60)
      ..quadraticBezierTo(82, 90, 50, 100)
      ..quadraticBezierTo(18, 90, 22, 60)
      ..close();
    canvas.drawPath(bodyPath, bodyPaint);
    final bodyBorderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = _periwinkle.withValues(alpha: 0.9);
    canvas.drawPath(bodyPath, bodyBorderPaint);

    // 하이라이트 곡선(흰색, 왼쪽 사선).
    final highlightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.35);
    final highlightCurve = Path()
      ..moveTo(30, 50)
      ..quadraticBezierTo(26, 68, 32, 84);
    canvas.drawPath(highlightCurve, highlightPaint);

    // "福" 글자(중앙, 금색 + 은은한 발광).
    final fuPainter = TextPainter(
      text: TextSpan(
        text: '福',
        style: TextStyle(
          color: _gold.withValues(alpha: 0.95),
          fontSize: 16,
          fontWeight: FontWeight.w900,
          fontFamily: 'serif',
          shadows: [
            Shadow(color: _gold.withValues(alpha: 0.8), blurRadius: 8),
          ],
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    fuPainter.paint(
      canvas,
      Offset(50 - fuPainter.width / 2, 72 - fuPainter.height / 2),
    );

    // 하단 술(tassel) - 세로선 + 매듭 점.
    final tasselPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = _gold.withValues(alpha: 0.9);
    canvas.drawLine(const Offset(50, 100), const Offset(50, 108), tasselPaint);
    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = _gold.withValues(alpha: 0.95);
    canvas.drawCircle(const Offset(50, 108), 2, dotPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant WelcomeRewardPouchPainter oldDelegate) => false;
}

/// [Phase C] `.pouch-hero` 컨테이너 — halo(radial gradient, 2.6s pulse) +
/// 복주머니 SVG(3s bob: translateY+rotate 왕복) 조합.
class WelcomeRewardPouchHero extends StatefulWidget {
  final double size;

  const WelcomeRewardPouchHero({super.key, this.size = 130});

  @override
  State<WelcomeRewardPouchHero> createState() =>
      _WelcomeRewardPouchHeroState();
}

class _WelcomeRewardPouchHeroState extends State<WelcomeRewardPouchHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // halo-pulse 2.6s + pouch-bob 3s를 하나의 컨트롤러로 근사(둘 다 ease-in-out
    // 왕복이라 위상만 살짝 다르게 둬도 시각적 차이가 크지 않다).
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final haloSize = widget.size * 1.4;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        final haloScale = 1.0 + 0.12 * t;
        final haloOpacity = 0.75 + 0.25 * t;
        final bobY = -5.0 * t;
        final bobRotate = (-3 + 6 * t) * (pi / 180);
        return SizedBox(
          width: haloSize,
          height: haloSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: haloOpacity,
                child: Transform.scale(
                  scale: haloScale,
                  child: Container(
                    width: haloSize,
                    height: haloSize,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Color(0x4DF5D97A),
                          Color(0x1FF5D97A),
                          Color(0x00F5D97A),
                        ],
                        stops: [0.0, 0.4, 0.7],
                      ),
                    ),
                  ),
                ),
              ),
              Transform.translate(
                offset: Offset(0, bobY),
                child: Transform.rotate(
                  angle: bobRotate,
                  child: SizedBox(
                    width: widget.size,
                    height: widget.size * 110 / 100,
                    child: CustomPaint(
                      painter: const WelcomeRewardPouchPainter(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
