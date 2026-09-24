// ============================================================
// [정통사주 결과 화면 개편 - Dawn Paper] 肆(FOUR) 사주 풀이 4챕터.
//
// HTML `.story`(4개 `.story-chapter`, 점선 구분선, 드롭캡 첫 문단,
// 한자 하이라이트 `.han-hi`, 챕터 三에만 `.story-timeline`)를 그대로
// 옮긴다. 챕터 데이터는 `saju_dawn_data_builder.dart`가 이미 실계산
// 문장으로 채운 [StoryChapter]/[StoryParagraph]/[StoryRun]/[DaeunNode]를
// 그대로 그린다(재계산 없음 — 순수 렌더링).
// ============================================================

import 'package:flutter/material.dart';

import 'saju_dawn_data_models.dart';
import 'saju_dawn_ilgan_theme.dart';
import 'saju_dawn_section_shell.dart';
import 'saju_dawn_tokens.dart';

class SajuDawnStoryChapters extends StatelessWidget {
  final List<StoryChapter> chapters;
  final List<DaeunNode> daeunTimeline;
  final IlganTheme ilganTheme;

  const SajuDawnStoryChapters({
    super.key,
    required this.chapters,
    required this.daeunTimeline,
    required this.ilganTheme,
  });

  @override
  Widget build(BuildContext context) {
    return SajuDawnCard(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < chapters.length; i++)
            _StoryChapterBlock(
              chapter: chapters[i],
              isFirst: i == 0,
              isLast: i == chapters.length - 1,
              daeunTimeline: chapters[i].includeTimeline ? daeunTimeline : const [],
              ilganTheme: ilganTheme,
            ),
        ],
      ),
    );
  }
}

class _StoryChapterBlock extends StatelessWidget {
  final StoryChapter chapter;
  final bool isFirst;
  final bool isLast;
  final List<DaeunNode> daeunTimeline;
  final IlganTheme ilganTheme;

  const _StoryChapterBlock({
    required this.chapter,
    required this.isFirst,
    required this.isLast,
    required this.daeunTimeline,
    required this.ilganTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: isFirst ? 4 : 18, bottom: isLast ? 4 : 18),
      decoration: isLast
          ? null
          : const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: SajuDawnColors.line, width: 1),
              ),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '— ${chapter.chapterNum} —',
                style: const TextStyle(
                  fontFamily: SajuDawnFonts.serif,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.3,
                  color: SajuDawnColors.goldDeep,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(chapter.title, style: SajuDawnText.chapterTitle),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < chapter.paragraphs.length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i == chapter.paragraphs.length - 1 ? 0 : 10,
              ),
              child: _StoryParagraphText(
                paragraph: chapter.paragraphs[i],
              ),
            ),
          if (daeunTimeline.isNotEmpty) ...[
            const SizedBox(height: 14),
            _DaeunTimeline(nodes: daeunTimeline, ilganTheme: ilganTheme),
          ],
        ],
      ),
    );
  }
}

/// 문단 렌더링 — `dropCap`이면 첫 글자를 44px 세리프 드롭캡으로,
/// 나머지 런은 [StoryRun.hanjaHighlight]에 따라 하이라이트 배경을 적용.
class _StoryParagraphText extends StatelessWidget {
  final StoryParagraph paragraph;
  const _StoryParagraphText({required this.paragraph});

  @override
  Widget build(BuildContext context) {
    if (!paragraph.dropCap || paragraph.runs.isEmpty) {
      return _buildRichText(paragraph.runs);
    }

    // 드롭캡: 첫 run의 첫 글자만 분리해 44px 큰 글자로 띄운다.
    final runs = paragraph.runs;
    final firstRun = runs.first;
    if (firstRun.text.isEmpty) return _buildRichText(runs);

    final firstChar = firstRun.text.substring(0, 1);
    final restOfFirst = firstRun.text.substring(1);
    final remainingRuns = [
      if (restOfFirst.isNotEmpty)
        StoryRun(restOfFirst, hanjaHighlight: firstRun.hanjaHighlight),
      ...runs.skip(1),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 6, top: 2),
          child: Text(
            firstChar,
            style: const TextStyle(
              fontFamily: SajuDawnFonts.serif,
              fontSize: 40,
              fontWeight: FontWeight.w900,
              height: 0.9,
              color: SajuDawnColors.brown,
            ),
          ),
        ),
        Expanded(child: _buildRichText(remainingRuns)),
      ],
    );
  }

  Widget _buildRichText(List<StoryRun> runs) {
    return Text.rich(
      TextSpan(
        children: [
          for (final run in runs)
            run.hanjaHighlight
                ? WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: SajuDawnColors.gold.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        run.text,
                        style: const TextStyle(
                          fontFamily: SajuDawnFonts.serif,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: SajuDawnColors.brownDeep,
                          height: 1.85,
                        ),
                      ),
                    ),
                  )
                : TextSpan(text: run.text, style: SajuDawnText.storyBody),
        ],
      ),
    );
  }
}

/// 챕터 三 전용 — HTML `.story-timeline`(Life Timeline 트랙 + 최대 4노드).
class _DaeunTimeline extends StatelessWidget {
  final List<DaeunNode> nodes;
  final IlganTheme ilganTheme;

  const _DaeunTimeline({required this.nodes, required this.ilganTheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      decoration: BoxDecoration(
        color: SajuDawnColors.paper2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'LIFE TIMELINE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.32,
              color: SajuDawnColors.goldDeep,
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 40,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 8,
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          color: SajuDawnColors.line2,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    for (final node in nodes)
                      Positioned(
                        left: (node.position * width - 9).clamp(0.0, width - 18),
                        top: 0,
                        child: _TimelineNode(node: node, ilganTheme: ilganTheme),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineNode extends StatelessWidget {
  final DaeunNode node;
  final IlganTheme ilganTheme;
  const _TimelineNode({required this.node, required this.ilganTheme});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      child: Column(
        children: [
          Text(
            '${node.ageStart}세',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: SajuDawnColors.ink3,
            ),
          ),
          const SizedBox(height: 2),
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: node.active ? ilganTheme.main : SajuDawnColors.paper,
              border: Border.all(
                color: node.active ? ilganTheme.main : SajuDawnColors.ink3,
                width: 3,
              ),
              boxShadow: node.active
                  ? [
                      BoxShadow(
                        color: ilganTheme.main.withValues(alpha: 0.15),
                        blurRadius: 0,
                        spreadRadius: 4,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            node.hanja,
            style: const TextStyle(
              fontFamily: SajuDawnFonts.serif,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: SajuDawnColors.ink2,
            ),
          ),
        ],
      ),
    );
  }
}
