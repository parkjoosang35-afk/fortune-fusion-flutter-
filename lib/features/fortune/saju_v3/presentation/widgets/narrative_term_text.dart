// [69종 AI 해석 전면 재설계 — 용어 탭 설명] NarrativeTermText.
//
// [배경] `/saju/v3/narrative`가 반환하는 서사형 본문(text)은 정재/편재/
// 용신/희신 같은 사주 전문 용어를 문장 속에 그대로 쓴다. 본문 안에서
// "처음 등장 시 쉬운말을 괄호로 풀어 쓰는" 방식은 QA
// (`check_terminology_explained`)가 경고하는 지점이지만, 문장 흐름을
// 끊지 않기 위해 본문 자체를 고치는 대신 — 이미 존재하는
// `assets/jeontong/easy_terms.json` 사전(+ `JeontongEasyTermToggle`이
// 쓰는 것과 동일 자산)을 재사용해, 본문 속 용어 토큰 자체를 탭 가능한
// 하이라이트로 감싸고 탭하면 바텀시트로 쉬운 설명을 보여주는 방식을
// 택한다. 새 사전을 만들지 않고 기존 `EasyTerms` 캐시만 재사용한다.
//
// [재계산 없음] 이 위젯은 서버가 이미 만들어 준 `text` 문자열을 그대로
// 표시하고, 그 안에서 사전에 등록된 용어만 스캔해 하이라이트를 씌우는
// 순수 표시 로직이다 — 사주를 다시 계산하거나 문장을 새로 만들지 않는다.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../home/presentation/widgets/jeontong_easy_term_toggle.dart'
    show EasyTerms;

/// 사전에 등록된 용어 중, 본문에 실제로 등장하는 것만 길이 내림차순으로
/// 찾아 [TextSpan] 리스트로 쪼갠다(예: "무재격"이 "재"보다 먼저 매칭되게
/// 하기 위해 긴 용어를 먼저 검사).
class NarrativeTermText extends StatelessWidget {
  const NarrativeTermText({
    super.key,
    required this.text,
    this.style,
    this.highlightColor,
  });

  final String text;
  final TextStyle? style;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    final baseStyle = style ??
        Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.7) ??
        const TextStyle(height: 1.7);
    final hlColor = highlightColor ?? Theme.of(context).colorScheme.primary;

    final terms = EasyTerms.cachedOrNull;
    if (terms == null) {
      // 사전이 아직 로드되지 않았으면(프리로드 실패/타이밍) 평문 그대로.
      return Text(text, style: baseStyle);
    }

    final spans = _buildSpans(context, text, terms, baseStyle, hlColor);
    return Text.rich(TextSpan(children: spans), style: baseStyle);
  }

  List<InlineSpan> _buildSpans(
    BuildContext context,
    String text,
    EasyTerms terms,
    TextStyle baseStyle,
    Color hlColor,
  ) {
    // 사전에 있는 용어 중 이 텍스트에 실제로 등장하는 것만 후보로 삼고,
    // 긴 용어부터 매칭되도록 정렬(부분 문자열 충돌 방지, 예: "정인"과
    // "인" 같은 사례를 막기 위함 — 현재 사전엔 없지만 방어적으로 유지).
    final candidates = terms.allTerms
        .where((t) => t.isNotEmpty && text.contains(t))
        .toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    if (candidates.isEmpty) {
      return [TextSpan(text: text)];
    }

    // 한 번에 하나의 매치만 소비하도록 정규식 alternation을 구성.
    final escaped = candidates.map(RegExp.escape).join('|');
    final regex = RegExp(escaped);

    final spans = <InlineSpan>[];
    int cursor = 0;
    for (final match in regex.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      final token = match.group(0)!;
      spans.add(
        TextSpan(
          text: token,
          style: TextStyle(
            color: hlColor,
            fontWeight: FontWeight.w700,
            decoration: TextDecoration.underline,
            decorationColor: hlColor.withValues(alpha: 0.45),
            decorationStyle: TextDecorationStyle.dotted,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => _showTermSheet(context, token, terms),
        ),
      );
      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    return spans;
  }

  void _showTermSheet(BuildContext context, String token, EasyTerms terms) {
    final easy = terms.explain(token) ?? '쉬운 설명 준비 중';
    final detail = terms.detailOf(token);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        token,
                        style: Theme.of(sheetContext)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(sheetContext).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  easy,
                  style: Theme.of(sheetContext)
                      .textTheme
                      .titleSmall
                      ?.copyWith(color: Theme.of(sheetContext).colorScheme.primary),
                ),
                if (detail != null && detail.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    detail,
                    style: Theme.of(sheetContext).textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
