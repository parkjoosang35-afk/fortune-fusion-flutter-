import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/wish_room_theme.dart';

/// [디자인 핸드오프 적용 — "마법진이 소환되는 신전"] 촛불(Candle) 위젯.
///
/// `design_handoff/sigils.jsx`의 `Candle({size, color, melted, lit})`를
/// Flutter로 재구현했다. 원본은 CSS로 그린 몸통(선형 그라디언트 + 글로우
/// box-shadow) 위에 SVG teardrop 불꽃을 올린 구조 — 여기서는 몸통을
/// `Container`(gradient+boxShadow)로, 불꽃을 `CustomPaint`(teardrop Path +
/// radial gradient)로 각각 구현해 원본 레이어 구조를 그대로 따른다.
///
/// [애니메이션 — anim-dramatic] README: flame flicker 1.8s ease-in-out
/// 무한 반복 (V1은 3.4s로 더 느림). scale + translateY + opacity의 미세한
/// 노이즈로 살랑이는 불꽃을 표현한다.
class WishRoomCandle extends StatefulWidget {
  final double size;
  final Color color;

  /// 촛불이 녹아든 정도(0~1). 값이 클수록 몸통이 짧아진다.
  final double melted;
  final bool lit;

  /// anim-dramatic(1.8s) vs anim-gentle(3.4s) 등 flicker 주기 커스터마이즈.
  final Duration flickerDuration;

  const WishRoomCandle({
    super.key,
    this.size = 60,
    this.color = WishRoomColors.glow,
    this.melted = 0,
    this.lit = true,
    this.flickerDuration = const Duration(milliseconds: 1800),
  });

  @override
  State<WishRoomCandle> createState() => _WishRoomCandleState();
}

class _WishRoomCandleState extends State<WishRoomCandle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flicker;

  @override
  void initState() {
    super.initState();
    _flicker = AnimationController(
      vsync: this,
      duration: widget.flickerDuration,
    )..repeat();
  }

  @override
  void dispose() {
    _flicker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.size;
    final h = widget.size * 1.8;
    final bodyW = widget.size * 0.55;
    final bodyH = widget.size * 1.1 - widget.melted * 0.4;

    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          if (widget.lit)
            AnimatedBuilder(
              animation: _flicker,
              builder: (context, _) {
                // flame-flicker 4단계(scale/translateY/opacity 미세 노이즈)를
                // 사인파 조합으로 근사.
                final t = _flicker.value * 2 * pi;
                final scale = 1.0 + 0.04 * sin(t * 2.3);
                final dy = sin(t * 1.7) * widget.size * 0.015;
                final alpha = 0.92 + 0.08 * sin(t * 3.1);
                return Transform.translate(
                  offset: Offset(0, dy),
                  child: Transform.scale(
                    scale: scale,
                    child: Opacity(
                      opacity: alpha.clamp(0.0, 1.0),
                      child: SizedBox(
                        width: widget.size * 0.5,
                        height: widget.size * 0.7,
                        child: CustomPaint(
                          painter: _FlamePainter(color: widget.color),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          // 심지
          Positioned(
            top: widget.size * 0.68,
            child: Container(
              width: 1.5,
              height: 6,
              decoration: BoxDecoration(
                color: const Color(0xFF3A2515),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
          // 몸통
          Positioned(
            top: widget.size * 0.72,
            child: Container(
              width: bodyW,
              height: bodyH,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.white.withValues(alpha: widget.lit ? 0.15 : 0.05),
                    widget.color.withValues(alpha: widget.lit ? 1.0 : 0.4),
                    widget.color.withValues(alpha: widget.lit ? 1.0 : 0.4),
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
                boxShadow: widget.lit
                    ? [
                        BoxShadow(
                          color: widget.color.withValues(alpha: 0.4),
                          blurRadius: 20,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 촛불 불꽃 teardrop SVG path를 재현한 페인터.
/// 원본 sigils.jsx viewBox 0 0 20 30, path:
/// "M 10,2 C 14,10 16,16 14,22 C 13,26 11,28 10,28 C 9,28 7,26 6,22 C 4,16 6,10 10,2 Z"
class _FlamePainter extends CustomPainter {
  final Color color;

  const _FlamePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 20.0;
    final sy = size.height / 30.0;
    final path = Path()
      ..moveTo(10 * sx, 2 * sy)
      ..cubicTo(14 * sx, 10 * sy, 16 * sx, 16 * sy, 14 * sx, 22 * sy)
      ..cubicTo(13 * sx, 26 * sy, 11 * sx, 28 * sy, 10 * sx, 28 * sy)
      ..cubicTo(9 * sx, 28 * sy, 7 * sx, 26 * sy, 6 * sx, 22 * sy)
      ..cubicTo(4 * sx, 16 * sy, 6 * sx, 10 * sy, 10 * sx, 2 * sy)
      ..close();

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final gradient = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.0, 0.4),
        radius: 0.8,
        colors: [
          const Color(0xFFFFF8DD),
          const Color(0xFFFFD47A),
          color.withValues(alpha: 0.3),
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(rect);
    canvas.drawPath(path, gradient);

    // 심지 그림자(불꽃 하단의 작은 어두운 타원)
    final shadowPaint = Paint()
      ..color = const Color(0xFF4A2B8A).withValues(alpha: 0.5);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(10 * sx, 22 * sy),
        width: 6 * sx,
        height: 8 * sy,
      ),
      shadowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _FlamePainter oldDelegate) =>
      oldDelegate.color != color;
}
