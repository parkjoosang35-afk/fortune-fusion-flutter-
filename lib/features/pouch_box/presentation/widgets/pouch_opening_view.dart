import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../theme/lucky_box_tokens.dart';
import '../../application/pouch_box_audio_controller.dart';

/// [행운상자 - 복주머니 탭 신규 기능] dev-spec.md §3-3 "opening" 단계 —
/// 상자 shake(1.1초, 350ms loop x 3, ease-in-out, rotate ±6° + scale
/// 1.05~1.10). 1.1초가 끝나면 [onSettle]로 burst 단계 전이를 알린다.
class PouchOpeningView extends StatefulWidget {
  final VoidCallback onSettle;
  const PouchOpeningView({super.key, required this.onSettle});

  @override
  State<PouchOpeningView> createState() => _PouchOpeningViewState();
}

class _PouchOpeningViewState extends State<PouchOpeningView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: LuckyBoxTokens.openingShake,
    )..forward();
    PouchBoxAudioController.instance.playOpenShake();
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
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          // 350ms 주기로 3회 shake — 전체 1.1s를 3개 loop로 나눠 sin 진동.
          final t = _controller.value * (1100 / 350) * 2 * math.pi;
          final decay = 1.0 - _controller.value * 0.3; // 점점 감쇠
          final angleDeg = math.sin(t) * 6 * decay;
          final scale = 1.0 + (math.sin(t).abs() * 0.10 * decay);
          return Transform.rotate(
            angle: angleDeg * math.pi / 180,
            child: Transform.scale(scale: scale, child: child),
          );
        },
        child: Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            color: LuckyBoxTokens.bgSoft,
            borderRadius: BorderRadius.circular(LuckyBoxTokens.rHero),
            border: Border.all(color: LuckyBoxTokens.accentGlow, width: 1.4),
            boxShadow: LuckyBoxTokens.lavenderShadow,
          ),
          alignment: Alignment.center,
          child: const Text('🎁', style: TextStyle(fontSize: 52)),
        ),
      ),
    );
  }
}
