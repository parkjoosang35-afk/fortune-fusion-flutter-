// ═══════════════════════════════════════════════════════════════
// FILE: home_reading_mini_card.dart
// [관상·손금 신통방통 리스킨] 홈 화면의 좁은 카드 슬롯(소원방 카드와
// 동일한 높이/크기)에 맞춘 컴팩트 버전. `home_reading_card.dart`(핸드오프
// 원본)는 미니 프리뷰 그리드를 포함해 세로 공간을 많이 차지하므로,
// 홈 화면 2단 카드 행에는 이 컴팩트 버전을 사용한다.
//
// 시각 언어는 원본과 동일: Dawn Hanji 그라디언트 + 觀·紋 한자 스탬프 +
// 배경 마법진(FaceSigil) + 화살표 CTA.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../theme/sintong_colors.dart';
import '../theme/sintong_typography.dart';
import '../widgets/hanja_stamp.dart';
import '../widgets/face_sigil.dart';

class HomeReadingMiniCard extends StatelessWidget {
  final VoidCallback? onTap;
  final String title;
  final String bottomLabel;

  const HomeReadingMiniCard({
    super.key,
    this.onTap,
    this.title = '관상 · 손금',
    this.bottomLabel = '얼굴과 손을 읽어보세요',
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              SintongColors.glow.withValues(alpha: 0.16),
              SintongColors.accent.withValues(alpha: 0.09),
            ],
          ),
          border: Border.all(
            color: SintongColors.accent.withValues(alpha: 0.28),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.all(14),
        child: Stack(
          children: [
            // 배경 마법진(우상단, 은은하게)
            Positioned(
              top: -26,
              right: -30,
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.5,
                  child: FaceSigil(
                    size: 96,
                    color: SintongColors.stampGuan,
                    opacity: 0.4,
                  ),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: SintongType.cardTitle.copyWith(fontSize: 15),
                      ),
                    ),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const HanjaStamp(
                          text: '觀',
                          color: SintongColors.stampGuan,
                          size: 22,
                          rotation: -8,
                        ),
                        Positioned(
                          left: 12,
                          top: 6,
                          child: HanjaStamp(
                            text: '紋',
                            color: SintongColors.stampMun,
                            size: 22,
                            rotation: 6,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        bottomLabel,
                        style: SintongType.caption.copyWith(fontSize: 11.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: SintongColors.accent,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
