// 한지 카드 (반투명 갈색 배경 + 얇은 라인 테두리 + 선택적 상단 글로우)
// 원본: flutter_handoff.zip widgets/hanji_card.dart (값 100% 동일)

import 'package:flutter/material.dart';
import 'hanji_design_tokens.dart';

class HanjiCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool glow;
  final Color? borderColor;
  final Color? backgroundColor;

  const HanjiCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(HanjiSpacing.lg),
    this.glow = false,
    this.borderColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: backgroundColor ?? HanjiColors.card,
            border: Border.all(color: borderColor ?? HanjiColors.line),
            borderRadius: BorderRadius.circular(HanjiRadii.hero - 4),
          ),
          padding: padding,
          child: child,
        ),
        if (glow)
          Positioned(
            top: -30,
            left: 30,
            right: 30,
            height: 60,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      HanjiColors.glowShadow,
                      HanjiColors.glowShadow.withValues(alpha: 0),
                    ],
                    stops: const [0, 1],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
