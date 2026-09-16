import 'package:flutter/material.dart';
import '../../../../theme/lucky_box_tokens.dart';
import 'pouch_burst_painter.dart';

/// [행운상자 - 복주머니 탭 신규 기능] dev-spec.md §3-3 "burst" 단계 —
/// 총 2.0초 폭발 시퀀스를 [PouchBurstPainter](CustomPainter)로 렌더링한다.
/// 파티클 개수는 [particleCount](서버 보상량 등급에 비례해 50~300개 사이로
/// 호출부가 미리 결정)를 그대로 쓰고, [progress] 0→1 애니메이션이 끝나면
/// [onSettle]로 result 단계 전이를 알린다.
class PouchBurstView extends StatefulWidget {
  final int particleCount;
  final bool isJackpot;
  final VoidCallback onSettle;

  const PouchBurstView({
    super.key,
    required this.particleCount,
    this.isJackpot = false,
    required this.onSettle,
  });

  @override
  State<PouchBurstView> createState() => _PouchBurstViewState();
}

class _PouchBurstViewState extends State<PouchBurstView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final PouchBurstData _data;

  @override
  void initState() {
    super.initState();
    _data = PouchBurstData.generate(
      particleCount: widget.particleCount,
      totalMs: LuckyBoxTokens.burstTotal.inMilliseconds.toDouble(),
      isJackpot: widget.isJackpot,
    );
    _controller = AnimationController(
      vsync: this,
      duration: LuckyBoxTokens.burstTotal,
    )..forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onSettle();
      }
    });
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
        return CustomPaint(
          size: Size.infinite,
          painter: PouchBurstPainter(data: _data, progress: _controller.value),
        );
      },
    );
  }
}
