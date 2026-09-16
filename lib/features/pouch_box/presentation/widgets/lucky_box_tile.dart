import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../theme/lucky_box_tokens.dart';

/// [행운상자 - 복주머니 탭 신규 기능] dev-spec.md §3-1 `<BoxTile>` →
/// `LuckyBoxTile` 매핑. 3x3 그리드의 상자 1칸. idle 상태에서 3초 주기로
/// ±3px Y이동 + ±2° 회전(Sin 곡선)을 반복한다(각 타일마다 delay를 줘서
/// 동시에 움직이지 않도록 자연스러움을 준다).
class LuckyBoxTile extends StatefulWidget {
  final int index;
  const LuckyBoxTile({super.key, required this.index});

  @override
  State<LuckyBoxTile> createState() => _LuckyBoxTileState();
}

class _LuckyBoxTileState extends State<LuckyBoxTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: LuckyBoxTokens.boxIdle,
    )..repeat();
    // 타일마다 시작 위상을 다르게 줘서 동시에 움직이지 않도록 함.
    _controller.value = (widget.index * 0.13) % 1.0;
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
      builder: (context, child) {
        final t = _controller.value * 2 * math.pi;
        final dy = math.sin(t) * 3;
        final rot = math.sin(t) * (2 * math.pi / 180);
        return Transform.translate(
          offset: Offset(0, dy),
          child: Transform.rotate(angle: rot, child: child),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: LuckyBoxTokens.bgSoft,
          borderRadius: BorderRadius.circular(LuckyBoxTokens.rTile),
          border: Border.all(color: LuckyBoxTokens.line),
          boxShadow: LuckyBoxTokens.cardShadow,
        ),
        alignment: Alignment.center,
        child: const Text('🎁', style: TextStyle(fontSize: 32)),
      ),
    );
  }
}
