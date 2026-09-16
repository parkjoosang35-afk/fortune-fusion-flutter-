import 'package:flutter/material.dart';
import '../../../../core/widgets/bangtong_seonyeo.dart';
import 'intro_eyebrow_label.dart';
import 'intro_feature_list.dart';
import 'intro_title_text.dart';
import '../intro_text_styles.dart';
import '../../domain/intro_config_model.dart';

/// [2026 디자인 핸드오프 콘텐츠 전면 반영 - 신규]
/// 인트로 페이지2("오늘의 결이 무슨 빛인지")/페이지3("내 곁의 귀인은 몇
/// 명일까") 공용 레이아웃. 기존 `IntroCardWidget`(카드 박스형 히어로 +
/// 좌측정렬 텍스트 블록)을 완전히 대체한다 — 핸드오프는 카드 박스가 없고
/// 제목·서브가 화면 중앙에 자유 배치, 가운데 정렬된다
/// (`screens/01_Intro.html` `.hero` 블록 참조).
class IntroPageContent extends StatelessWidget {
  final String eyebrow;

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

  /// [방통선녀 캐릭터 재배치] 페이지 상단(eyebrow 위)에 표시할 캐릭터
  /// 표정. null이면 캐릭터를 표시하지 않는다.
  final BangtongMood? characterMood;

  const IntroPageContent({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.titleFontSize = 30,
    this.titleHighlight,
    this.titleHighlightColors = const [Colors.white, Colors.white],
    this.featureItems,
    this.alignTop = false,
    this.characterMood,
  });

  /// 제목/서브카피/피처리스트를 렌더링하는 공용 콘텐츠 블록.
  List<Widget> _contentChildren() {
    return [
      IntroTitleText(
        title,
        style: IntroTextStyles.title(fontSize: titleFontSize),
        highlight: titleHighlight,
        highlightColors: titleHighlightColors,
      ),
      const SizedBox(height: 14),
      Text(subtitle, textAlign: TextAlign.center, style: IntroTextStyles.sub()),
      if (featureItems != null) ...[
        const SizedBox(height: 20),
        IntroFeatureList(items: featureItems!),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (characterMood != null) ...[
          BangtongFaceAvatar(size: 84, mood: characterMood!, glow: true),
          const SizedBox(height: 16),
        ],
        IntroEyebrowLabel(eyebrow),
        const SizedBox(height: 20),
        Expanded(
          // [2차 버그 수정 - 데스크톱 목업(WebMobileFrame)에서 콘텐츠가 넘쳐
          // dots+버튼이 화면 밖으로 밀려나는 문제]
          // 과거(1차) 수정에서는 "짧은 콘텐츠가 항상 상단에 붙어 버튼과의
          // 사이가 거대하게 빈다"는 문제를 고치기 위해 SingleChildScrollView를
          // 제거하고 Column(mainAxisAlignment.center)만 사용했다. 그런데
          // WebMobileFrame이 앱 내부를 고정 논리 캔버스(430x900)로 강제하는
          // 환경 등, 실제 가용 높이가 콘텐츠 총 높이보다 작아지는 경우
          // Column은 정렬 개념이 있을 뿐 "넘치는 만큼 줄여주는" 기능이 없어
          // RenderFlex 오버플로우가 발생하고, 그 결과 형제 위젯인
          // dots/버튼까지 화면 밖으로 밀려나 보이지 않게 되었다.
          //
          // 해결: LayoutBuilder + SingleChildScrollView +
          // ConstrainedBox(minHeight: 가용 높이) 조합을 사용한다.
          // - 콘텐츠가 가용 높이보다 짧으면: ConstrainedBox가 최소 높이를
          //   가용 높이만큼 강제하므로, 내부 Column(center)이 실제로
          //   중앙에 배치된다(1차 버그가 재발하지 않음).
          // - 콘텐츠가 가용 높이보다 길면: SingleChildScrollView가 스크롤을
          //   허용해 하드 오버플로우 없이 자연스럽게 넘치는 부분만 스크롤
          //   가능해지고, Expanded가 차지하는 공간 자체는 변하지 않으므로
          //   형제 위젯(dots/버튼)이 화면 밖으로 밀려나지 않는다(2차 버그
          //   수정).
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: alignTop
                    ? const NeverScrollableScrollPhysics()
                    : const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    mainAxisAlignment: alignTop
                        ? MainAxisAlignment.start
                        : MainAxisAlignment.center,
                    children: _contentChildren(),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
