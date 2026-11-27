import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../../theme/lucky_box_tokens.dart';

/// [행운상자 - 복주머니 탭 신규 기능] dev-spec.md §3-3 파티클 파라미터를
/// 그대로 반영한 파티클 1개의 모델.
class _PouchParticle {
  final double angle; // radian
  final double radius; // 방사 거리(px)
  final double size; // 18~46px
  final double rotationDeg; // -180~180
  final double delayMs;
  final double durationMs;
  final double hue; // -20~20 (색상 변주)
  final bool lit; // 30% 확률로 발광

  const _PouchParticle({
    required this.angle,
    required this.radius,
    required this.size,
    required this.rotationDeg,
    required this.delayMs,
    required this.durationMs,
    required this.hue,
    required this.lit,
  });
}

class _Sparkle {
  final double angle;
  final double radius;
  final double size;
  final double delayMs;
  final double durationMs;

  const _Sparkle({
    required this.angle,
    required this.radius,
    required this.size,
    required this.delayMs,
    required this.durationMs,
  });
}

/// dev-spec.md §3-3 시퀀스(총 2초)를 그대로 구현한 폭발 파티클 세트.
/// [핵심] 파티클 개수/속성은 이 생성자에서 1회만 랜덤 생성하고, 매 프레임
/// 재생성하지 않는다(성능 + 애니메이션 일관성).
class PouchBurstData {
  final List<_PouchParticle> particles;
  final List<_Sparkle> sparkles;
  final double totalMs;
  final bool isJackpot;

  PouchBurstData._(
    this.particles,
    this.sparkles,
    this.totalMs,
    this.isJackpot,
  );

  /// dev-spec.md §7 항목7 "Jackpot(300) 특수 연출: 금색 파티클 배수" 채택.
  /// [isJackpot]이면 모든 파티클이 발광(lit=true)하고, 골든 스파클 개수를
  /// 24 → 48로 2배 늘려 화면을 더 풍성하게 채운다.
  factory PouchBurstData.generate({
    required int particleCount,
    required double totalMs,
    bool isJackpot = false,
  }) {
    final rng = math.Random();
    final particles = List.generate(particleCount, (i) {
      return _PouchParticle(
        angle: rng.nextDouble() * 2 * math.pi,
        radius: 60 + math.pow(rng.nextDouble(), 0.55) * 260,
        size:
            RewardConfig.particleSizeMin +
            rng.nextDouble() *
                (RewardConfig.particleSizeMax - RewardConfig.particleSizeMin),
        rotationDeg: -180 + rng.nextDouble() * 360,
        delayMs: rng.nextDouble() * 350,
        durationMs: 1600 + rng.nextDouble() * 1200,
        hue: -20 + rng.nextDouble() * 40,
        lit: isJackpot ? true : rng.nextDouble() > 0.7,
      );
    });
    final sparkleCount = isJackpot ? 48 : 24;
    final sparkles = List.generate(sparkleCount, (i) {
      return _Sparkle(
        angle: rng.nextDouble() * 2 * math.pi,
        radius: 40 + rng.nextDouble() * 220,
        size: (isJackpot ? 8 : 6) + rng.nextDouble() * 8,
        delayMs: rng.nextDouble() * 500,
        durationMs: 900 + rng.nextDouble() * 700,
      );
    });
    return PouchBurstData._(particles, sparkles, totalMs, isJackpot);
  }
}

/// [성능] CustomPainter로 구현(§5 권장: "파티클 300개 초과 시 CustomPainter
/// 필수 — Widget 방식 불가"). progress(0.0~1.0)는 burstTotal(2000ms) 전체
/// 진행률이다.
class PouchBurstPainter extends CustomPainter {
  final PouchBurstData data;
  final double progress; // 0.0 ~ 1.0 (전체 burst 진행률)

  PouchBurstPainter({required this.data, required this.progress});

  double _easeOut(double t) {
    // particleCurve: cubic-bezier(0.22, 0.61, 0.36, 1.0) 근사 — easeOutCubic으로 대체.
    final p = t.clamp(0.0, 1.0);
    return 1 - math.pow(1 - p, 3).toDouble();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final globalT = progress.clamp(0.0, 1.0);

    _paintRings(canvas, center, globalT);
    _paintFlash(canvas, center, globalT);
    _paintSparkles(canvas, center, globalT);
    _paintParticles(canvas, center, globalT);
  }

  // t=0: 중앙 flash 시작(900ms, scale 0.2→2.4, opacity 0→1→0).
  void _paintFlash(Canvas canvas, Offset center, double globalT) {
    const flashFrac = 900 / 2000;
    if (globalT > flashFrac) return;
    final localT = (globalT / flashFrac).clamp(0.0, 1.0);
    final scale = 0.2 + _easeOut(localT) * (2.4 - 0.2);
    final opacity = math.sin(math.pi * localT).clamp(0.0, 1.0);
    final radius = 46.0 * scale;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: opacity * 0.9)
      ..maskFilter = const MaskFilter.blur(ui.BlurStyle.normal, 24);
    canvas.drawCircle(center, radius, paint);
    // 잭팟은 골든 글로우 반경/강도를 키워 "터지는 순간"을 더 화려하게.
    final goldPaint = Paint()
      ..color = LuckyBoxTokens.accentGold.withValues(
        alpha: opacity * (data.isJackpot ? 0.85 : 0.6),
      )
      ..maskFilter = MaskFilter.blur(
        ui.BlurStyle.normal,
        data.isJackpot ? 48 : 36,
      );
    canvas.drawCircle(center, radius * (data.isJackpot ? 1.6 : 1.3), goldPaint);
  }

  // t=0: 3개 확장 링(stagger 0,200,400ms), 각 1.4s. border scale 0.3→7 + fade.
  void _paintRings(Canvas canvas, Offset center, double globalT) {
    const ringDurationFrac = 1400 / 2000;
    const staggerFrac = 200 / 2000;
    for (var i = 0; i < 3; i++) {
      final start = i * staggerFrac;
      final end = start + ringDurationFrac;
      if (globalT < start) continue;
      final localT = ((globalT - start) / (end - start)).clamp(0.0, 1.0);
      final scale = 0.3 + _easeOut(localT) * (7.0 - 0.3);
      final opacity = (1 - localT).clamp(0.0, 1.0);
      final radius = 40.0 * scale;
      final ringColor = data.isJackpot
          ? LuckyBoxTokens.accentGold
          : LuckyBoxTokens.accentGlow;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = data.isJackpot ? 3.2 : 2.5
        ..color = ringColor.withValues(alpha: opacity * 0.55);
      canvas.drawCircle(center, radius, paint);
    }
  }

  void _paintSparkles(Canvas canvas, Offset center, double globalT) {
    for (final s in data.sparkles) {
      final localStart = s.delayMs / data.totalMs;
      final localEnd = (s.delayMs + s.durationMs) / data.totalMs;
      if (globalT < localStart) continue;
      final localT = ((globalT - localStart) / (localEnd - localStart)).clamp(
        0.0,
        1.0,
      );
      final eased = _easeOut(localT);
      final distance = eased * s.radius;
      final pos =
          center + Offset(math.cos(s.angle), math.sin(s.angle)) * distance;
      final opacity = _fadeInOutOpacity(localT);
      if (opacity <= 0) continue;
      final paint = Paint()
        ..color = LuckyBoxTokens.accentSparkle.withValues(alpha: opacity)
        ..maskFilter = const MaskFilter.blur(ui.BlurStyle.normal, 3);
      _drawStar(canvas, pos, s.size, paint);
    }
  }

  void _paintParticles(Canvas canvas, Offset center, double globalT) {
    // t=1500ms(총 2000ms 중 75%): 잔여 파티클이 중력으로 낙하.
    final gravityT = ((globalT - 0.75) / 0.25).clamp(0.0, 1.0);
    final gravityDrop = gravityT * gravityT * 44.0;

    for (final p in data.particles) {
      final localStart = p.delayMs / data.totalMs;
      final localEnd = (p.delayMs + p.durationMs) / data.totalMs;
      if (globalT < localStart) continue;
      final localT = ((globalT - localStart) / (localEnd - localStart)).clamp(
        0.0,
        1.0,
      );
      final eased = _easeOut(localT);
      final distance = eased * p.radius;
      var pos =
          center + Offset(math.cos(p.angle), math.sin(p.angle)) * distance;
      pos += Offset(0, gravityDrop);
      final opacity = _fadeInOutOpacity(localT);
      if (opacity <= 0) continue;
      final rotation = p.rotationDeg * localT * math.pi / 180;

      if (p.lit) {
        final glowPaint = Paint()
          ..color = LuckyBoxTokens.accentGold.withValues(alpha: opacity * 0.45)
          ..maskFilter = MaskFilter.blur(ui.BlurStyle.normal, p.size * 0.5);
        canvas.drawCircle(pos, p.size * 0.75, glowPaint);
      }

      final hueShift = (p.hue / 40).clamp(-0.5, 0.5) + 0.5;
      // 잭팟은 라벤더/러스트 그라디언트 대신 골드 계열로 전 파티클을
      // 물들여 "황금 복주머니 비" 느낌을 낸다.
      final color = data.isJackpot
          ? (Color.lerp(
                  LuckyBoxTokens.accentGold,
                  LuckyBoxTokens.accentRust,
                  hueShift * 0.4,
                ) ??
                LuckyBoxTokens.accentGold)
          : (Color.lerp(
                  LuckyBoxTokens.accentGlow,
                  LuckyBoxTokens.accentRust,
                  hueShift,
                ) ??
                LuckyBoxTokens.accentGlow);

      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(rotation);
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: p.size,
        height: p.size * 0.86,
      );
      final rrect = RRect.fromRectAndRadius(
        rect,
        Radius.circular(p.size * 0.28),
      );
      final paint = Paint()..color = color.withValues(alpha: opacity);
      canvas.drawRRect(rrect, paint);
      // 복주머니 끈(윗부분 작은 사각) — 간단한 실루엣 디테일.
      final tieRect = Rect.fromCenter(
        center: Offset(0, -p.size * 0.5),
        width: p.size * 0.32,
        height: p.size * 0.18,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(tieRect, Radius.circular(p.size * 0.08)),
        Paint()..color = LuckyBoxTokens.fgOnGlow.withValues(alpha: opacity),
      );
      canvas.restore();
    }
  }

  void _drawStar(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    for (var i = 0; i < 4; i++) {
      final angle = (i * math.pi / 2);
      final outer = center + Offset(math.cos(angle), math.sin(angle)) * size;
      final innerAngle = angle + math.pi / 4;
      final inner =
          center +
          Offset(math.cos(innerAngle), math.sin(innerAngle)) * (size * 0.35);
      if (i == 0) {
        path.moveTo(outer.dx, outer.dy);
      } else {
        path.lineTo(outer.dx, outer.dy);
      }
      path.lineTo(inner.dx, inner.dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  double _fadeInOutOpacity(double localT) {
    if (localT <= 0 || localT >= 1) return 0.0;
    if (localT < 0.1) return localT / 0.1;
    if (localT > 0.75) return ((1 - localT) / 0.25).clamp(0.0, 1.0);
    return 1.0;
  }

  @override
  bool shouldRepaint(covariant PouchBurstPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
