// ═══════════════════════════════════════════════════════════════
// FILE: hanja_stamp.dart
// PURPOSE: 하자 인장 (觀·紋·願·合 등을 도장처럼 렌더)
// USED IN: 홈 카드 헤더, 결과 리포트 상단, 공유 카드, 히스토리 배지
//
// 사용 예:
//   HanjaStamp(text: '觀', size: 32)                    // 관상용 (기본 accent)
//   HanjaStamp(text: '紋', size: 32, color: SintongColors.stampMun, rotation: 5)
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../theme/sintong_colors.dart';
import '../theme/sintong_typography.dart';

class HanjaStamp extends StatelessWidget {
  final String text;
  final double size;
  final Color color;
  final double rotation;  // degree

  const HanjaStamp({
    super.key,
    required this.text,
    this.size = 40,
    this.color = SintongColors.stampGuan,
    this.rotation = -6,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotation * 3.14159 / 180,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.5),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // 이너 하이라이트 (도장 눌린 느낌)
            Positioned.fill(
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFFFFF9E8).withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            // 하자 글리프
            Center(
              child: Text(
                text,
                style: TextStyle(
                  fontFamily: SintongType.display,
                  fontWeight: FontWeight.w900,
                  fontSize: size * 0.5,
                  color: const Color(0xFFFFF9E8),
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      offset: const Offset(0, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
