import 'package:flutter/material.dart';
import '../../domain/intro_config_model.dart';
import '../intro_text_styles.dart';
import 'intro_character.dart';
import 'intro_eyebrow_label.dart';
import 'intro_feature_list.dart';
import 'intro_progress_dots.dart';
import 'intro_title_text.dart';

/// [핸드오프 콘텐츠 반영 - 신규] 인트로 페이저 페이지2·페이지3 공용 레이아웃.
///
/// 기존 `IntroCardWidget`(카드형 히어로 박스 + 하단 텍스트 블록)을 완전히
/// 대체한다. 핸드오프는 카드 박스 개념이 없고, `.content`(패딩 컨테이너) 안에
/// eyebrow → hero(캐릭터+제목+서브+선택적 피처리스트) → progress 순서로
/// 자유 배치된다(`screens/01_Intro.html` PAGE 2/PAGE 3 구조 그대로).
class IntroContentPage extends StatelessWidget {
  final String eyebrow;
  final String characterAsset;
  final double characterSize;
  final String title;
  final String? highlight;
  final List<Color> highlightColors;
  final double titleFontSize;
  final String subtitle;
  final List<IntroFeatureItem>? featureItems;
  final int progressIndex;
  final bool heroStartAligned;

  const IntroContentPage({
    super.key,
    required this.eyebrow,
    required this.characterAsset,
    required this.characterSize,
    required this.title,
    this.highlight,
    this.highlightColors = const [Colors.white, Colors.white],
    this.titleFontSize = 30,
    required this.subtitle,
    this.featureItems,
    required this.progressIndex,
    this.heroStartAligned = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Column(
        children: [
          IntroEyebrowLabel(eyebrow),
          Expanded(
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                mainAxisAlignment: heroStartAligned
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  if (heroStartAligned) const SizedBox(height: 8),
                  IntroCharacter(
                    asset: characterAsset,
                    size: characterSize,
                    haloSize: characterSize * 1.3,
                  ),
                  const SizedBox(height: 20),
                  IntroTitleText(
                    title,
                    style: IntroTextStyles.title(fontSize: titleFontSize),
                    highlight: highlight,
                    highlightColors: highlightColors,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: IntroTextStyles.sub(),
                  ),
                  if (featureItems != null && featureItems!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    IntroFeatureList(items: featureItems!),
                  ],
                ],
              ),
            ),
          ),
          IntroProgressDots(activeIndex: progressIndex),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
