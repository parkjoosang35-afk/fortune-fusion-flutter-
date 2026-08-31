// ═══════════════════════════════════════════════════════════════
// FILE: home_reading_card.dart
// MAPS TO: 홈 스크린샷의 "관상·손금" 그리드 셀 (우측 두 번째 줄)
// KEEPS: onTap 콜백 (기존 로직: showModalBottomSheet 또는 push /reading/select)
// REPLACES: 기존 회색 카드 + 손 이모지 + "얼굴과 손을 읽어보세요"
// ADDS: Dawn Hanji 그라디언트 + 觀·紋 하자 스탬프 + 배경 마법진 + 얼굴/손 미니 프리뷰
//
// 사용 (홈 위젯 트리에서):
//   GridView( children: [
//     정통사주Card, 타로Card, 소원방Card,
//     HomeReadingCard(onTap: () => showReadingSheet(context)),   ← 여기
//   ])
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../theme/sintong_colors.dart';
import '../theme/sintong_typography.dart';
import '../widgets/hanja_stamp.dart';
import '../widgets/face_sigil.dart';
import '../widgets/face_silhouette.dart';
import '../widgets/palm_silhouette.dart';

class HomeReadingCard extends StatelessWidget {
  final VoidCallback? onTap;

  /// 우측 하단 배지 (예: '지난 기록 · 12회'). null이면 숨김
  final String? badgeText;

  const HomeReadingCard({
    super.key,
    this.onTap,
    this.badgeText = '지난 기록 · 12회',
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [
              SintongColors.glow.withValues(alpha: 0.14),
              SintongColors.accent.withValues(alpha: 0.08),
            ],
          ),
          border: Border.all(color: SintongColors.accent.withValues(alpha: 0.28)),
        ),
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.all(18),
        child: Stack(
          children: [
            // 배경 마법진
            Positioned(
              top: -30, right: -40,
              child: Opacity(
                opacity: 0.55,
                child: IgnorePointer(
                  child: FaceSigil(
                    size: 180,
                    color: SintongColors.stampGuan,
                    opacity: 0.4,
                  ),
                ),
              ),
            ),

            // 콘텐츠
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 스탬프 + 라벨
                Row(
                  children: [
                    const HanjaStamp(
                      text: '觀',
                      color: SintongColors.stampGuan,
                      size: 26,
                      rotation: -8,
                    ),
                    Transform.translate(
                      offset: const Offset(-6, 0),
                      child: const HanjaStamp(
                        text: '紋',
                        color: SintongColors.stampMun,
                        size: 26,
                        rotation: 5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('PHYSIOGNOMY · PALMISTRY', style: SintongType.monoSm),
                  ],
                ),
                const SizedBox(height: 8),
                Text('관상 · 손금', style: SintongType.displayLg.copyWith(fontSize: 22)),
                const SizedBox(height: 4),
                Text(
                  '얼굴과 손에 새겨진\n당신의 하늘을 읽습니다',
                  style: SintongType.bodySmall.copyWith(
                    color: SintongColors.muted,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 14),

                // 얼굴/손 미니 프리뷰
                Row(
                  children: [
                    Expanded(child: _MiniPreview(child: const FaceSilhouette(size: 62, showLandmarks: false), label: '觀相')),
                    const SizedBox(width: 8),
                    Expanded(child: _MiniPreview(child: const PalmSilhouette(size: 54, showLines: false), label: '手紋')),
                  ],
                ),

                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (badgeText != null)
                      Text(badgeText!, style: SintongType.caption)
                    else const SizedBox(),
                    Text(
                      '들여다보기 →',
                      style: SintongType.bodySmall.copyWith(
                        fontWeight: FontWeight.w700, fontSize: 12,
                        color: SintongColors.accent,
                      ),
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

class _MiniPreview extends StatelessWidget {
  final Widget child;
  final String label;
  const _MiniPreview({required this.child, required this.label});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: SintongColors.bg1.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: SintongColors.line),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(child: Center(child: child)),
            Text(label, style: SintongType.monoSm.copyWith(fontSize: 8)),
          ],
        ),
      ),
    );
  }
}
