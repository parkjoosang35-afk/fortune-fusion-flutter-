// ═══════════════════════════════════════════════════════════════
// FILE: sintong_screen_bg.dart
// PURPOSE: 한지 배경 (라디얼 그라디언트 2겹 + 크림→베이지 선형)
// USED IN: 관상/손금 화면의 body 최하단 (Stack 첫 자식으로 배치)
//
// 사용 예:
//   Scaffold(
//     body: Stack(children: [
//       const SintongScreenBg(),
//       SafeArea(child: ...),
//     ]),
//   )
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../theme/sintong_colors.dart';

class SintongScreenBg extends StatelessWidget {
  /// 어두운 촬영/로딩 화면용 dark 모드
  final bool dark;

  const SintongScreenBg({super.key, this.dark = false});

  @override
  Widget build(BuildContext context) {
    if (dark) {
      return Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.0,
            colors: [
              const Color(0xFF3A2A1A),
              const Color(0xFF1A1410),
            ],
            stops: const [0, 0.8],
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [SintongColors.bg1, const Color(0xFFF0E2C4)],
        ),
      ),
      child: Stack(
        children: [
          // 우상단 러스트 워시
          Positioned(
            left: -60, top: -60,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    SintongColors.glow.withValues(alpha: 0.14),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // 좌하단 제이드 워시
          Positioned(
            right: -60, bottom: -60,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    SintongColors.crystal.withValues(alpha: 0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
