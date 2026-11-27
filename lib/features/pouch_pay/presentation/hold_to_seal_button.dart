// [S5 복주머니 결제] HoldToSeal — design_handoff_pouch_payment
// PayCheckout.jsx `HoldToSeal({onDone,label,disabled})` 1:1 포팅.
// 1.4초(DUR) 동안 눌러야 완료되는 길게 누르기 확인 버튼 — 실수로 실제
// 돈이 빠져나가는 것을 막기 위한 안전장치. 중간에 손을 떼면 진행도가
// 스프링처럼 되감긴다.
import 'package:flutter/material.dart';

import '../../wishroom/core/theme/wr_theme.dart';

class HoldToSeal extends StatefulWidget {
  const HoldToSeal({
    super.key,
    required this.onDone,
    required this.label,
    this.disabled = false,
  });

  final VoidCallback onDone;
  final String label;
  final bool disabled;

  @override
  State<HoldToSeal> createState() => _HoldToSealState();
}

class _HoldToSealState extends State<HoldToSeal>
    with SingleTickerProviderStateMixin {
  static const _durMs = 1400;
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _durMs),
  );
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_done) {
        _done = true;
        widget.onDone();
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _start() {
    if (widget.disabled || _done) return;
    _c.forward();
  }

  void _cancel() {
    if (_done) return;
    // 스프링백: 500ms에 걸쳐 0으로 되감는다.
    _c.animateBack(0, duration: const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'pouch_checkout_hold_to_seal',
      button: true,
      child: GestureDetector(
        onTapDown: widget.disabled ? null : (_) => _start(),
        onTapUp: widget.disabled ? null : (_) => _cancel(),
        onTapCancel: widget.disabled ? null : _cancel,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final p = _c.value;
            return Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: widget.disabled
                    ? WrC.darkBtn
                    : const Color(0xFF241420),
                border: Border.all(
                  color: widget.disabled ? WrC.line : WrC.glow,
                ),
              ),
              child: Stack(
                children: [
                  FractionallySizedBox(
                    widthFactor: p.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFE7A0), WrC.glow],
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      p > 0.02 && !widget.disabled
                          ? '꾹 눌러서 봉인하는 중… ${(p * 100).round()}%'
                          : widget.label,
                      style: WrF.body(
                        14,
                        w: FontWeight.w800,
                        color: widget.disabled
                            ? WrC.muted
                            : (p > 0.5 ? const Color(0xFF3A2410) : Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
