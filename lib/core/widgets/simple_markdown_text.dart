import 'package:flutter/material.dart';
import '../theme/app_unified_style.dart';

/// [마크다운 렌더링 개선] AI(completeText)가 생성하는 응답에는 `#`, `##`, `**굵게**`,
/// `---`, `- 목록`, `| 표 |` 같은 마크다운 문법이 섞여 있다. 기존에는 결과 화면들이
/// 이 문자열을 순수 [Text]로 그대로 출력해 `#`/`**` 등의 원문 기호가 화면에 노출되는
/// 문제가 있었다.
///
/// 이 위젯은 별도 마크다운 패키지 의존성 추가 없이, 이 앱의 AI 결과 텍스트에서
/// 실제로 쓰이는 문법(헤더/굵게/구분선/목록/간단한 표)만 가볍게 파싱해 앱 공용
/// 디자인 토큰([UnifiedText]/[UnifiedColors])으로 자연스럽게 렌더링한다.
/// [ResultCardStack]의 히어로 요약/세부 리포트 본문 등 AI 텍스트를 표시하는 모든
/// 곳에서 공통으로 재사용한다.
class SimpleMarkdownText extends StatelessWidget {
  const SimpleMarkdownText({
    super.key,
    required this.data,
    this.baseStyle,
  });

  /// 렌더링할 원본 텍스트(마크다운 문법 포함 가능)
  final String data;

  /// 본문 기본 스타일(미지정 시 [UnifiedText.body] 사용)
  final TextStyle? baseStyle;

  @override
  Widget build(BuildContext context) {
    final style = baseStyle ?? UnifiedText.body();
    final lines = data.replaceAll('\r\n', '\n').split('\n');
    final widgets = <Widget>[];

    List<List<String>>? tableBuffer;

    void flushTable() {
      if (tableBuffer == null || tableBuffer!.isEmpty) {
        tableBuffer = null;
        return;
      }
      widgets.add(_MarkdownTable(rows: tableBuffer!, baseStyle: style));
      tableBuffer = null;
    }

    for (final rawLine in lines) {
      final line = rawLine.trimRight();
      final trimmed = line.trim();

      // 표 행(| a | b |) 감지 — 연속된 표 행을 모아 하나의 테이블로 렌더링.
      if (trimmed.startsWith('|') && trimmed.endsWith('|') && trimmed.length > 1) {
        final cells = trimmed
            .substring(1, trimmed.length - 1)
            .split('|')
            .map((c) => c.trim())
            .toList();
        // 구분행(|---|---|) 은 건너뛴다.
        final isDivider = cells.every(
          (c) => c.isEmpty || RegExp(r'^:?-{2,}:?$').hasMatch(c),
        );
        if (!isDivider) {
          (tableBuffer ??= []).add(cells);
        }
        continue;
      } else if (tableBuffer != null) {
        flushTable();
      }

      if (trimmed.isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }

      // 구분선(--- / *** / ___)
      if (RegExp(r'^(-{3,}|\*{3,}|_{3,})$').hasMatch(trimmed)) {
        widgets.add(
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            height: 1,
            color: UnifiedColors.border,
          ),
        );
        continue;
      }

      // 헤더(#, ##, ### ...)
      final headerMatch = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(trimmed);
      if (headerMatch != null) {
        final level = headerMatch.group(1)!.length;
        final content = headerMatch.group(2)!.trim();
        final headerStyle = level <= 2
            ? UnifiedText.title(color: style.color ?? UnifiedColors.textPrimary)
            : UnifiedText.bodyStrong(color: style.color ?? UnifiedColors.textPrimary);
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: _InlineRichText(text: content, baseStyle: headerStyle),
          ),
        );
        continue;
      }

      // 목록(- / * / • 접두)
      final bulletMatch = RegExp(r'^[-*•]\s+(.*)$').firstMatch(trimmed);
      if (bulletMatch != null) {
        final content = bulletMatch.group(1)!.trim();
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('•  ', style: style),
                Expanded(child: _InlineRichText(text: content, baseStyle: style)),
              ],
            ),
          ),
        );
        continue;
      }

      // 숫자 목록(1. / 2) 등)
      final numberedMatch = RegExp(r'^(\d+)[.)]\s+(.*)$').firstMatch(trimmed);
      if (numberedMatch != null) {
        final number = numberedMatch.group(1)!;
        final content = numberedMatch.group(2)!.trim();
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$number. ', style: style),
                Expanded(child: _InlineRichText(text: content, baseStyle: style)),
              ],
            ),
          ),
        );
        continue;
      }

      // 인용(> )
      if (trimmed.startsWith('> ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Container(
              padding: const EdgeInsets.only(left: 10),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: UnifiedColors.border, width: 2),
                ),
              ),
              child: _InlineRichText(
                text: trimmed.substring(2).trim(),
                baseStyle: style.copyWith(color: UnifiedColors.textSecondary),
              ),
            ),
          ),
        );
        continue;
      }

      // 일반 문단
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: _InlineRichText(text: trimmed, baseStyle: style),
        ),
      );
    }

    flushTable();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: widgets,
    );
  }
}

/// 한 줄 내 인라인 문법(`**굵게**`, `*기울임*`, `` `코드` ``)을 파싱해
/// [RichText]로 렌더링한다. 지원하지 않는 문법은 원문 그대로 노출한다.
class _InlineRichText extends StatelessWidget {
  const _InlineRichText({required this.text, required this.baseStyle});

  final String text;
  final TextStyle baseStyle;

  @override
  Widget build(BuildContext context) {
    return RichText(text: TextSpan(children: _parseInline(text, baseStyle)));
  }

  static List<InlineSpan> _parseInline(String input, TextStyle base) {
    final spans = <InlineSpan>[];
    // **bold** 또는 __bold__ 를 우선 처리, 그 다음 *italic*/_italic_, `code`.
    final pattern = RegExp(
      r'(\*\*.+?\*\*|__.+?__|\*[^*\n]+?\*|_[^_\n]+?_|`[^`\n]+?`)',
    );
    int start = 0;
    for (final match in pattern.allMatches(input)) {
      if (match.start > start) {
        spans.add(TextSpan(text: input.substring(start, match.start), style: base));
      }
      final token = match.group(0)!;
      if (token.startsWith('**') || token.startsWith('__')) {
        spans.add(
          TextSpan(
            text: token.substring(2, token.length - 2),
            style: base.copyWith(fontWeight: FontWeight.w700),
          ),
        );
      } else if (token.startsWith('`')) {
        spans.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: base.copyWith(
              fontFamily: 'monospace',
              backgroundColor: UnifiedColors.cardAllMenu,
            ),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: base.copyWith(fontStyle: FontStyle.italic),
          ),
        );
      }
      start = match.end;
    }
    if (start < input.length) {
      spans.add(TextSpan(text: input.substring(start), style: base));
    }
    return spans;
  }
}

/// `| a | b |` 형태의 간단한 마크다운 표를 렌더링한다.
/// 첫 행을 헤더로 취급해 SemiBold로 강조한다.
class _MarkdownTable extends StatelessWidget {
  const _MarkdownTable({required this.rows, required this.baseStyle});

  final List<List<String>> rows;
  final TextStyle baseStyle;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final columnCount = rows.map((r) => r.length).reduce((a, b) => a > b ? a : b);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(UnifiedTokens.radiusSm),
        border: Border.all(color: UnifiedColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (int r = 0; r < rows.length; r++)
            Container(
              decoration: BoxDecoration(
                color: r == 0 ? UnifiedColors.cardAllMenu : Colors.transparent,
                border: r == rows.length - 1
                    ? null
                    : Border(bottom: BorderSide(color: UnifiedColors.border)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  for (int c = 0; c < columnCount; c++)
                    Expanded(
                      child: _InlineRichText(
                        text: c < rows[r].length ? rows[r][c] : '',
                        baseStyle: r == 0
                            ? baseStyle.copyWith(fontWeight: FontWeight.w700)
                            : baseStyle,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
