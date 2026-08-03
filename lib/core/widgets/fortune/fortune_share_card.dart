import 'package:flutter/material.dart';
import '../../theme/app_unified_style.dart';

/// [오늘의 운세 표준 플로우] §6 후속연결 — "이미지 공유 카드".
///
/// 1080x1350 세로형(4:5) 캡처를 위해 논리 크기 360x450으로 그리고,
/// RepaintBoundary 캡처 시 pixelRatio 3.0을 곱해 정확히 1080x1350을 얻는다.
/// 구성: 히어로 요약 + 점수 + 한줄 총평 + 앱 로고. 톤은 화이트 + 라벤더화이트.
class FortuneShareCard extends StatelessWidget {
  const FortuneShareCard({
    super.key,
    required this.name,
    required this.date,
    required this.score,
    required this.headline,
  });

  final String name;
  final DateTime date;
  final int score;
  final String headline;

  static const double logicalWidth = 360;
  static const double logicalHeight = 450;
  static const double capturePixelRatio = 3.0; // 360*3=1080, 450*3=1350

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
    return Container(
      width: logicalWidth,
      height: logicalHeight,
      color: UnifiedColors.bg,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('오늘의 운세', style: UnifiedText.caption()),
          const SizedBox(height: 4),
          Text('$name · $dateLabel', style: UnifiedText.bodySmall()),
          const Spacer(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(UnifiedTokens.spaceXl),
            decoration: BoxDecoration(
              color: UnifiedColors.cardMain,
              borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$score',
                      style: UnifiedText.titleLarge().copyWith(fontSize: 34),
                    ),
                    const SizedBox(width: 2),
                    Text('/100', style: UnifiedText.body()),
                  ],
                ),
                const SizedBox(height: UnifiedTokens.spaceSm),
                Text(headline, style: UnifiedText.bodyStrong()),
              ],
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: UnifiedColors.black,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 14,
                  color: UnifiedColors.neon,
                ),
              ),
              const SizedBox(width: 6),
              Text('Fortune Fusion · 신통방통', style: UnifiedText.caption()),
            ],
          ),
        ],
      ),
    );
  }
}
