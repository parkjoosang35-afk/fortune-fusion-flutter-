import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';

/// [AI 타로 리딩 UX/UI 개선 §1/§3/§7] "살아있는" 신비 배경 - 어두운 우주 +
/// 천천히 움직이는 별빛 + 흐르는 안개 + 맥박처럼 커졌다 작아지는 중앙 빛.
///
/// 로딩 화면(§1~3, 화려하게)과 결과 화면(§7, "너무 화려하지 않게") 양쪽에서
/// [intensity]로 화려함 정도만 조절해 재사용한다(신규 배경 위젯을 화면마다
/// 따로 만들지 않는다 - 과설계 방지). 단일 [AnimationController]로 별/안개/
/// 빛맥박을 모두 구동해 성능(60fps) 부담을 최소화한다.
class TarotMysticBackground extends StatefulWidget {
  /// 0.6(결과화면, 은은하게) ~ 1.0(로딩화면, 화려하게) 권장 범위.
  final double intensity;
  const TarotMysticBackground({super.key, this.intensity = 1.0});

  @override
  State<TarotMysticBackground> createState() => _TarotMysticBackgroundState();
}

class _TarotMysticBackgroundState extends State<TarotMysticBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_StarSpec> _stars;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    final rand = Random(11);
    _stars = List.generate(70, (i) {
      return _StarSpec(
        dx: rand.nextDouble(),
        dy: rand.nextDouble(),
        size: 0.8 + rand.nextDouble() * 2.0,
        phase: rand.nextDouble(),
        driftSpeed: 0.02 + rand.nextDouble() * 0.03,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // [§11 P6] 매 프레임(20초 반복 애니메이션) 다시 그려지는 이 배경은
    // 항상 [Stack] 안에서 다른 정적 콘텐츠(카드/텍스트 등)와 형제로
    // 놓인다. `Positioned.fill`은 [Stack]이 직계 자식에서 직접 인식해야
    // 하므로 최상위에 유지하고, 그 안쪽을 RepaintBoundary로 감싸 이
    // 배경의 repaint가 형제 서브트리로 전파되지 않도록 격리한다
    // (§11 P6 "저사양 degrade" 성능 원칙).
    return Positioned.fill(
      child: RepaintBoundary(
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.2),
              radius: 1.3,
              colors: [
                AppColors.deepSpaceLight,
                AppColors.deepSpace,
                Colors.black,
              ],
            ),
          ),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                size: Size.infinite,
                painter: _MysticPainter(
                  stars: _stars,
                  t: _controller.value,
                  intensity: widget.intensity,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StarSpec {
  final double dx;
  final double dy;
  final double size;
  final double phase;
  final double driftSpeed;
  const _StarSpec({
    required this.dx,
    required this.dy,
    required this.size,
    required this.phase,
    required this.driftSpeed,
  });
}

class _MysticPainter extends CustomPainter {
  final List<_StarSpec> stars;
  final double t;
  final double intensity;
  _MysticPainter({
    required this.stars,
    required this.t,
    required this.intensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 중앙 맥박 빛(§3 "빛이 맥박처럼 커졌다 작아짐")
    final pulse = 0.5 + 0.5 * sin(t * 2 * pi);
    final glowPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              AppColors.primaryLight.withValues(
                alpha: 0.10 * intensity * (0.6 + 0.4 * pulse),
              ),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.5, size.height * 0.32),
              radius: size.shortestSide * 0.6,
            ),
          );
    canvas.drawRect(Offset.zero & size, glowPaint);

    // 흐르는 안개(§1 "은은한 안개", §3 "안개가 흐름") - 가로로 느리게 이동하는
    // 옅은 밴드 2개.
    for (var band = 0; band < 2; band++) {
      final bandT = (t + band * 0.5) % 1.0;
      final fogPaint = Paint()
        ..shader =
            LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.transparent,
                AppColors.primaryLight.withValues(alpha: 0.05 * intensity),
                Colors.transparent,
              ],
            ).createShader(
              Rect.fromLTWH(
                size.width * (bandT * 1.6 - 0.3),
                size.height * (0.2 + band * 0.35),
                size.width * 0.9,
                size.height * 0.28,
              ),
            );
      canvas.drawRect(
        Rect.fromLTWH(
          size.width * (bandT * 1.6 - 0.3),
          size.height * (0.2 + band * 0.35),
          size.width * 0.9,
          size.height * 0.28,
        ),
        fogPaint,
      );
    }

    // 별빛(§1 "별빛", §3 "별이 천천히 움직임" - 반짝임 + 미세한 수직 드리프트)
    final starPaint = Paint()..color = Colors.white;
    for (final s in stars) {
      final twinkle = (sin((t * 6 + s.phase) * 2 * pi) * 0.5 + 0.5).clamp(
        0.0,
        1.0,
      );
      final driftedY = (s.dy + t * s.driftSpeed) % 1.0;
      starPaint.color = Colors.white.withValues(
        alpha: (0.15 + twinkle * 0.65) * intensity,
      );
      canvas.drawCircle(
        Offset(s.dx * size.width, driftedY * size.height),
        s.size,
        starPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MysticPainter oldDelegate) => true;
}
