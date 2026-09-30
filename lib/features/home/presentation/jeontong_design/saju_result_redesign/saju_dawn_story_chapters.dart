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

  /// [정통사주 로딩 개선 — Dawn Paper 스켈레톤 호스트] 챕터가
  /// [DawnSectionStatus.error]일 때 "다시 시도" 버튼이 호출할 콜백. 챕터
  /// 별로 재시도 소스가 다르므로(一/四는 report+interpret+narrative, 二는
  /// interpret만) 호출부가 챕터 번호에 맞는 콜백을 결정해 넘긴다. null이면
  /// 재시도 버튼을 그리지 않는다.
  final void Function(StoryChapter chapter)? onRetryChapter;

  const SajuDawnStoryChapters({
    super.key,
    required this.chapters,
    required this.daeunTimeline,
    required this.ilganTheme,
    this.onRetryChapter,
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
              onRetry: onRetryChapter == null
                  ? null
                  : () => onRetryChapter!(chapters[i]),
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
  final VoidCallback? onRetry;

  const _StoryChapterBlock({
    required this.chapter,
    required this.isFirst,
    required this.isLast,
    required this.daeunTimeline,
    required this.ilganTheme,
    this.onRetry,
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
          // [정통사주 로딩 개선 — Dawn Paper 스켈레톤 호스트] 이 챕터의
          // 문장이 saju_v3 응답을 기다리는 중이거나(loading) 실패했으면
          // (error) 문단 대신 스켈레톤/에러 뷰를 그린다. 기존
          // [_JeontongV3PartCard]의 스켈레톤 패턴(문단 모양 회색 블록 3줄
          // + 안내 문구)을 그대로 이식한다 — 도착 시 같은 자리에서 텍스트로
          // 바뀌듯 전환되어 레이아웃이 흔들리지 않는다.
          if (chapter.status == DawnSectionStatus.loading)
            const _DawnStoryTextSkeleton()
          else if (chapter.status == DawnSectionStatus.error)
            _DawnStorySectionError(onRetry: onRetry)
          else
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

/// [정통사주 로딩 개선 — jeontong_v3_report_view.dart의 `_HanjiSkeletonBox`
/// 패턴 이식] 문단 모양(3줄, 마지막 줄은 짧게)의 회색 블록 + 안내 문구.
/// 색상만 Dawn Paper 팔레트([SajuDawnColors.line2])로 맞췄다 — 애니메이션
/// 로직(1200ms 펄스)은 원본과 동일하다.
class _DawnStoryTextSkeleton extends StatelessWidget {
  const _DawnStoryTextSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DawnSkeletonBox(height: 14, radius: 4),
          SizedBox(height: 8),
          _DawnSkeletonBox(height: 14, radius: 4),
          SizedBox(height: 8),
          _DawnSkeletonBox(height: 14, width: 160, radius: 4),
          SizedBox(height: 8),
          Text(
            '풀이를 준비하고 있어요...',
            style: TextStyle(fontSize: 12.5, color: SajuDawnColors.ink3),
          ),
        ],
      ),
    );
  }
}

/// [정통사주 로딩 개선] 관련 saju_v3 응답이 모두 실패했을 때만 표시되는
/// 챕터 단위 에러 뷰. 로컬 계산 섹션(壹·貳·參·陸·柒, 및 항상 ready인
/// 챕터 三)은 이 상태와 무관하게 항상 정상 표시된다 — 부분 실패에도 화면
/// 전체가 깨지지 않는다는 기존 원칙을 챕터 단위로 좁힌 것뿐이다.
class _DawnStorySectionError extends StatelessWidget {
  final VoidCallback? onRetry;
  const _DawnStorySectionError({this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Text(
            '이 부분을 불러오지 못했어요.',
            style: TextStyle(fontSize: 13, height: 1.5, color: SajuDawnColors.ink3),
          ),
        ),
        if (onRetry != null)
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: SajuDawnColors.goldDeep,
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('다시 시도', style: TextStyle(fontSize: 13)),
          ),
      ],
    );
  }
}

/// Hanji 결과 화면의 `_HanjiSkeletonBox`와 완전히 동일한 애니메이션
/// 로직(1200ms 펄스 opacity)을 쓰되, 베이스 컬러만 Dawn Paper 팔레트
/// ([SajuDawnColors.line2])로 바꾼 스켈레톤 블록.
class _DawnSkeletonBox extends StatefulWidget {
  const _DawnSkeletonBox({
    this.width = double.infinity,
    this.height = 16,
    this.radius = 6,
  });

  final double width;
  final double height;
  final double radius;

  @override
  State<_DawnSkeletonBox> createState() => _DawnSkeletonBoxState();
}

class _DawnSkeletonBoxState extends State<_DawnSkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final opacity = 0.35 + 0.3 * (t < 0.5 ? t * 2 : (1 - t) * 2);
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: SajuDawnColors.line2.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        );
      },
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
                    for (final entry in nodes.asMap().entries)
                      Positioned(
                        left: (entry.value.position * width - 9).clamp(
                          0.0,
                          width - 18,
                        ),
                        top: 0,
                        child: _TimelineNode(
                          node: entry.value,
                          ilganTheme: ilganTheme,
                          index: entry.key,
                        ),
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

/// [대운 타임라인 진입 애니메이션] 사용자 리포트 "대운의 흐름... 애니메이션
/// 넣어서 제대로 만들어"에 따라, 노드가 순서대로(index * 120ms 지연)
/// 아래에서 위로 살짝 슬라이드하며 페이드인한다. 별도 스크롤 감지 패키지
/// 없이 위젯 마운트 시점(이 섹션이 빌드되는 시점 — 이미
/// [SajuDawnSectionShell]이 [RevealOnScroll]로 섹션 전체를 스크롤 진입
/// 시에만 빌드하므로, 그 안쪽 노드가 처음 build될 때가 곧 "화면에 보이는
/// 시점"과 사실상 같다)을 기준으로 지연 후 표시한다.
class _TimelineNode extends StatefulWidget {
  final DaeunNode node;
  final IlganTheme ilganTheme;
  final int index;
  const _TimelineNode({
    required this.node,
    required this.ilganTheme,
    required this.index,
  });

  @override
  State<_TimelineNode> createState() => _TimelineNodeState();
}

class _TimelineNodeState extends State<_TimelineNode> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 120 * widget.index), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final ilganTheme = widget.ilganTheme;
    return AnimatedSlide(
      offset: _visible ? Offset.zero : const Offset(0, 0.4),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        child: AnimatedScale(
          scale: _visible ? 1 : 0.6,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutBack,
          child: SizedBox(
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
                    color: node.active
                        ? ilganTheme.main
                        : SajuDawnColors.paper,
                    border: Border.all(
                      color: node.active
                          ? ilganTheme.main
                          : SajuDawnColors.ink3,
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
          ),
        ),
      ),
    );
  }
}
