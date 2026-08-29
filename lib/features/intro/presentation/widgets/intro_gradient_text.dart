import 'package:flutter/material.dart';

/// [핸드오프 콘텐츠 반영 - 신규] `.title .accent` — 제목 중 일부 구간에
/// 세로 그라디언트(예: gold→glow, crystal 계열)를 입혀 텍스트 색으로 클리핑하는
/// CSS `background-clip: text`를 Flutter `ShaderMask`로 재현한 위젯.
class IntroGradientText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final List<Color> colors;
  final TextAlign textAlign;

  const IntroGradientText(
    this.text, {
    super.key,
    required this.style,
    required this.colors,
    this.textAlign = TextAlign.center,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: colors,
      ).createShader(bounds),
      child: Text(
        text,
        textAlign: textAlign,
        style: style.copyWith(color: Colors.white),
      ),
    );
  }
}
