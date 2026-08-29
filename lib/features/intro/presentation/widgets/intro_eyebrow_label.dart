import 'package:flutter/material.dart';
import '../intro_text_styles.dart';

/// [핸드오프 콘텐츠 반영 - 신규] `.eyebrow` — 각 인트로 페이지 상단의
/// mono 라벨(神通萬通 · SINTONG / CHAPTER · N°01 / CHAPTER · N°02 /
/// READY · TO · BEGIN). 이전 코드에는 이 요소 자체가 없었다.
class IntroEyebrowLabel extends StatelessWidget {
  final String text;

  const IntroEyebrowLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: IntroTextStyles.eyebrow(),
    );
  }
}
