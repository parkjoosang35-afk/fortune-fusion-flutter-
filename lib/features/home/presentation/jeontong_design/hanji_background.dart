// ============================================================
// 한지 배경 (정통사주 화면 공용)
// - 두 개의 방사형 그라디언트 + 한지 종이 결 + 고정 각도의 마법진(sigil)
// 원본: flutter_handoff.zip widgets/hanji_background.dart. 시각 요소는
// 100% 동일하되, 아래 이유로 무한 반복 [AnimationController]는 제거하고
// 고정 각도(-0.08rad)로 정적 렌더링한다.
//
// [테스트 안정성 원칙] 원본의 220초 주기 `AnimationController(...)..repeat()`
// 를 그대로 쓰면 `WidgetTester.pumpAndSettle()`이 "스케줄된 프레임이 완전히
// 사라질 때까지" 기다리는데, 반복 애니메이션은 절대 사라지지 않아 무한
// 대기(테스트 타임아웃)로 이어진다. 이 배경은
// `jeontong_eighty_result_bookmark_toggle_test.dart`/
// `jeontong_eighty_result_frame_bench_test.dart`가 이미 `pumpAndSettle()`을
// 사용 중인 [JeontongEightyResultScreen]에 이식되므로, 애니메이션을
// 정적으로 바꿔 기존 테스트를 절대 깨지 않게 한다(기능 변경 없음 —
// 220초 회전은 육안으로 거의 감지되지 않는 매우 느린 장식 요소였다).
// ============================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'hanji_design_tokens.dart';

class HanjiBackground extends StatelessWidget {
  final double sigilOpacity;
  final Widget child;

  const HanjiBackground({
    super.key,
    this.sigilOpacity = 0.14,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [HanjiColors.bg1, HanjiColors.bg2],
              ),
            ),
            child: CustomPaint(painter: _HanjiPainter()),
          ),
        ),
        Positioned(
          top: -80,
          left: 0,
          right: 0,
          child: Center(
            child: Transform.rotate(
              angle: -0.08,
              child: CustomPaint(
                size: const Size(420, 420),
                painter: _SigilPainter(opacity: sigilOpacity),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _HanjiPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final warmPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.6, -0.8),
        radius: 1.1,
        colors: [
          const Color(0xFFD97941).withValues(alpha: 0.10),
          const Color(0xFFD97941).withValues(alpha: 0.0),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, warmPaint);

    final coolPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.7, 0.7),
        radius: 1.1,
        colors: [
          const Color(0xFF7BA896).withValues(alpha: 0.09),
          const Color(0xFF7BA896).withValues(alpha: 0.0),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, coolPaint);

    final grain = Paint()
      ..color = const Color(0xFF8B5A2B).withValues(alpha: 0.04)
      ..strokeWidth = 1;
    const step = 4.0;
    for (double y = -size.height; y < size.height * 2; y += step) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y + size.height * 0.6),
        grain,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HanjiPainter oldDelegate) => false;
}

class _SigilPainter extends CustomPainter {
  final double opacity;
  _SigilPainter({required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.shortestSide / 2;

    Paint stroke(double alpha, double w) => Paint()
      ..color = HanjiColors.sigil.withValues(alpha: opacity * alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w;

    canvas.drawCircle(center, r * 0.95, stroke(1.0, 0.6));
    canvas.drawCircle(center, r * 0.90, stroke(0.5, 0.4));

    for (int i = 0; i < 36; i++) {
      final a = i * math.pi * 2 / 36;
      final p1 = center + Offset(math.cos(a), math.sin(a)) * r * 0.90;
      final p2 = center + Offset(math.cos(a), math.sin(a)) * r * 0.95;
      canvas.drawLine(p1, p2, stroke(0.8, 0.5));
    }

    final hexR = r * 0.55;
    final tri1 = Path();
    final tri2 = Path();
    for (int i = 0; i < 3; i++) {
      final a1 = -math.pi / 2 + i * (2 * math.pi / 3);
      final a2 = math.pi / 2 + i * (2 * math.pi / 3);
      final p1 = center + Offset(math.cos(a1), math.sin(a1)) * hexR;
      final p2 = center + Offset(math.cos(a2), math.sin(a2)) * hexR;
      if (i == 0) {
        tri1.moveTo(p1.dx, p1.dy);
        tri2.moveTo(p2.dx, p2.dy);
      } else {
        tri1.lineTo(p1.dx, p1.dy);
        tri2.lineTo(p2.dx, p2.dy);
      }
    }
    tri1.close();
    tri2.close();
    canvas.drawPath(tri1, stroke(0.5, 0.5));
    canvas.drawPath(tri2, stroke(0.5, 0.5));

    canvas.drawCircle(center, r * 0.27, stroke(1.0, 0.6));
    canvas.drawCircle(center, r * 0.22, stroke(0.5, 0.4));

    final starPath = Path();
    for (int i = 0; i < 10; i++) {
      final rad = i.isEven ? r * 0.12 : r * 0.05;
      final a = -math.pi / 2 + i * math.pi / 5;
      final p = center + Offset(math.cos(a), math.sin(a)) * rad;
      if (i == 0) {
        starPath.moveTo(p.dx, p.dy);
      } else {
        starPath.lineTo(p.dx, p.dy);
      }
    }
    starPath.close();
    canvas.drawPath(
      starPath,
      Paint()..color = HanjiColors.sigil.withValues(alpha: opacity * 0.6),
    );
  }

  @override
  bool shouldRepaint(covariant _SigilPainter oldDelegate) =>
      oldDelegate.opacity != opacity;
}
