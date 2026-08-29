import 'package:flutter/material.dart';
import 'intro_character.dart';
import 'intro_eyebrow_label.dart';
import 'intro_feature_list.dart';
import 'intro_title_text.dart';
import '../intro_text_styles.dart';
import '../../domain/intro_config_model.dart';

/// [2026 디자인 핸드오프 콘텐츠 전면 반영 - 신규]
/// 인트로 페이지2("오늘의 결이 무슨 빛인지")/페이지3("내 곁의 귀인은 몇
/// 명일까") 공용 레이아웃. 기존 `IntroCardWidget`(카드 박스형 히어로 +
/// 좌측정렬 텍스트 블록)을 완전히 대체한다 — 핸드오프는 카드 박스가 없고
/// 캐릭터·제목·서브가 화면 중앙에 자유 배치, 가운데 정렬된다
/// (`screens/01_Intro.html` `.hero` 블록 참조).
class IntroPageContent extends StatelessWidget {
  final String eyebrow;
  final String characterAsset;
  final double characterSize;

  /// `\n`으로 줄바꿈된 원문 제목(IntroConfigModel의 title 필드).
  final String title;
  final double titleFontSize;

  /// 제목 중 그라디언트로 강조할 부분 문자열(핸드오프 `.accent`).
  final String? titleHighlight;
  final List<Color> titleHighlightColors;

  /// `\n`으로 줄바꿈된 원문 서브카피.
  final String subtitle;

  /// 페이지3 전용 - 피처리스트 3개(貴/緣/符). null이면 렌더링하지 않는다.
  final List<IntroFeatureItem>? featureItems;

  /// 히어로 영역을 상단 정렬로 시작할지(페이지3 handoff는
  /// `justify-content: flex-start`) 여부.
  final bool alignTop;

  const IntroPageContent({
    super.key,
    required this.eyebrow,
    required this.characterAsset,
    required this.characterSize,
    required this.title,
    required this.subtitle,
    this.titleFontSize = 30,
    this.titleHighlight,
    this.titleHighlightColors = const [Colors.white, Colors.white],
    this.featureItems,
    this.alignTop = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IntroEyebrowLabel(eyebrow),
        const SizedBox(height: 20),
        Expanded(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              mainAxisAlignment: alignTop
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                IntroCharacter(asset: characterAsset, size: characterSize),
                const SizedBox(height: 20),
                IntroTitleText(
                  title,
                  style: IntroTextStyles.title(fontSize: titleFontSize),
                  highlight: titleHighlight,
                  highlightColors: titleHighlightColors,
                ),
                const SizedBox(height: 14),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: IntroTextStyles.sub(),
                ),
                if (featureItems != null) ...[
                  const SizedBox(height: 20),
                  IntroFeatureList(items: featureItems!),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
