import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../intro_palette.dart';

/// [온보딩 v2 리디자인 2026-10-18] `온보딩 v2.html`의 `.stars`(별 46개) +
/// `.petals`(꽃잎 9개) 배경 레이어를 그대로 재현한다.
///
/// [v1→v2 변경] 개수·분포·타이밍이 모두 바뀌었다(README §1/§8):
/// - 별: 60→**46개**, 전체 화면이 아니라 **상단 70% 영역에만** 분포,
///   opacity 범위 0.15~0.7(v1은 0.12~0.85), duration 고정 **4s**(v1은
///   3~7s 랜덤), delay는 `(i%7)*0.6s`로 결정적(v1은 완전 랜덤). 9개 중
///   1개는 3px+glow(v1과 동일 규칙 유지).
/// - 꽃잎: 14→**9개**, duration **10~14.8s**(v1은 9~17s), delay
///   `i*1.25s`로 결정적(v1은 음수 랜덤 delay), 낙하 거리/흔들림 폭도
///   달라졌다(원본 CSS `translate(-70px, 880px)` 고정 벡터).
/// - 터치 이벤트 없음(`IgnorePointer`), `reduceMotion`이면 정적 최종
///   상태만 그린다(README "접근성" 규정 유지).
class OnboardingStarPetalField extends StatefulWidget {
  const OnboardingStarPetalField({
    super.key,
    this.starCount = 46,
    this.petalCount = 9,
    this.reduceMotion = false,
    this.lowSpec = false,
  });

  final int starCount;
  final int petalCount;
  final bool reduceMotion;

  /// README "저사양 기기에서는 꽃잎을 6개로 줄여 주세요"(v1부터 유지된
  /// 요구사항. v2 README에는 재언급이 없지만 기존 정책을 깨지 않는다).
  final bool lowSpec;

  @override
  State<OnboardingStarPetalField> createState() =>
      _OnboardingStarPetalFieldState();
}

class _OnboardingStarPetalFieldState extends State<OnboardingStarPetalField>
    with TickerProviderStateMixin {
  late List<_StarSpec> _stars;
  late List<_PetalSpec> _petals;
  late List<AnimationController> _starControllers;
  late List<AnimationController> _petalControllers;

  @override
  void initState() {
    super.initState();

    // 별 — 핸드오프 JS의 의사난수(LCG 유사) 공식을 그대로 이식해 항상
    // 같은 배치가 나오도록 한다: `(i*9301+49297) % 233280 / 233280`,
    // `(i*4877+1231) % 1000 / 1000`.
    _stars = List.generate(widget.starCount, (i) {
      final r = (i * 9301 + 49297) % 233280 / 233280;
      final r2 = (i * 4877 + 1231) % 1000 / 1000;
      final isBig = i % 9 == 0;
      return _StarSpec(
        left: r,
        top: r2 * 0.70, // README "화면 상단 70% 안에 흩뿌립니다".
        size: isBig ? 3.0 : 2.0,
        glow: isBig,
        // `animation-delay: (i % 7) * 0.6s` — 4s 주기 컨트롤러의 시작
        // 지점(0~1)으로 환산.
        startProgress: ((i % 7) * 0.6) / 4.0,
      );
    });
    _starControllers = _stars
        .map(
          (_) => AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 4000), // v2: 고정 4s.
          ),
        )
        .toList();

    // 꽃잎 — README "저사양 기기에서는 꽃잎을 6개로 줄여 주세요".
    final petalCount = widget.lowSpec ? 6 : widget.petalCount;
    _petals = List.generate(petalCount, (i) {
      // `left: (12 + (i*37) % 90) + '%'`.
      final left = (12 + (i * 37) % 90) / 100.0;
      // `width/height scale = .6 + (i%3)*.25` → 0.6/0.85/1.1.
      final scale = 0.6 + (i % 3) * 0.25;
      // `animationDuration = 10 + (i%4)*1.6` → 10~14.8s.
      final durationMs = (10000 + (i % 4) * 1600);
      return _PetalSpec(
        left: left,
        scale: scale,
        duration: Duration(milliseconds: durationMs),
        // `animationDelay = i * 1.25s` — 각 꽃잎 주기 대비 시작 지점으로 환산.
        startProgress: ((i * 1.25 * 1000) % durationMs) / durationMs,
      );
    });
    _petalControllers = _petals
        .map((p) => AnimationController(vsync: this, duration: p.duration))
        .toList();

    if (widget.reduceMotion) {
      // README "구현 규칙 — reduced-motion이면 최종 상태 바로 표시".
      for (final c in _starControllers) {
        c.value = 0.5; // twinkle 중간값(가장 밝은 지점 근처).
      }
      for (final c in _petalControllers) {
        c.value = 0.0; // 낙하 전 정지 상태(투명).
      }
      return;
    }

    for (var i = 0; i < _starControllers.length; i++) {
      _starControllers[i].value = _stars[i].startProgress;
      _starControllers[i].repeat();
    }
    for (var i = 0; i < _petalControllers.length; i++) {
      _petalControllers[i].value = _petals[i].startProgress;
      _petalControllers[i].repeat();
    }
  }

  @override
  void dispose() {
    for (final c in _starControllers) {
      c.dispose();
    }
    for (final c in _petalControllers) {
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
              for (var i = 0; i < _petals.length; i++)
                _Petal(
                  spec: _petals[i],
                  controller: _petalControllers[i],
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
    required this.glow,
    required this.startProgress,
  });

  final double left;
  final double top;
  final double size;
  final bool glow;
  final double startProgress;
}

/// `@keyframes twinkle{0%,100%{opacity:.15}50%{opacity:.7}}`(v2 — scale
/// 변화 없이 opacity만 애니메이션한다. v1은 opacity+scale 둘 다였다).
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
          final opacity = 0.15 + wave * (0.7 - 0.15);
          return Opacity(
            opacity: opacity,
            child: Container(
              width: spec.size,
              height: spec.size,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: spec.glow
                    ? [
                        BoxShadow(
                          color: IntroPalette.primary.withValues(alpha: 0.9),
                          blurRadius: 6,
                        ),
                      ]
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PetalSpec {
  const _PetalSpec({
    required this.left,
    required this.scale,
    required this.duration,
    required this.startProgress,
  });

  final double left;
  final double scale;
  final Duration duration;
  final double startProgress;
}

/// `@keyframes petal{0%{opacity:0;translate(0,0) rotate(0)}10%{opacity:.85}
/// 85%{opacity:.7}100%{opacity:0;translate(-70px,880px) rotate(540deg)}}`
/// — v2는 낙하 종점이 화면 비율이 아닌 고정 px(디자인 기준 844pt 디바이스
/// 기준 880px)라서, 실제 위젯 높이에 맞춰 비례 환산한다(880/844 ≈ 1.043).
class _Petal extends StatelessWidget {
  const _Petal({
    required this.spec,
    required this.controller,
    required this.areaWidth,
    required this.areaHeight,
  });

  final _PetalSpec spec;
  final AnimationController controller;
  final double areaWidth;
  final double areaHeight;

  static const double _refDeviceHeight = 844;
  static const double _refFallDistance = 880;
  static const double _refXDrift = -70;

  double get _baseWidth => 7 * spec.scale;
  double get _baseHeight => 9 * spec.scale;

  @override
  Widget build(BuildContext context) {
    final fallDistance = areaHeight * (_refFallDistance / _refDeviceHeight);
    final xDrift = areaHeight * (_refXDrift / _refDeviceHeight);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        double opacity;
        if (t < 0.10) {
          opacity = (t / 0.10) * 0.85;
        } else if (t < 0.85) {
          opacity = 0.85 - ((t - 0.10) / (0.85 - 0.10)) * (0.85 - 0.70);
        } else {
          opacity = 0.70 * (1 - (t - 0.85) / 0.15);
        }
        final dy = t * fallDistance;
        final dx = t * xDrift;
        final rotation = t * 540 * math.pi / 180;
        return Positioned(
          left: spec.left * areaWidth - 20,
          top: -20 + dy,
          child: Transform.translate(
            offset: Offset(dx, 0),
            child: Transform.rotate(
              angle: rotation,
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Container(
                  width: _baseWidth,
                  height: _baseHeight,
                  decoration: BoxDecoration(
                    // CSS `border-radius: 80% 0 80% 0` (TL/TR/BR/BL).
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(_baseWidth * 0.8),
                      topRight: Radius.zero,
                      bottomRight: Radius.circular(_baseWidth * 0.8),
                      bottomLeft: Radius.zero,
                    ),
                    // v2: `linear-gradient(135deg, #f6c9dc, #d98bb0)`
                    // (v1은 radial #fde3ec→petal).
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFF6C9DC), Color(0xFFD98BB0)],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
