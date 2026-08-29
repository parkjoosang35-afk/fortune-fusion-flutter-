import 'package:flutter/material.dart';

/// [STEP04 PART2 §3] 응원 성공 시 짧게(800ms) 위로 떠오르며 사라지는 하트
/// 오버레이. 기존 `wish_wall_detail_screen.dart`의 `_RiseHeart` 패턴을 그대로
/// 공용 위젯으로 승격했다(동일 시각 효과, 재사용). 전체화면을 가리지 않는
/// 작은 오버레이이며, 스크롤 위치나 레이아웃에 영향을 주지 않도록 보통
/// [Stack] 안에서 [Positioned] / [Align]으로 겹쳐 배치해 사용한다.
class WishRoomRiseHeart extends StatefulWidget {
  const WishRoomRiseHeart({super.key, required this.color, this.size = 14});

  final Color color;
  final double size;

  @override
  State<WishRoomRiseHeart> createState() => _WishRoomRiseHeartState();
}

class _WishRoomRiseHeartState extends State<WishRoomRiseHeart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;
          return Opacity(
            opacity: (1 - t).clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, -18 * t),
              child: Icon(
                Icons.favorite,
                size: widget.size,
                color: widget.color,
              ),
            ),
          );
        },
      ),
    );
  }
}
