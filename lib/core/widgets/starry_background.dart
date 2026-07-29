import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// [Fortune Fusion UI 리뉴얼 프롬프트] §2-3 StarryBackground - 별 배경 위젯
///
/// 화면 전체에 은은하게 반짝이는 별 파티클을 그리는 배경 위젯.
/// 3~5개의 큰 별(보라빛 20%) + 30~50개의 작은 별(흰색 15%)을 랜덤 배치하고
/// 2~4초 주기로 페이드(반짝임) 애니메이션을 적용한다.
///
/// 사용 예:
/// ```dart
/// Stack(
///   children: [
///     const Positioned.fill(child: StarryBackground()),
///     ...실제 콘텐츠...
///   ],
/// )
/// ```
class StarryBackground extends StatefulWidget {
  const StarryBackground({
    super.key,
    this.starCount = 40,
    this.bigStarCount = 4,
    this.backgroundColor = AppColors.bgPrimary,
  });

  final int starCount;
  final int bigStarCount;
  final Color backgroundColor;

  @override
  State<StarryBackground> createState() => _StarryBackgroundState();
}

class _StarryBackgroundState extends State<StarryBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Star> _stars;

  @override
  void initState() {
    super.initState();
    final rnd = Random(42);
    _stars = [
      for (int i = 0; i < widget.starCount; i++)
        _Star(
          dx: rnd.nextDouble(),
          dy: rnd.nextDouble(),
          radius: 0.6 + rnd.nextDouble() * 1.2,
          color: Colors.white.withValues(alpha: 0.15),
          phase: rnd.nextDouble(),
          period: 2 + rnd.nextDouble() * 2,
        ),
      for (int i = 0; i < widget.bigStarCount; i++)
        _Star(
          dx: rnd.nextDouble(),
          dy: rnd.nextDouble(),
          radius: 2.5 + rnd.nextDouble() * 2,
          color: AppColors.accentPurple.withValues(alpha: 0.2),
          phase: rnd.nextDouble(),
          period: 3 + rnd.nextDouble() * 2,
        ),
    ];
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.backgroundColor,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            size: Size.infinite,
            painter: _StarryPainter(stars: _stars, time: _controller.value * 8),
          );
        },
      ),
    );
  }
}

class _Star {
  _Star({
    required this.dx,
    required this.dy,
    required this.radius,
    required this.color,
    required this.phase,
    required this.period,
  });

  final double dx;
  final double dy;
  final double radius;
  final Color color;
  final double phase;
  final double period;
}

class _StarryPainter extends CustomPainter {
  _StarryPainter({required this.stars, required this.time});

  final List<_Star> stars;
  final double time;

  @override
  void paint(Canvas canvas, Size size) {
    for (final star in stars) {
      final t = ((time + star.phase * star.period) % star.period) / star.period;
      // 0.3 ~ 1.0 사이를 오가는 사인파 반짝임
      final opacity = 0.3 + 0.7 * (0.5 - 0.5 * cos(t * 2 * pi));
      final paint = Paint()
        ..color = star.color.withValues(alpha: star.color.a * opacity);
      canvas.drawCircle(
        Offset(star.dx * size.width, star.dy * size.height),
        star.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StarryPainter oldDelegate) =>
      oldDelegate.time != time;
}
