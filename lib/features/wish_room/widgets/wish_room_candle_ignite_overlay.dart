import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/wish_room_theme.dart';

/// [소원방 개편 · 2a] "촛불 켜기" 탭 시 실제로 불이 붙는 것처럼 보이는
/// 1회성 점화(ignition) 연출.
///
/// 기존 [WishRoomCandle]은 항상 반복되는 미세 흔들림(flicker)만 있을 뿐,
/// 탭했을 때 "불이 붙는" 순간적인 연출이 전혀 없어 사용자가 "그냥
/// 스낵바만 뜬다"고 느끼는 원인이었다. 이 위젯은 [Overlay]에 잠깐
/// 삽입되어 화면 중앙에서 확산하는 골든 링 + 위로 솟구치는 불티(spark)
/// 입자 + 화면 전체의 은은한 플래시를 재생한 뒤 스스로 제거된다.
/// 기존 촛불/애니메이션 구조를 건드리지 않는 완전히 독립적인 오버레이라
/// 홈/상세 화면 어디서든 동일하게 재사용할 수 있다.
Future<void> playWishRoomCandleIgnition(BuildContext context) async {
  final overlay = Overlay.of(context, rootOverlay: true);
  final completer = Completer<void>();
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _IgniteOverlay(
      onDone: () {
        entry.remove();
        if (!completer.isCompleted) completer.complete();
      },
    ),
  );
  overlay.insert(entry);
  return completer.future;
}

class _IgniteOverlay extends StatefulWidget {
  const _IgniteOverlay({required this.onDone});

  final VoidCallback onDone;

  @override
  State<_IgniteOverlay> createState() => _IgniteOverlayState();
}

class _IgniteOverlayState extends State<_IgniteOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final List<_Spark> _sparks;

  @override
  void initState() {
    super.initState();
    final rand = Random();
    _sparks = List.generate(14, (i) {
      final angle = (i / 14) * 2 * pi + rand.nextDouble() * 0.3;
      return _Spark(
        angle: angle,
        distance: 60 + rand.nextDouble() * 70,
        delay: rand.nextDouble() * 0.25,
        size: 3 + rand.nextDouble() * 4,
      );
    });
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
    _c.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onDone();
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          // 0.0~0.35: 화면 플래시 in, 0.35~1.0: 플래시 out
          final flashOpacity = t < 0.15
              ? (t / 0.15) * 0.35
              : ((1 - ((t - 0.15) / 0.85)).clamp(0.0, 1.0)) * 0.35;
          // 링 확산
          final ringScale = 0.2 + Curves.easeOutCubic.transform(t) * 2.6;
          final ringOpacity = (1 - t).clamp(0.0, 1.0);
          return Stack(
            children: [
              // 화면 전체 은은한 골든 플래시
              Positioned.fill(
                child: Container(
                  color: WishRoomColors.glow.withValues(alpha: flashOpacity),
                ),
              ),
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 확산 링
                    Transform.scale(
                      scale: ringScale,
                      child: Opacity(
                        opacity: ringOpacity,
                        child: Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: WishRoomColors.glow,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: WishRoomColors.glow.withValues(
                                  alpha: 0.6,
                                ),
                                blurRadius: 30,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // 중심 코어 글로우 (빠르게 밝아졌다 사라짐)
                    Opacity(
                      opacity: (1 - (t / 0.6)).clamp(0.0, 1.0),
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Color(0xFFFFF8DD),
                              WishRoomColors.glow,
                              Colors.transparent,
                            ],
                            stops: [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                    ),
                    // 솟구치는 불티 입자들
                    ..._sparks.map((s) => _buildSpark(s, t)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSpark(_Spark s, double t) {
    final localT = ((t - s.delay) / (1 - s.delay)).clamp(0.0, 1.0);
    if (localT <= 0) return const SizedBox.shrink();
    final eased = Curves.easeOutQuart.transform(localT);
    final dx = cos(s.angle) * s.distance * eased;
    final dy =
        sin(s.angle) * s.distance * eased * 0.6 -
        eased * 40; // 위로 솟구치는 느낌 추가
    final opacity = (1 - localT).clamp(0.0, 1.0);
    return Transform.translate(
      offset: Offset(dx, dy),
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: s.size,
          height: s.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFFFD47A),
            boxShadow: [
              BoxShadow(
                color: WishRoomColors.glow.withValues(alpha: 0.8),
                blurRadius: 6,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Spark {
  const _Spark({
    required this.angle,
    required this.distance,
    required this.delay,
    required this.size,
  });

  final double angle;
  final double distance;
  final double delay;
  final double size;
}
