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
    // [반응형 화면 규격 통일 — 잘림 현상 수정] 하이라이트가 포함된 줄은
    // before/highlight/after 세 조각의 Text를 한 줄(Row)로 이어 붙여
    // 부분 그라디언트를 재현한다. 이 줄 전체가 하나의 "단어"처럼 항상
    // 한 줄로 유지돼야 디자인(하이라이트 위치)이 깨지지 않는데, 좁은
    // 화면(360px 내외) + 긴 문구 조합에서 가로 오버플로가 실측 확인됐다.
    // 폰트·줄바꿈 구조는 그대로 두고, 꽉 찰 때만 미세 축소되도록
    // FittedBox로 감싼다(들어가면 scale 1로 기존과 동일).
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (before.isNotEmpty) Text(before, style: style),
          IntroGradientText(h, style: style, colors: highlightColors),
          if (after.isNotEmpty) Text(after, style: style),
        ],
      ),
    );
  }
}
