import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

/// 귀인지도(Guinji Map) 8화면 공통 "별빛 배경".
///
/// [design_handoff_guinji_web/Guinji Section.html] `.stars`/`.star` +
/// `@keyframes twinkle` 스펙을 그대로 재현한다.
/// - 화면당 별 [starCount]개(기본 20개, HTML 하단 script와 동일)
/// - 각 별은 랜덤 위치(top/left %), 랜덤 duration(2~5s), 랜덤 delay(0~3s),
///   랜덤 최대 opacity(0.4~0.9 → CSS 변수 `--o`)
/// - `twinkle` keyframe: opacity `var(--o)` ↔ 0.15, scale 1 ↔ 0.6 (0%,100% 은
///   var(--o)/scale(1), 50% 는 0.15/scale(0.6))
///
/// 좌표계는 부모 크기에 상대적인 비율(0~1)로 저장해 두고
/// [LayoutBuilder]로 실제 픽셀 위치를 계산한다 — 화면 회전/리사이즈에도
/// 별 위치 시드가 유지되도록 [seed]를 고정해 동일한 배치를 재현할 수 있다.
class GuinjiStarField extends StatefulWidget {
  const GuinjiStarField({super.key, this.starCount = 20, this.seed = 42});

  final int starCount;
  final int seed;

  @override
  State<GuinjiStarField> createState() => _GuinjiStarFieldState();
}

class _GuinjiStarFieldState extends State<GuinjiStarField>
    with TickerProviderStateMixin {
  late final List<_StarSpec> _stars;
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _opacities;
  late final List<Animation<double>> _scales;
  late final List<Timer> _delayTimers;

  @override
  void initState() {
    super.initState();
    final random = Random(widget.seed);
    _stars = List.generate(widget.starCount, (_) {
      return _StarSpec(
        left: random.nextDouble(),
        top: random.nextDouble(),
        size: 2 + random.nextDouble() * 2, // 2~4px
        maxOpacity: 0.4 + random.nextDouble() * 0.5, // 0.4~0.9
        duration: Duration(
          milliseconds: 2000 + random.nextInt(3000), // 2~5s
        ),
        delay: Duration(milliseconds: random.nextInt(3000)), // 0~3s
      );
    });

    _controllers = _stars
        .map(
          (star) => AnimationController(vsync: this, duration: star.duration),
        )
        .toList();

    _opacities = List.generate(_stars.length, (i) {
      final star = _stars[i];
      return TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween(begin: star.maxOpacity, end: 0.15),
          weight: 50,
        ),
        TweenSequenceItem(
          tween: Tween(begin: 0.15, end: star.maxOpacity),
          weight: 50,
        ),
      ]).animate(_controllers[i]);
    });

    _scales = List.generate(_stars.length, (i) {
      return TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.6), weight: 50),
        TweenSequenceItem(tween: Tween(begin: 0.6, end: 1.0), weight: 50),
      ]).animate(_controllers[i]);
    });

    _delayTimers = [];
    for (var i = 0; i < _controllers.length; i++) {
      final star = _stars[i];
      _delayTimers.add(
        Timer(star.delay, () {
          if (mounted) {
            _controllers[i].repeat();
          }
        }),
      );
    }
  }

  @override
  void dispose() {
    for (final timer in _delayTimers) {
      timer.cancel();
    }
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: List.generate(_stars.length, (i) {
              final star = _stars[i];
              return Positioned(
                left: star.left * constraints.maxWidth - star.size / 2,
                top: star.top * constraints.maxHeight - star.size / 2,
                child: AnimatedBuilder(
                  animation: _controllers[i],
                  builder: (context, child) {
                    return Opacity(
                      opacity: _opacities[i].value,
                      child: Transform.scale(
                        scale: _scales[i].value,
                        child: Container(
                          width: star.size,
                          height: star.size,
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
            }),
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
    required this.maxOpacity,
    required this.duration,
    required this.delay,
  });

  final double left; // 0~1 비율
  final double top; // 0~1 비율
  final double size;
  final double maxOpacity;
  final Duration duration;
  final Duration delay;
}
