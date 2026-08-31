// ═══════════════════════════════════════════════════════════════
// FILE: bangtong_fairy_avatar.dart
// PURPOSE: 방통선녀 마스코트 얼굴 아바타 (원형, 재사용)
// USED IN: 홈 히어로, 인트로 코칭 카드, 로딩 화면, 결과 총평 카드, 공유 카드
//
// ASSET REQUIRED: assets/bangtong_fairy.png (pubspec에 등록 필수)
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../theme/sintong_colors.dart';

class BangtongFairyAvatar extends StatelessWidget {
  /// 원형 아바타 크기 (지름)
  final double size;

  /// 테두리 색. null이면 accent 사용
  final Color? borderColor;

  /// 테두리 두께
  final double borderWidth;

  /// 그림자 강도 (0 = 없음, 1 = 강한 halo)
  final double glowIntensity;

  const BangtongFairyAvatar({
    super.key,
    this.size = 60,
    this.borderColor,
    this.borderWidth = 2,
    this.glowIntensity = 0.6,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor ?? SintongColors.accent.withValues(alpha: 0.5),
          width: borderWidth,
        ),
        boxShadow: glowIntensity > 0
          ? [
              BoxShadow(
                color: SintongColors.accent.withValues(alpha: 0.25 * glowIntensity),
                blurRadius: 12 * glowIntensity,
                offset: Offset(0, 4 * glowIntensity),
              ),
            ]
          : null,
      ),
      child: ClipOval(
        child: Semantics(
          label: '방통선녀',
          child: Image.asset(
            'assets/images/sintong/bangtong_fairy.png',
            fit: BoxFit.cover,
            // 이미지가 얼굴 중심에 잡히도록
            alignment: const Alignment(0, -0.4),
          ),
        ),
      ),
    );
  }
}
