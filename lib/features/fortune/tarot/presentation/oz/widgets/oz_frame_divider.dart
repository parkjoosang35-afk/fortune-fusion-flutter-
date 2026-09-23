import 'package:flutter/material.dart';

import '../oz_theme.dart';

/// [타로 카드뽑기 화면 디자인 핸드오프 매핑 · T1] 진열대 위/아래를 감싸는
/// 대칭 구분선. CSS 대응: `<FrameDivider>`(TarotApp.jsx) — 좌우 그라디언트
/// 라인 + ◆ + 콘텐츠 + ◆ + 라인.
class OzFrameDivider extends StatelessWidget {
  final Widget child;
  const OzFrameDivider({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          Expanded(child: _GradientLine(reversed: false)),
          const SizedBox(width: 8),
          Text(
            '◆',
            style: TextStyle(color: OzColors.goldDeep, fontSize: 8),
          ),
          const SizedBox(width: 8),
          child,
          const SizedBox(width: 8),
          Text(
            '◆',
            style: TextStyle(color: OzColors.goldDeep, fontSize: 8),
          ),
          const SizedBox(width: 8),
          Expanded(child: _GradientLine(reversed: true)),
        ],
      ),
    );
  }
}

class _GradientLine extends StatelessWidget {
  final bool reversed;
  const _GradientLine({required this.reversed});

  @override
  Widget build(BuildContext context) {
    final colors = [
      Colors.transparent,
      OzColors.goldDeep.withValues(alpha: 0.65),
      Colors.transparent,
    ];
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: reversed ? Alignment.centerRight : Alignment.centerLeft,
          end: reversed ? Alignment.centerLeft : Alignment.centerRight,
          colors: colors,
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}
