import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../intro_palette.dart';

/// [온보딩 화면 교체 2026-10-11] `Onboarding.html`의 `.stars`/`.star`(별
/// 60개) + `.petals`/`.petal`(꽃잎 14개) 배경 레이어를 그대로 재현한다.
///
/// - 별: 랜덤 위치(%), 크기 1.5/2/3px(3px는 15% 확률), `twinkle`
///   (opacity .12↔.85, scale .8↔1.2, 3~7s 랜덤 duration/delay).
/// - 꽃잎: 위에서 아래(105% 높이)까지 낙하, x 편차 ±60~100px, 회전
///   540°, opacity 0→.85→.6→0, 9~17s 랜덤 duration + 음수 지연(=이미
///   낙하 중인 상태로 시작 — `animation-delay: -Ns` 재현).
/// - 터치 이벤트 없음(`IgnorePointer`).
/// - `reduceMotion`이면 별/꽃잎 모두 정적 최종 상태만 그린다
///   (README "구현 규칙 — prefers-reduced-motion이면 최종 상태").
/// - 저사양 기기 대응(README "deviceMemory ≤ 2면 꽃잎 6개로 축소")은
///   Flutter에 deviceMemory API가 없어 [lowSpec] 플래그로 호출부가
///   대신 판단해 전달한다(기본값 false=14개 전부).
class OnboardingStarPetalField extends StatefulWidget {
  const OnboardingStarPetalField({
    super.key,
    this.starCount = 60,
    this.petalCount = 14,
    this.reduceMotion = false,
    this.lowSpec = false,
    this.seed = 7,
  });

  final int starCount;
  final int petalCount;
  final bool reduceMotion;
  final bool lowSpec;
  final int seed;

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
    final random = math.Random(widget.seed);

    _stars = List.generate(widget.starCount, (_) {
      final sizeRoll = random.nextDouble();
      final size = sizeRoll < 0.15
          ? 3.0
          : (random.nextDouble() < 0.5 ? 1.5 : 2.0);
      return _StarSpec(
        left: random.nextDouble(),
        top: random.nextDouble(),
        size: size,
        duration: Duration(
          milliseconds: 3000 + random.nextInt(4000), // 3~7s
        ),
        // CSS `animation-delay`(0~6s, 랜덤) 재현 — 컨트롤러를 곧바로
        // repeat()하는 대신 임의 시작 지점(0~1)에서 출발시켜 별들이
        // 동시에 깜빡이지 않도록 한다.
        startProgress: random.nextDouble(),
      );
    });
    _starControllers = _stars
        .map((s) => AnimationController(vsync: this, duration: s.duration))
        .toList();

    // README "저사양 기기에서는 꽃잎을 6개로 줄여 주세요".
    final petalCount = widget.lowSpec ? 6 : widget.petalCount;
    _petals = List.generate(petalCount, (_) {
      final scale = 0.6 + random.nextDouble() * 0.8;
      return _PetalSpec(
        left: random.nextDouble(),
        xDrift: (random.nextDouble() * 160 - 60), // ±60~100px 근사
        scale: scale,
        duration: Duration(
          milliseconds: 9000 + random.nextInt(8000), // 9~17s
        ),
        // CSS `animation-delay: -Ns` 음수 지연 재현 — 처음부터 이미
        // 낙하 중인 지점에서 시작하도록 컨트롤러 value를 바로 설정한다.
        startProgress: random.nextDouble(),
      );
    });
    _petalControllers = _petals
        .map((p) => AnimationController(vsync: this, duration: p.duration))
        .toList();

    if (widget.reduceMotion) {
      // README "구현 규칙 — reduced-motion이면 최종 상태 바로 표시".
      for (final c in _starControllers) {
        c.value = 0.5; // twinkle 중간값(가장 밝은 지점 근처)
      }
      for (final c in _petalControllers) {
        c.value = 0.5;
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
    required this.duration,
    required this.startProgress,
  });

  final double left;
  final double top;
  final double size;
  final Duration duration;
  final double startProgress;
}

/// `@keyframes twinkle{0%,100%{opacity:.12;scale(.8)}50%{opacity:.85;scale(1.2)}}`.
class _StarDot extends StatefulWidget {
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
  State<_StarDot> createState() => _StarDotState();
}

class _StarDotState extends State<_StarDot> {
  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.spec.left * widget.areaWidth,
      top: widget.spec.top * widget.areaHeight,
      child: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final t = widget.controller.value;
          // 0→0.5→1 사이를 사인곡선으로 보간(두 극점을 ease-in-out에
          // 근사). opacity .12↔.85, scale .8↔1.2.
          final wave = (math.sin((t * 2 * math.pi) - math.pi / 2) + 1) / 2;
          final opacity = 0.12 + wave * (0.85 - 0.12);
          final scale = 0.8 + wave * (1.2 - 0.8);
          return Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: widget.spec.size,
                height: widget.spec.size,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
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
    required this.xDrift,
    required this.scale,
    required this.duration,
    required this.startProgress,
  });

  final double left;
  final double xDrift;
  final double scale;
  final Duration duration;
  final double startProgress;
}

/// `@keyframes fall{0%{opacity:0;y:0}10%{opacity:.85}85%{opacity:.6}
/// 100%{opacity:0;translate(x,105dvh) rotate(540deg)}}`.
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

  double get _baseWidth => 9 * spec.scale;
  double get _baseHeight => 7 * spec.scale;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        double opacity;
        if (t < 0.10) {
          opacity = (t / 0.10) * 0.85;
        } else if (t < 0.85) {
          opacity = 0.85 - ((t - 0.10) / (0.85 - 0.10)) * (0.85 - 0.60);
        } else {
          opacity = 0.60 * (1 - (t - 0.85) / 0.15);
        }
        final dy = t * (areaHeight * 1.05 + 20);
        final dx = t * spec.xDrift;
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
                    gradient: RadialGradient(
                      center: const Alignment(-0.4, -0.4),
                      colors: [
                        const Color(0xFFFDE3EC),
                        IntroPalette.petal,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: IntroPalette.petal.withValues(alpha: 0.5),
                        blurRadius: 3,
                      ),
                    ],
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
