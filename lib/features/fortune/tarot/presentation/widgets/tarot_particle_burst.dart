import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';

/// [AI 타로 리딩 UX/UI 개선 §4] "별가루 폭발" - 카드 공개 순간 방사형으로
/// 퍼지는 별가루 파티클. `send_bok_success_dialog.dart`의 `_SparkleSpec`
/// 방사형 파티클 패턴(각도+거리+지연)을 그대로 재사용해 신규 애니메이션
/// 기법을 추가하지 않는다(기존 패턴 재사용 원칙).
///
/// [progress]는 외부 [AnimationController]의 0.0~1.0 값을 그대로 전달받는
/// "제어형(controlled)" 위젯이다(자체 컨트롤러를 새로 만들지 않고, 결과 화면의
/// 단일 시네마틱 타임라인에 종속시켜 60fps 성능/타이밍 동기화를 보장한다).
class TarotParticleBurst extends StatelessWidget {
  final double progress; // 0.0 ~ 1.0
  final int count;
  final double maxDistance;
  const TarotParticleBurst({
    super.key,
    required this.progress,
    this.count = 36,
    this.maxDistance = 160,
  });

  @override
  Widget build(BuildContext context) {
    // [§11 P6] 리빌 오버레이 재생 중(약 0.27초, burstProgress 0→1) 매
    // 프레임 repaint되므로, 형제로 놓이는 카드/텍스트 레이어의 repaint와
    // 서로 전파되지 않도록 RepaintBoundary로 격리한다.
    return RepaintBoundary(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _BurstPainter(
            progress: progress,
            count: count,
            maxDistance: maxDistance,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  final double progress;
  final int count;
  final double maxDistance;
  static final List<_ParticleSpec> _specs = List.generate(60, (i) {
    final rand = Random(500 + i);
    return _ParticleSpec(
      angle: rand.nextDouble() * 2 * pi,
      distanceFactor: 0.5 + rand.nextDouble() * 0.5,
      size: 2.0 + rand.nextDouble() * 4,
      delay: rand.nextDouble() * 0.3,
      gold: rand.nextBool(),
    );
  });

  _BurstPainter({
    required this.progress,
    required this.count,
    required this.maxDistance,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint();
    for (var i = 0; i < count && i < _specs.length; i++) {
      final spec = _specs[i];
      final t = ((progress - spec.delay) / (1 - spec.delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final eased = Curves.easeOut.transform(t);
      final distance = maxDistance * spec.distanceFactor * eased;
      final opacity = (1 - eased) * 0.95;
      final offset = Offset(
        center.dx + cos(spec.angle) * distance,
        center.dy + sin(spec.angle) * distance,
      );
      paint.color = (spec.gold ? AppColors.secondaryLight : Colors.white)
          .withValues(alpha: opacity.clamp(0.0, 1.0));
      canvas.drawCircle(offset, spec.size * (1 - eased * 0.3), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _ParticleSpec {
  final double angle;
  final double distanceFactor;
  final double size;
  final double delay;
  final bool gold;
  const _ParticleSpec({
    required this.angle,
    required this.distanceFactor,
    required this.size,
    required this.delay,
    required this.gold,
  });
}
