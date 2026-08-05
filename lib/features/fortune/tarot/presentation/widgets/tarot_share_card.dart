import 'package:flutter/material.dart';
import '../theme/tarot_colors.dart';
import '../theme/tarot_text_styles.dart';
import '../theme/tarot_tokens.dart';

/// [타로 섹션 전면 개편 §2 정보구조 ⑩ / §11 P4] 공유용 결과 카드.
///
/// 앱 전역 공유카드([FortuneShareCard], `core/widgets/fortune/`)와 동일한
/// "논리 크기 360x450 + capturePixelRatio 3.0 → 1080x1350 캡처" 규칙을
/// 그대로 따르되, 톤은 [TarotColors] 다크 미스틱으로 맞춘다(§1-3 실행
/// 원칙 - 신규 자산 최소화: 캡처 로직은 새로 만들지 않고 기존 패턴만 재사용).
class TarotShareCard extends StatelessWidget {
  const TarotShareCard({
    super.key,
    required this.cardIcon,
    this.cardImagePath,
    required this.cardName,
    required this.isReversed,
    required this.oneLiner,
    required this.luckyColorName,
    required this.luckyColor,
    required this.luckyNumber,
  });

  final String cardIcon;

  /// [카드 이미지 교체] 실제 카드 이미지 경로(nullable). null이면 기존
  /// 이모지([cardIcon])로 표시한다(§ 기존 코드 호환 최소 수정 원칙).
  final String? cardImagePath;
  final String cardName;
  final bool isReversed;
  final String oneLiner;
  final String luckyColorName;
  final Color luckyColor;
  final int luckyNumber;

  static const double logicalWidth = 360;
  static const double logicalHeight = 450;
  static const double capturePixelRatio = 3.0; // 360*3=1080, 450*3=1350

  @override
  Widget build(BuildContext context) {
    return Container(
      width: logicalWidth,
      height: logicalHeight,
      decoration: const BoxDecoration(gradient: TarotColors.nightGradient),
      padding: const EdgeInsets.all(TarotTokens.spaceXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🔮', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text('AI 타로 리딩', style: TarotTextStyles.caption),
            ],
          ),
          const Spacer(),
          Center(
            child: Column(
              children: [
                cardImagePath == null
                    ? Text(cardIcon, style: const TextStyle(fontSize: 48))
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          cardImagePath!,
                          width: 90,
                          height: 138,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Text(
                            cardIcon,
                            style: const TextStyle(fontSize: 48),
                          ),
                        ),
                      ),
                const SizedBox(height: TarotTokens.spaceSm),
                Text(
                  '$cardName${isReversed ? " (역방향)" : ""}',
                  style: TarotTextStyles.categoryTitle.copyWith(fontSize: 20),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: TarotTokens.spaceLg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(TarotTokens.spaceLg),
            decoration: BoxDecoration(
              color: TarotColors.surfaceCard,
              borderRadius: BorderRadius.circular(TarotTokens.radiusMd),
              border: Border.all(color: TarotColors.borderGlow),
            ),
            child: Text(
              '"$oneLiner"',
              textAlign: TextAlign.center,
              style: TarotTextStyles.bodyStrong.copyWith(
                color: TarotColors.pinkGlow,
                fontStyle: FontStyle.italic,
                fontSize: 14,
              ),
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: luckyColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '행운의 색 $luckyColorName · 행운의 숫자 $luckyNumber',
                style: TarotTextStyles.caption,
              ),
            ],
          ),
          const SizedBox(height: TarotTokens.spaceSm),
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  gradient: TarotColors.goldAccentGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 14,
                  color: TarotColors.bgVoid,
                ),
              ),
              const SizedBox(width: 6),
              Text('Fortune Fusion · 신통방통 타로', style: TarotTextStyles.caption),
            ],
          ),
        ],
      ),
    );
  }
}
