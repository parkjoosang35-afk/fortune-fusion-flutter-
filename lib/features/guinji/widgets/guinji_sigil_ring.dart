import 'dart:math';

import 'package:flutter/material.dart';

import '../../wish_room/widgets/wish_room_sigil.dart';

/// 귀인지도(Guinji Map) 8화면 전용 "회전 마법진" 래퍼.
///
/// [design_handoff_guinji_web/Guinji Section.html] `@keyframes sigil-rot`은
/// 화면마다 서로 다른 회전 속도를 사용한다:
/// - C(Calculating) 화면 배경 sigil: 12s linear
/// - M(My Map) 화면 `.map-sigil`: 90s linear
///
/// 기존 [WishRoomSigilRing]은 duration이 40s/55s(reverse bool)로 고정되어
/// 있어 재사용할 수 없으므로, 동일한 [WishRoomSigil] 페인터를 그대로
/// 재사용하면서 임의의 [duration]으로 회전시키는 얇은 래퍼를 새로 만든다.
class GuinjiSigilRing extends StatefulWidget {
  const GuinjiSigilRing({
    super.key,
    this.size = 300,
    required this.color,
    this.opacity = 0.5,
    required this.duration,
    this.reverse = false,
  });

  final double size;
  final Color color;
  final double opacity;
  final Duration duration;
  final bool reverse;

  @override
  State<GuinjiSigilRing> createState() => _GuinjiSigilRingState();
}

class _GuinjiSigilRingState extends State<GuinjiSigilRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
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
      builder: (context, _) {
        final angle = _controller.value * 2 * pi * (widget.reverse ? -1 : 1);
        return Transform.rotate(
          angle: angle,
          child: WishRoomSigil(
            size: widget.size,
            color: widget.color,
            opacity: widget.opacity,
          ),
        );
      },
    );
  }
}
