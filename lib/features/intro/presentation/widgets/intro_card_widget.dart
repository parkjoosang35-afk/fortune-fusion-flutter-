import 'package:flutter/material.dart';
import '../../../../core/theme/app_unified_style.dart';
import 'intro_hero_section.dart';
import 'intro_benefit_section.dart';

/// [인트로 전면 개편] 2단계(카드1: 프리패스)/3단계(카드2: 복주머니) 공용 레이아웃.
/// IntroHeroSection(상단 비주얼) + IntroBenefitSection(제목/설명)을 세로로
/// 배치한다. 카드 자체에 그림자/테두리 등 과한 장식을 넣지 않는다.
class IntroCardWidget extends StatelessWidget {
  final IconData icon;
  final String? badgeText;
  final Color heroColor;
  final bool showCounter;
  final int counterTarget;
  final String counterSuffix;
  final String title;
  final String description;

  const IntroCardWidget({
    super.key,
    required this.icon,
    this.badgeText,
    required this.heroColor,
    this.showCounter = false,
    this.counterTarget = 12,
    this.counterSuffix = '개',
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: UnifiedTokens.screenPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IntroHeroSection(
            icon: icon,
            badgeText: badgeText,
            cardColor: heroColor,
            showCounter: showCounter,
            counterTarget: counterTarget,
            counterSuffix: counterSuffix,
          ),
          const SizedBox(height: UnifiedTokens.spaceXxl),
          IntroBenefitSection(title: title, description: description),
        ],
      ),
    );
  }
}
