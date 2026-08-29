import 'package:flutter/material.dart';
import 'intro_gradient_text.dart';

/// [핸드오프 콘텐츠 반영 - 신규] `.title` + `.title .accent` 조합을
/// 재현하는 다줄 제목 위젯.
///
/// 핸드오프는 제목 중 일부 단어만 그라디언트로 강조한다
/// (예: "오늘의 결이 / **무슨 빛**인지"). [text]는 `\n`으로 줄바꿈된
/// 원문(IntroConfigModel의 필드 값)을 그대로 받고, [highlight]로 지정한
/// 부분 문자열만 [highlightColors] 그라디언트로 렌더링한다. 하이라이트가
/// 포함된 줄은 가운데 정렬된 Row로, 나머지 줄은 일반 Text로 그린다.
class IntroTitleText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final String? highlight;
  final List<Color> highlightColors;

  const IntroTitleText(
    this.text, {
    super.key,
    required this.style,
    this.highlight,
    this.highlightColors = const [Colors.white, Colors.white],
  });

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [for (final line in lines) _buildLine(line)],
    );
  }

  Widget _buildLine(String line) {
    final h = highlight;
    if (h == null || h.isEmpty || !line.contains(h)) {
      return Text(line, textAlign: TextAlign.center, style: style);
    }
    final idx = line.indexOf(h);
    final before = line.substring(0, idx);
    final after = line.substring(idx + h.length);
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (before.isNotEmpty) Text(before, style: style),
        IntroGradientText(h, style: style, colors: highlightColors),
        if (after.isNotEmpty) Text(after, style: style),
      ],
    );
  }
}
