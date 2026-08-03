import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// [Fortune Fusion 디자인 우선 리디자인 프롬프트] §8 그래픽 스타일
///
/// 화이트 프리미엄 화면에서 쓰는 가볍고 깨끗한 감성 그래픽 모음.
/// subtle gradient blobs, tiny stars, moon icon, glow rings, soft sparkles.
/// 과한 3D 대신 아주 옅은 오파시티 도형으로 "공기감"을 표현한다.

/// [Fortune Fusion 디자인 우선 리디자인 프롬프트] §9 애니메이션 방향
/// "카드 등장 시 부드러운 fade + slight up motion"을 재사용 가능한 래퍼로 표준화.
/// [delay]를 다르게 주면 섹션들이 순차적으로(stagger) 나타나는 효과를 낼 수 있다.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 420),
    this.offsetY = 14,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offsetY;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: Offset(0, widget.offsetY),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
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
      builder: (context, child) => Opacity(
        opacity: _fade.value,
        child: Transform.translate(offset: _slide.value, child: child),
      ),
      child: widget.child,
    );
  }
}

/// 카드 배경 뒤에 까는 은은한 그라디언트 블롭(원형 번짐).
class SoftGradientBlob extends StatelessWidget {
  const SoftGradientBlob({
    super.key,
    this.size = 140,
    this.color = AppColors.premiumMainPurple,
    this.opacity = 0.14,
  });

  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: opacity), color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

/// 은은하게 떠다니는(위아래로 살짝 흔들리는) 초승달 아이콘.
class FloatingMoon extends StatefulWidget {
  const FloatingMoon({super.key, this.size = 28, this.color});

  final double size;
  final Color? color;

  @override
  State<FloatingMoon> createState() => _FloatingMoonState();
}

class _FloatingMoonState extends State<FloatingMoon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
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
      builder: (context, child) {
        final dy = math.sin(_controller.value * math.pi) * 4;
        return Transform.translate(
          offset: Offset(0, -dy),
          child: Icon(
            Icons.nightlight_round,
            size: widget.size,
            color: widget.color ?? AppColors.premiumSoftGold,
          ),
        );
      },
    );
  }
}

/// 아주 약하게 반짝이는(opacity pulse) 작은 별 아이콘. 복주머니 배지 등에 사용.
class SparkleDot extends StatefulWidget {
  const SparkleDot({super.key, this.size = 14, this.color});

  final double size;
  final Color? color;

  @override
  State<SparkleDot> createState() => _SparkleDotState();
}

class _SparkleDotState extends State<SparkleDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: Icon(
        Icons.auto_awesome_rounded,
        size: widget.size,
        color: widget.color ?? AppColors.premiumSoftGold,
      ),
    );
  }
}

/// 점선 궤도(dotted orbit) 장식 - 히어로 카드 배경 등에 사용하는 얇은 원형 점선.
class DottedOrbit extends StatelessWidget {
  const DottedOrbit({super.key, this.size = 160, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size(size, size),
        painter: _DottedOrbitPainter(
          color: color ?? AppColors.premiumMainPurple.withValues(alpha: 0.18),
        ),
      ),
    );
  }
}

class _DottedOrbitPainter extends CustomPainter {
  _DottedOrbitPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    final radius = size.width / 2;
    final center = Offset(radius, radius);
    const dashCount = 36;
    for (int i = 0; i < dashCount; i++) {
      final angle = (i / dashCount) * 2 * math.pi;
      final start = Offset(
        center.dx + radius * 0.94 * math.cos(angle),
        center.dy + radius * 0.94 * math.sin(angle),
      );
      final end = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      canvas.drawLine(start, end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DottedOrbitPainter oldDelegate) => false;
}

/// 작은 반짝이는 별들을 무작위 위치에 흩뿌려 배치하는 오버레이(히어로 카드용).
class TinyStarsOverlay extends StatelessWidget {
  const TinyStarsOverlay({super.key, this.count = 6});

  final int count;

  @override
  Widget build(BuildContext context) {
    final random = math.Random(42); // 고정 시드로 항상 같은 배치(리렌더 시 흔들림 방지)
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth.isFinite ? constraints.maxWidth : 200.0;
          final h = constraints.maxHeight.isFinite ? constraints.maxHeight : 120.0;
          return Stack(
            children: List.generate(count, (i) {
              final top = random.nextDouble() * 0.8 * h;
              final left = random.nextDouble() * 0.9 * w;
              final size = 6.0 + random.nextDouble() * 6;
              return Positioned(
                top: top,
                left: left,
                child: Icon(
                  Icons.star_rounded,
                  size: size,
                  color: AppColors.premiumSoftGold.withValues(alpha: 0.5),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
