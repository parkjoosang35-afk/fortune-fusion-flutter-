// ═══════════════════════════════════════════════════════════════
// FILE: bangtong_coach_card.dart
// PURPOSE: 방통선녀가 사용자에게 코칭하는 카드
// USED IN:
//   - 관상 인트로: "천천히 정면을 바라봐 주세요"
//   - 손금 인트로: "손바닥에 네 갈래 길이 흘러요"
//
// 기존 화면의 "정면을 바라보고 밝은 곳에서 촬영해주세요" 회색 문구를
// 이 카드로 교체하면 브랜드 톤이 강해집니다.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../theme/sintong_colors.dart';
import '../theme/sintong_typography.dart';
import 'bangtong_fairy_avatar.dart';

class BangtongCoachCard extends StatelessWidget {
  /// 방통선녀 대사 (2줄 이내 권장)
  final String message;

  /// 메타 라벨. 기본 '方通仙女'. 필요 시 '方通仙女 · 觀相' 등으로 확장
  final String metaLabel;

  const BangtongCoachCard({
    super.key,
    required this.message,
    this.metaLabel = '方通仙女',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SintongColors.cardAccent.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: SintongColors.lineDashed,
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BangtongFairyAvatar(size: 44, borderWidth: 1.5),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metaLabel,
                  style: SintongType.monoSm.copyWith(
                    color: SintongColors.accent.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: SintongType.bodySmall.copyWith(
                    color: SintongColors.fg,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
