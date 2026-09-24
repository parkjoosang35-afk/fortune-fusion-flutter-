// ============================================================
// [정통사주 결과 화면 개편 - Dawn Paper] 壹~柒 전체 조립 페이지.
//
// HTML `.app`(topbar sticky + hero + 7개 section + footer + 고정
// actions)의 전체 스크롤 구조를 그대로 옮긴다. 이 위젯은 이미 만들어진
// [SajuResultData]를 받아 그리기만 한다(재계산 없음) — 데이터 조립은
// `saju_dawn_data_builder.dart`, 실계산은 PHASE1~4가 전담한다.
//
// [스크롤 감지] 원본은 `window.scrollY > 6`으로 topbar에 하단 테두리를
// 준다. 이 위젯은 [ScrollController]를 직접 소유해 그 값을 [SajuDawnTopBar
// .scrolled]로 넘긴다(README §9 "호출부가 이미 가진 ScrollController를
// 재사용" 원칙 — 이 페이지가 최상위 스크롤 컨테이너이므로 직접 소유).
//
// [사용 예]
// ```dart
// SajuDawnResultPage(
//   data: buildSajuDawnResultDataFromDeepReport(...), // 또는 FromParagraphs
//   strengthLabel: '신강(身强)',
//   typeLabel: '조력형 助力型',
//   bookmarkButton: IconButton(key: ValueKey('jeontong_bookmark_toggle'), ...),
//   onRelatedTap: (r) => Navigator.pushNamed(context, ...),
//   onPrimaryAction: () => Navigator.of(context).pop(),
// )
// ```
// ============================================================

import 'package:flutter/material.dart';

import 'saju_dawn_advice_lucky_related.dart';
import 'saju_dawn_data_models.dart';
import 'saju_dawn_ilgan_card.dart';
import 'saju_dawn_ohaeng_chart.dart';
import 'saju_dawn_section_shell.dart';
import 'saju_dawn_story_chapters.dart';
import 'saju_dawn_tokens.dart';
import 'saju_dawn_topbar_hero.dart';
import 'saju_dawn_wongook_table.dart';

class SajuDawnResultPage extends StatefulWidget {
  final SajuResultData data;

  /// 이미 계산된 신강/신약 등 강약 라벨 문자열(예: "신강(身强)") — 재계산 없음.
  final String strengthLabel;

  /// 조력형/주도형 등 유형 라벨(있으면 표시, 없으면 생략).
  final String? typeLabel;

  /// 기존 화면의 `ValueKey('jeontong_bookmark_toggle')` 계약을 유지하기
  /// 위해 호출부가 그대로 만든 위젯을 주입받는다(TopBar trailing 슬롯).
  final Widget? bookmarkButton;

  final VoidCallback? onBack;
  final void Function(RelatedFortune)? onRelatedTap;
  final VoidCallback? onPrimaryAction;
  final VoidCallback? onSave;
  final VoidCallback? onShare;

  const SajuDawnResultPage({
    super.key,
    required this.data,
    required this.strengthLabel,
    this.typeLabel,
    this.bookmarkButton,
    this.onBack,
    this.onRelatedTap,
    this.onPrimaryAction,
    this.onSave,
    this.onShare,
  });

  @override
  State<SajuDawnResultPage> createState() => _SajuDawnResultPageState();
}

class _SajuDawnResultPageState extends State<SajuDawnResultPage> {
  final ScrollController _scrollController = ScrollController();
  bool _scrolled = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  void _handleScroll() {
    final scrolled = _scrollController.offset > 6;
    if (scrolled != _scrolled) {
      setState(() => _scrolled = scrolled);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final theme = data.ilganTheme;

    return Scaffold(
      backgroundColor: SajuDawnColors.bg,
      appBar: SajuDawnTopBar(
        scrolled: _scrolled,
        onBack: widget.onBack,
        trailing: widget.bookmarkButton,
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Stack(
          children: [
            ListView(
              controller: _scrollController,
              padding: const EdgeInsets.only(bottom: 140),
              children: [
                SajuDawnHero(
                  data: data,
                  strengthLabel: widget.strengthLabel,
                  typeLabel: widget.typeLabel,
                ),
                SajuDawnSectionShell(
                  num: '壹 · ONE',
                  name: '당신의 일간',
                  revealKey: 'dawn_section_1_${data.categoryCode}',
                  child: Padding(
                    padding: const EdgeInsets.only(top: 0),
                    child: SajuDawnIlganCard(data: data),
                  ),
                ),
                SajuDawnSectionShell(
                  num: '貳 · TWO',
                  name: '사주 원국',
                  revealKey: 'dawn_section_2_${data.categoryCode}',
                  child: SajuDawnWongookTable(
                    data: data,
                    revealKey: 'dawn_wongook_${data.categoryCode}',
                  ),
                ),
                SajuDawnSectionShell(
                  num: '參 · THREE',
                  name: '오행 분포',
                  revealKey: 'dawn_section_3_${data.categoryCode}',
                  child: SajuDawnOhaengChart(
                    data: data,
                    revealKey: 'dawn_ohaeng_${data.categoryCode}',
                  ),
                ),
                SajuDawnSectionShell(
                  num: '肆 · FOUR',
                  name: '사주 풀이',
                  revealKey: 'dawn_section_4_${data.categoryCode}',
                  child: SajuDawnStoryChapters(
                    chapters: data.chapters,
                    daeunTimeline: data.daeunTimeline,
                    ilganTheme: theme,
                  ),
                ),
                SajuDawnSectionShell(
                  num: '伍 · FIVE',
                  name: '실전 조언',
                  revealKey: 'dawn_section_5_${data.categoryCode}',
                  child: SajuDawnAdviceGrid(
                    doList: data.doList,
                    avoidList: data.avoidList,
                    ilganTheme: theme,
                  ),
                ),
                SajuDawnSectionShell(
                  num: '陸 · SIX',
                  name: '행운 요소',
                  revealKey: 'dawn_section_6_${data.categoryCode}',
                  child: SajuDawnLuckyGrid(lucky: data.lucky, ilganTheme: theme),
                ),
                SajuDawnSectionShell(
                  num: '柒 · SEVEN',
                  name: '함께 보면 좋은 운세',
                  revealKey: 'dawn_section_7_${data.categoryCode}',
                  child: SajuDawnRelatedGrid(
                    related: data.related,
                    onTap: widget.onRelatedTap,
                  ),
                ),
                SajuDawnFooterMeta(userRefId: data.userRefId),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SajuDawnBottomActionBar(
                onPrimary: widget.onPrimaryAction,
                onSave: widget.onSave,
                onShare: widget.onShare,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
