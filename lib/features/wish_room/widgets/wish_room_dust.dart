import 'package:flutter/material.dart';

import '../theme/wish_room_theme.dart';

/// [디자인 핸드오프 적용 — "마법진이 소환되는 신전"] 상승하는 먼지 파티클
/// (Dust) 위젯.
///
/// `design_handoff/sigils.jsx`의 `Dust({count, color})`를 재구현. 원본은
/// 각 파티클에 `dust-float {dur}s ease-out {delay}s infinite` 애니메이션을
/// 개별 적용한다(파티클마다 dur/delay/size가 살짝 다르게 결정론적으로
/// 계산됨). `anim-dramatic`에서는 `!important`로 duration이 4s로 강제된다
/// (README: "Fast rising particles").
///
/// [`wish-styles.css`] `@keyframes dust-float`: translateY(0 → -120px) +
/// translateX(0 → 20px), opacity 0→0.8→0(대략 10%~90% 구간에서 최대).
class WishRoomDust extends StatefulWidget {
  final int count;
  final Color color;

  /// anim-dramatic에서는 4s로 고정(빠른 파티클). 다른 변형을 나중에
  /// 지원하려면 이 값을 바꿔서 재사용할 수 있다.
  final Duration duration;

  const WishRoomDust({
    super.key,
    this.count = 8,
    this.color = WishRoomColors.glow,
    this.duration = const Duration(seconds: 4),
  });

  @override
  State<WishRoomDust> createState() => _WishRoomDustState();
}

class _WishRoomDustState extends State<WishRoomDust>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_DustSeed> _seeds;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
    _seeds = List.generate(widget.count, (i) {
      // 원본 JSX와 동일한 결정론적 배치 공식을 사용해 시각적으로 대응시킴.
      final left = (i * 13 + 7) % 100 / 100.0;
      final delay = (i * 0.7) % (widget.duration.inMilliseconds / 1000.0);
      final size = 2.0 + (i % 3);
      return _DustSeed(left: left, delayFraction: delay, size: size);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: _DustPainter(
                seeds: _seeds,
                progress: _controller.value,
                periodSeconds: widget.duration.inMilliseconds / 1000.0,
                color: widget.color,
              ),
              size: Size.infinite,
            );
          },
        ),
      ),
    );
  }
}

class _DustSeed {
  final double left; // 0~1
  final double delayFraction; // seconds
  final double size;

  const _DustSeed({
    required this.left,
    required this.delayFraction,
    required this.size,
  });
}

class _DustPainter extends CustomPainter {
  final List<_DustSeed> seeds;
  final double progress; // 0~1, 한 주기(periodSeconds) 내 진행도
  final double periodSeconds;
  final Color color;

  _DustPainter({
    required this.seeds,
    required this.progress,
    required this.periodSeconds,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final elapsedNow = progress * periodSeconds;
    final paint = Paint()..style = PaintingStyle.fill;

    for (final seed in seeds) {
      // 각 파티클이 delay만큼 늦게 시작해 무한 반복되는 것을 로컬 시간
      // 진행도(0~1)로 환산.
      final localT =
          ((elapsedNow - seed.delayFraction) % periodSeconds) / periodSeconds;
      final t = localT < 0 ? localT + 1 : localT;

      // opacity: 0 → 0.8(10~90%) → 0 근사.
      double alpha;
      if (t < 0.1) {
        alpha = t / 0.1 * 0.8;
      } else if (t < 0.9) {
        alpha = 0.8;
      } else {
        alpha = (1 - t) / 0.1 * 0.8;
      }

      final dy = size.height * 0.9 - t * (size.height * 0.9 + 120);
      final dx = seed.left * size.width + t * 20;

      paint.shader = RadialGradient(
        colors: [
          color.withValues(alpha: alpha.clamp(0.0, 1.0)),
          color.withValues(alpha: 0),
        ],
      ).createShader(
        Rect.fromCircle(center: Offset(dx, dy), radius: seed.size),
      );
      canvas.drawCircle(Offset(dx, dy), seed.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DustPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
