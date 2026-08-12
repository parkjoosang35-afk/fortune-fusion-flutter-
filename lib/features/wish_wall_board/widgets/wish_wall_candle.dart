import 'package:flutter/material.dart';

/// 촛불(Candle) — 옛 "신통방통 소원방"(wish_room) 홈/상세 화면의 상징 모티프.
///
/// [디자인 히스토리] 옛 소원방은 "소원을 밝힌다"는 서사를 촛불로 표현했다
/// (홈: 밝힌 소원 개수 = 켜진 촛불, 상세: 밝힌 일수 = 촛농이 흘러내린 정도).
/// 화폐 시스템과 무관한 순수 시각 요소라 그대로 이식한다.
class WishWallCandle extends StatelessWidget {
  const WishWallCandle({
    super.key,
    this.size = 60,
    this.color = const Color(0xFFF5D97A),
    this.melted = 0,
    this.lit = true,
  });

  final double size;
  final Color color;
  final double melted;
  final bool lit;

  @override
  Widget build(BuildContext context) {
    final w = size;
    final h = size * 1.8;
    final bodyW = size * 0.55;
    final bodyH = size * 1.1 - melted * 0.4;

    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          if (lit)
            Positioned(
              top: 0,
              child: SizedBox(
                width: size * 0.5,
                height: size * 0.7,
                child: CustomPaint(painter: _FlamePainter(color: color)),
              ),
            ),
          Positioned(
            top: size * 0.68,
            child: Container(
              width: 1.5,
              height: 6,
              decoration: BoxDecoration(
                color: const Color(0xFF3A2515),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
          Positioned(
            top: size * 0.72,
            child: Container(
              width: bodyW,
              height: bodyH < 0 ? 0 : bodyH,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.15),
                    color,
                    color,
                    Colors.black.withValues(alpha: 0.2),
                  ],
                  stops: const [0.0, 0.3, 0.7, 1.0],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(bodyW * 0.15),
                  topRight: Radius.circular(bodyW * 0.15),
                  bottomLeft: const Radius.circular(4),
                  bottomRight: const Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 20,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlamePainter extends CustomPainter {
  _FlamePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 20.0;
    canvas.save();
    canvas.scale(scale, scale);
    final paint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, 0.4),
        radius: 0.5,
        colors: [
          const Color(0xFFFFF8DD),
          const Color(0xFFFFD47A),
          color.withValues(alpha: 0.3),
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(const Rect.fromLTWH(0, 0, 20, 30));
    final path = Path()
      ..moveTo(10, 2)
      ..cubicTo(14, 10, 16, 16, 14, 22)
      ..cubicTo(13, 26, 11, 28, 10, 28)
      ..cubicTo(9, 28, 7, 26, 6, 22)
      ..cubicTo(4, 16, 6, 10, 10, 2)
      ..close();
    canvas.drawPath(path, paint);
    final corePaint = Paint()
      ..color = const Color(0xFF4A2B8A).withValues(alpha: 0.5);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(10, 22), width: 6, height: 8),
      corePaint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FlamePainter oldDelegate) =>
      oldDelegate.color != color;
}
