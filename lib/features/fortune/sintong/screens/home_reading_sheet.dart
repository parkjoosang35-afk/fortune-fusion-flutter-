// ═══════════════════════════════════════════════════════════════
// FILE: home_reading_sheet.dart
// MAPS TO: 홈 스크린샷의 하단 시트 "관상·손금 보기 / 오늘의 관상 / 손금"
// KEEPS: 두 개의 세로 선택 카드 (관상 / 손금)
// REPLACES: 화이트 시트 + 이모지 + "얼굴과 손에 담긴 이야기를 읽어보세요"
// ADDS: 觀·紋 스탬프, 얼굴/손 실루엣, 마법진 배경, 방통선녀 스타일 문구
//
// 사용:
//   showModalBottomSheet(
//     context: context,
//     backgroundColor: Colors.transparent,
//     builder: (ctx) => HomeReadingSheet(
//       onFaceTap: () { Navigator.pop(ctx); Nav.push('/reading/face'); },
//       onPalmTap: () { Navigator.pop(ctx); Nav.push('/reading/palm'); },
//     ),
//   );
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../theme/sintong_colors.dart';
import '../theme/sintong_typography.dart';
import '../widgets/hanja_stamp.dart';
import '../widgets/face_sigil.dart';
import '../widgets/palm_sigil.dart';
import '../widgets/face_silhouette.dart';
import '../widgets/palm_silhouette.dart';

class HomeReadingSheet extends StatelessWidget {
  final VoidCallback? onFaceTap;
  final VoidCallback? onPalmTap;

  const HomeReadingSheet({
    super.key,
    this.onFaceTap,
    this.onPalmTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SintongColors.bg1,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: SintongColors.accent.withValues(alpha: 0.15),
            blurRadius: 24, offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 그랩 핸들
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: SintongColors.line,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),

          // 타이틀
          Text('READING · SELECT', style: SintongType.monoSm),
          const SizedBox(height: 4),
          Text(
            '무엇을 / 들여다볼까요',
            style: SintongType.displayLg.copyWith(fontSize: 22),
          ),
          const SizedBox(height: 4),
          Text(
            '얼굴에는 십이궁이,\n손금에는 사대선이 흐릅니다',
            style: SintongType.bodySmall.copyWith(
              color: SintongColors.muted,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 16),

          // 관상 카드
          _ChoiceCard(
            stampChar: '觀',
            stampColor: SintongColors.stampGuan,
            stampRotation: -6,
            eyebrow: 'PHYSIOGNOMY',
            title: '관상 보기',
            subtitle: '얼굴 · 오관 · 십이궁',
            sigil: FaceSigil(size: 140, color: SintongColors.stampGuan, opacity: 0.6),
            silhouette: const FaceSilhouette(size: 58, showLandmarks: true),
            onTap: onFaceTap,
          ),
          const SizedBox(height: 10),

          // 손금 카드
          _ChoiceCard(
            stampChar: '紋',
            stampColor: SintongColors.stampMun,
            stampRotation: 5,
            eyebrow: 'PALMISTRY',
            title: '손금 보기',
            subtitle: '4대선 · 보조선 · 8구',
            sigil: PalmSigil(size: 140, color: SintongColors.stampGuan, opacity: 0.6),
            silhouette: const PalmSilhouette(size: 52, showLines: true),
            onTap: onPalmTap,
          ),
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final String stampChar;
  final Color stampColor;
  final double stampRotation;
  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget sigil;
  final Widget silhouette;
  final VoidCallback? onTap;

  const _ChoiceCard({
    required this.stampChar,
    required this.stampColor,
    required this.stampRotation,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.sigil,
    required this.silhouette,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: SintongColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: SintongColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned(
              top: -20, right: -30,
              child: Opacity(opacity: 0.35, child: IgnorePointer(child: sigil)),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 76, height: 76,
                  decoration: BoxDecoration(
                    color: SintongColors.bg1.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: SintongColors.line),
                  ),
                  child: Center(child: silhouette),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          HanjaStamp(
                            text: stampChar,
                            color: stampColor,
                            size: 22,
                            rotation: stampRotation,
                          ),
                          const SizedBox(width: 8),
                          Text(eyebrow, style: SintongType.monoSm),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(title, style: SintongType.h2),
                      const SizedBox(height: 4),
                      Text(subtitle, style: SintongType.caption),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward,
                     size: 18, color: SintongColors.accent),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
