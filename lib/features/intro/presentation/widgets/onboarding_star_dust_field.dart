import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../intro_palette.dart';

/// [온보딩 전면 교체 2026-11 — design_handoff_onboarding_v2.zip 반영]
/// `Onboarding v2.html`의 배경 레이어 4~5번째(별 70개 + 빛 알갱이 12개)를
/// 재현한다.
///
/// README §배경: 별 70개(위치 랜덤, 지름 1.2/1.8/2.6px — 2.6px는 12%
/// 확률, 흰색, opacity .1↔.8 3~7초 랜덤), 빛 알갱이 12개(3×3px, #e8c8f5,
/// glow, 화면 아래→위로 상승, opacity 0→.7→0, 8~14초 랜덤).
///
/// [기존 `onboarding_star_petal_field.dart`와의 차이] 그 위젯은 과거(v1/v2
/// 리디자인) "별+벚꽃 꽃잎" 배경이었고 수치·규칙이 다르다(별 46개 상단
/// 70%만, 꽃잎 낙하). 이번 디자인은 꽃잎이 아니라 "빛 알갱이(dust)"가
/// 위로 떠오르는 효과이고 별 분포도 전체 화면이라 별도 파일로 신설한다.
class OnboardingStarDustField extends StatefulWidget {
  const OnboardingStarDustField({
    super.key,
    this.starCount = 70,
    this.dustCount = 12,
    this.reduceMotion = false,
    this.lowSpec = false,
  });

  final int starCount;
  final int dustCount;
  final bool reduceMotion;

  /// README "저사양 기기(deviceMemory ≤ 2)에서는 별 35개, 빛 알갱이
  /// 6개로 줄여 주세요".
  final bool lowSpec;

  @override
  State<OnboardingStarDustField> createState() =>
      _OnboardingStarDustFieldState();
}

class _OnboardingStarDustFieldState extends State<OnboardingStarDustField>
    with TickerProviderStateMixin {
  late final math.Random _rng;
  late List<_StarSpec> _stars;
  late List<_DustSpec> _dust;
  late List<AnimationController> _starControllers;
  late List<AnimationController> _dustControllers;

  @override
  void initState() {
    super.initState();
    // 결정적 배치를 위해 고정 시드를 사용(재빌드/재진입 시에도 동일 배치).
    _rng = math.Random(20261101);

    final starCount = widget.lowSpec ? 35 : widget.starCount;
    _stars = List.generate(starCount, (i) {
      final isBig = _rng.nextDouble() < 0.12;
      final size = isBig ? 2.6 : (_rng.nextDouble() < 0.5 ? 1.2 : 1.8);
      final duration = 3.0 + _rng.nextDouble() * 4.0; // 3~7s.
      return _StarSpec(
        left: _rng.nextDouble(),
        top: _rng.nextDouble(),
        size: size,
        duration: Duration(milliseconds: (duration * 1000).round()),
        startProgress: _rng.nextDouble(),
      );
    });
    _starControllers = _stars
        .map((s) => AnimationController(vsync: this, duration: s.duration))
        .toList();

    final dustCount = widget.lowSpec ? 6 : widget.dustCount;
    _dust = List.generate(dustCount, (i) {
      final duration = 8.0 + _rng.nextDouble() * 6.0; // 8~14s.
      return _DustSpec(
        left: 0.10 + _rng.nextDouble() * 0.80,
        xDrift: (_rng.nextDouble() * 60 - 30), // ±30px.
        duration: Duration(milliseconds: (duration * 1000).round()),
        startProgress: _rng.nextDouble(),
      );
    });
    _dustControllers = _dust
        .map((d) => AnimationController(vsync: this, duration: d.duration))
        .toList();

    if (widget.reduceMotion) {
      for (final c in _starControllers) {
        c.value = 0.5;
      }
      for (final c in _dustControllers) {
        c.value = 0.0;
      }
      return;
    }

    for (var i = 0; i < _starControllers.length; i++) {
      _starControllers[i].value = _stars[i].startProgress;
      _starControllers[i].repeat();
    }
    for (var i = 0; i < _dustControllers.length; i++) {
      _dustControllers[i].value = _dust[i].startProgress;
      _dustControllers[i].repeat();
    }
  }

  @override
  void dispose() {
    for (final c in _starControllers) {
      c.dispose();
    }
    for (final c in _dustControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          return Stack(
            children: [
              for (var i = 0; i < _stars.length; i++)
                _StarDot(
                  spec: _stars[i],
                  controller: _starControllers[i],
                  areaWidth: w,
                  areaHeight: h,
                ),
              for (var i = 0; i < _dust.length; i++)
                _DustParticle(
                  spec: _dust[i],
                  controller: _dustControllers[i],
                  areaWidth: w,
                  areaHeight: h,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _StarSpec {
  const _StarSpec({
    required this.left,
    required this.top,
    required this.size,
    required this.duration,
    required this.startProgress,
  });

  final double left;
  final double top;
  final double size;
  final Duration duration;
  final double startProgress;
}

/// `@keyframes twinkle{0%,100%{opacity:.1}50%{opacity:.8}}`.
class _StarDot extends StatelessWidget {
  const _StarDot({
    required this.spec,
    required this.controller,
    required this.areaWidth,
    required this.areaHeight,
  });

  final _StarSpec spec;
  final AnimationController controller;
  final double areaWidth;
  final double areaHeight;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: spec.left * areaWidth,
      top: spec.top * areaHeight,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final t = controller.value;
          final wave = (math.sin((t * 2 * math.pi) - math.pi / 2) + 1) / 2;
          final opacity = 0.1 + wave * (0.8 - 0.1);
          return Opacity(
            opacity: opacity,
            child: Container(
              width: spec.size,
              height: spec.size,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DustSpec {
  const _DustSpec({
    required this.left,
    required this.xDrift,
    required this.duration,
    required this.startProgress,
  });

  final double left;
  final double xDrift;
  final Duration duration;
  final double startProgress;
}

/// `@keyframes rise{0%{opacity:0;translate(0,0)}15%{opacity:.7}100%{opacity:0;
/// translate(x,-75dvh)}}` — 3×3px, glow 색, 아래에서 위로 상승.
class _DustParticle extends StatelessWidget {
  const _DustParticle({
    required this.spec,
    required this.controller,
    required this.areaWidth,
    required this.areaHeight,
  });

  final _DustSpec spec;
  final AnimationController controller;
  final double areaWidth;
  final double areaHeight;

  @override
  Widget build(BuildContext context) {
    final riseDistance = areaHeight * 0.75;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        double opacity;
        if (t < 0.15) {
          opacity = (t / 0.15) * 0.7;
        } else {
          opacity = 0.7 * (1 - (t - 0.15) / 0.85);
        }
        final dy = -t * riseDistance;
        final dx = t * spec.xDrift;
        return Positioned(
          left: spec.left * areaWidth,
          bottom: -10,
          child: Transform.translate(
            offset: Offset(dx, dy),
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Container(
                width: 3,
                height: 3,
                decoration: BoxDecoration(
                  color: IntroPalette.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: IntroPalette.primary.withValues(alpha: 0.9),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
