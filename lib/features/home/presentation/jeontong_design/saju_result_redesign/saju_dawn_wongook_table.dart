// ============================================================
// [정통사주 결과 화면 개편 - Dawn Paper] 貳(TWO) 사주 원국 표.
//
// HTML 레퍼런스의 `.wongook`(四柱 · 네 기둥 표, 時/日/月/年 4열 ×
// 天干/地支 2행)을 그대로 옮긴다. 원본은 `#pillars`에 별도
// IntersectionObserver를 달아 8칸을 80ms 간격으로 순차 등장시키고
// (`cells.forEach((c,i)=>setTimeout(...,i*80))`), 셀 탭 시 `data-tip`
// 텍스트를 툴팁으로 보여준다(2.4초 자동 dismiss).
//
// [애니메이션] 이 위젯은 자체 [VisibilityDetector]로 30% 노출 시점을
// 감지해([StaggeredCellReveal]과 동일한 스태거 로직 재사용) 8칸을
// 순차 등장시킨다 — 상위 [SajuDawnSectionShell]의 [RevealOnScroll]과는
// 별개의 트리거(원본 HTML의 별도 `pillarObs`와 동일한 설계).
//
// [툴팁] 원본은 커스텀 tap→OverlayEntry+setTimeout dismiss를 쓰지만,
// 이 프로젝트에서는 Flutter 표준 [Tooltip](triggerMode: tap,
// showDuration: 2.4초)으로 대체한다 — 동일한 tap-트리거 + 자동 dismiss
// 동작을 프레임워크 위젯으로 재현(새 OverlayEntry 관리 로직을 만들지
// 않기 위한 실용적 단순화).
//
// [재계산 금지] 셀에 표시되는 한자/한글/오행/십신 툴팁 문구는 전부
// `saju_dawn_data_builder.dart`가 이미 실계산 데이터로 채운
// [SajuDawnPillar] 필드를 그대로 그린다.
// ============================================================

import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'saju_dawn_animations.dart';
import 'saju_dawn_data_models.dart';
import 'saju_dawn_ilgan_theme.dart';
import 'saju_dawn_section_shell.dart';
import 'saju_dawn_tokens.dart';

class SajuDawnWongookTable extends StatefulWidget {
  final SajuResultData data;
  final String revealKey; // VisibilityDetector 고유 키(화면 내 유일).

  const SajuDawnWongookTable({
    super.key,
    required this.data,
    required this.revealKey,
  });

  @override
  State<SajuDawnWongookTable> createState() => _SajuDawnWongookTableState();
}

class _SajuDawnWongookTableState extends State<SajuDawnWongookTable> {
  bool _active = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    // README §4 열 순서: 時 · 日 · 月 · 年.
    final pillars = [
      data.timePillar,
      data.dayPillar,
      data.monthPillar,
      data.yearPillar,
    ];
    const colLabels = ['時', '日', '月', '年'];

    return VisibilityDetector(
      key: Key(widget.revealKey),
      onVisibilityChanged: (info) {
        if (info.visibleFraction >= 0.3 && !_active && mounted) {
          setState(() => _active = true);
        }
      },
      child: SajuDawnCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  '四柱 · 네 기둥',
                  style: TextStyle(
                    fontFamily: SajuDawnFonts.serif,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.15,
                    color: SajuDawnColors.ink,
                  ),
                ),
                const Text(
                  '탭하면 뜻이 나와요',
                  style: TextStyle(fontSize: 11, color: SajuDawnColors.ink3),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _PillarsGrid(
              pillars: pillars,
              colLabels: colLabels,
              ilganTheme: data.ilganTheme,
              active: _active,
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.only(top: 12),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: SajuDawnColors.line, width: 1),
                ),
              ),
              child: Wrap(
                spacing: 10,
                runSpacing: 6,
                children: [
                  for (final el in SajuDawnElement.values) _LegendDot(el: el),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final SajuDawnElement el;
  const _LegendDot({required this.el});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: el.color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '${el.hangul}(${el.hanja})',
          style: const TextStyle(fontSize: 11, color: SajuDawnColors.ink3),
        ),
      ],
    );
  }
}

class _PillarsGrid extends StatelessWidget {
  final List<SajuDawnPillar> pillars; // [時,日,月,年]
  final List<String> colLabels;
  final IlganTheme ilganTheme;
  final bool active;

  const _PillarsGrid({
    required this.pillars,
    required this.colLabels,
    required this.ilganTheme,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: const {0: FixedColumnWidth(28)},
      children: [
        TableRow(
          children: [
            const SizedBox(height: 24),
            for (final label in colLabels) _ColLabel(label: label),
          ],
        ),
        const TableRow(children: [SizedBox(height: 6), SizedBox(), SizedBox(), SizedBox(), SizedBox()]),
        TableRow(
          children: [
            const _RowLabel(text: '天干'),
            for (var i = 0; i < pillars.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: StaggeredCellReveal(
                  index: i,
                  active: active,
                  child: _PillarCell(
                    hanja: pillars[i].stemHanja,
                    hangul: pillars[i].stemHangul,
                    element: pillars[i].stemElement,
                    tip: pillars[i].stemTip,
                    highlight: i == 1, // 日 열의 天干 = 일간 자신.
                    ilganTheme: ilganTheme,
                  ),
                ),
              ),
          ],
        ),
        const TableRow(children: [SizedBox(height: 6), SizedBox(), SizedBox(), SizedBox(), SizedBox()]),
        TableRow(
          children: [
            const _RowLabel(text: '地支'),
            for (var i = 0; i < pillars.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: StaggeredCellReveal(
                  index: 4 + i,
                  active: active,
                  child: _PillarCell(
                    hanja: pillars[i].branchHanja,
                    hangul: pillars[i].branchHangul,
                    element: pillars[i].branchElement,
                    tip: pillars[i].branchTip,
                    highlight: false,
                    ilganTheme: ilganTheme,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ColLabel extends StatelessWidget {
  final String label;
  const _ColLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: SajuDawnFonts.serif,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.88,
          color: SajuDawnColors.ink3,
        ),
      ),
    );
  }
}

class _RowLabel extends StatelessWidget {
  final String text; // "天干" / "地支"
  const _RowLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '${text.substring(0, 1)}\n${text.substring(1)}',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: SajuDawnFonts.serif,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          height: 1.2,
          color: SajuDawnColors.ink3,
        ),
      ),
    );
  }
}

class _PillarCell extends StatelessWidget {
  final String hanja;
  final String hangul;
  final SajuDawnElement element;
  final String tip;
  final bool highlight;
  final IlganTheme ilganTheme;

  const _PillarCell({
    required this.hanja,
    required this.hangul,
    required this.element,
    required this.tip,
    required this.highlight,
    required this.ilganTheme,
  });

  @override
  Widget build(BuildContext context) {
    final bg = highlight ? ilganTheme.soft : SajuDawnColors.paper2;
    final border = highlight ? ilganTheme.main : SajuDawnColors.line;
    final hanjaColor = highlight ? ilganTheme.main : SajuDawnColors.ink;
    final hangulColor = highlight ? ilganTheme.main : SajuDawnColors.ink3;

    return Tooltip(
      message: tip,
      triggerMode: TooltipTriggerMode.tap,
      showDuration: SajuDawnMotion.tooltipAutoDismiss,
      preferBelow: false,
      decoration: BoxDecoration(
        color: SajuDawnColors.ink,
        borderRadius: BorderRadius.circular(10),
      ),
      textStyle: const TextStyle(color: SajuDawnColors.paper, fontSize: 12, height: 1.5),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(SajuDawnRadius.cell),
          border: Border.all(color: border, width: highlight ? 1.5 : 1),
          boxShadow: highlight
              ? [
                  BoxShadow(
                    color: ilganTheme.main.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: -8,
              right: -0,
              child: Container(
                width: 12,
                height: 12,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: element.color,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  element.hanja,
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
              ),
            ),
            Column(
              children: [
                Text(
                  hanja,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: SajuDawnFonts.serif,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    height: 1,
                    color: hanjaColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hangul,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 0.04,
                    fontWeight: highlight ? FontWeight.w600 : FontWeight.w400,
                    color: hangulColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
