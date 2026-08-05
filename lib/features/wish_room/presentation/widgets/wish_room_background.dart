import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/wish_room_theme.dart';

/// [소원방 Riverpod 실험판] 별빛/안개 반짝임 배경.
///
/// 단 하나의 AnimationController(repeat)를 여러 별빛 Dot이 공유하고,
/// 전체를 RepaintBoundary로 감싸 메인 콘텐츠(CustomScrollView) rebuild와
/// 페인팅을 분리한다. sparkleLevel이 높을수록(연속 기도일수가 쌓일수록)
/// 반짝임 개수/강도가 점진적으로 늘어난다.
class WishRoomBackground extends StatefulWidget {
  final double sparkleLevel; // 0.0 ~ 1.0

  const WishRoomBackground({super.key, this.sparkleLevel = 0.3});

  @override
  State<WishRoomBackground> createState() => _WishRoomBackgroundState();
}

class _WishRoomBackgroundState extends State<WishRoomBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_StarSeed> _seeds;

  static const int _maxStars = 24;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    final rng = Random(7);
    _seeds = List.generate(
      _maxStars,
      (i) => _StarSeed(
        dx: rng.nextDouble(),
        dy: rng.nextDouble(),
        phase: rng.nextDouble(),
        size: 1.5 + rng.nextDouble() * 2.0,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibleStars = (8 + widget.sparkleLevel * (_maxStars - 8)).round();

    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: WishRoomColors.backgroundGradient,
            ),
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: _StarfieldPainter(
                  seeds: _seeds.take(visibleStars).toList(),
                  progress: _controller.value,
                  intensity: widget.sparkleLevel,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StarSeed {
  final double dx;
  final double dy;
  final double phase;
  final double size;

  const _StarSeed({
    required this.dx,
    required this.dy,
    required this.phase,
    required this.size,
  });
}

class _StarfieldPainter extends CustomPainter {
  final List<_StarSeed> seeds;
  final double progress;
  final double intensity;

  _StarfieldPainter({
    required this.seeds,
    required this.progress,
    required this.intensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final seed in seeds) {
      final twinkle = (sin((progress + seed.phase) * 2 * pi) + 1) / 2;
      final alpha = (0.15 + 0.5 * twinkle * (0.4 + intensity)).clamp(0.0, 0.9);
      paint.color = WishRoomColors.goldSoft.withValues(alpha: alpha);
      canvas.drawCircle(
        Offset(seed.dx * size.width, seed.dy * size.height),
        seed.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StarfieldPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.intensity != intensity;
}
