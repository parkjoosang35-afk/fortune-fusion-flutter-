// ============================================================
// [정통사주 결과 화면 개편 - Dawn Paper] 參(THREE) 오행 분포.
//
// HTML `.ohaeng-card`(5개 막대 그래프 + 균형점 배지 + 진단 문구)를
// 그대로 옮긴다. 막대 성장 애니메이션은 이미 존재하는 [OhaengBar]
// (`saju_dawn_animations.dart`)를 그대로 재사용 — 이 파일은 그 값
// (오행별 count → heightRatio) 계산과 레이아웃만 담당한다.
//
// [재계산 금지] count는 `saju_dawn_data_builder.dart`의
// [SajuResultData.ohaengCounts]/[.ohaengDiagnosis]/[.balanceScore]를
// 그대로 조회한다 — 이 위젯은 막대 높이 비율(정규화)만 계산한다.
// ============================================================

import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'saju_dawn_animations.dart';
import 'saju_dawn_data_models.dart';
import 'saju_dawn_section_shell.dart';
import 'saju_dawn_tokens.dart';

class SajuDawnOhaengChart extends StatefulWidget {
  final SajuResultData data;
  final String revealKey;

  const SajuDawnOhaengChart({
    super.key,
    required this.data,
    required this.revealKey,
  });

  @override
  State<SajuDawnOhaengChart> createState() => _SajuDawnOhaengChartState();
}

class _SajuDawnOhaengChartState extends State<SajuDawnOhaengChart> {
  bool _active = false;

  @override
  Widget build(BuildContext context) {
    final counts = widget.data.ohaengCounts;
    final maxCount = counts.values.isEmpty
        ? 0
        : counts.values.reduce((a, b) => a > b ? a : b);
    // HTML 원본은 최댓값을 68%로 스케일하고 나머지는 비례(예: 3→68%,
    // 2→45%, 1→22%, 0→10%(바닥선만 살짝 보이는 최소치)). 여기서는
    // 동일한 시각적 의도를 "최댓값 대비 비율 + 0일 때 최소 10%"로
    // 일반화해 재현한다(순수 정규화 — 새 오행 판단 아님).
    double ratioOf(int v) {
      if (maxCount <= 0) return 0.1;
      if (v <= 0) return 0.1;
      return 0.15 + (v / maxCount) * 0.85;
    }

    return VisibilityDetector(
      key: Key(widget.revealKey),
      onVisibilityChanged: (info) {
        if (info.visibleFraction >= 0.35 && !_active && mounted) {
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
                  '五行 · 다섯 기운',
                  style: TextStyle(
                    fontFamily: SajuDawnFonts.serif,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.15,
                    color: SajuDawnColors.ink,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: SajuDawnColors.gold.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(SajuDawnRadius.pill),
                  ),
                  child: Text(
                    '균형점 ${widget.data.balanceScore}%',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.22,
                      color: SajuDawnColors.goldDeep,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 140,
              child: Stack(
                children: [
                  const Positioned(
                    left: 4,
                    right: 4,
                    bottom: 30,
                    child: _DashedBaseline(),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: [
                        for (var i = 0; i < SajuDawnElement.values.length; i++)
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                left: i == 0 ? 0 : 5,
                                right: i == SajuDawnElement.values.length - 1 ? 0 : 5,
                              ),
                              child: OhaengBar(
                                element: SajuDawnElement.values[i],
                                value: counts[SajuDawnElement.values[i]] ?? 0,
                                heightRatio: ratioOf(counts[SajuDawnElement.values[i]] ?? 0),
                                index: i,
                                active: _active,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: SajuDawnColors.paper2,
                borderRadius: BorderRadius.circular(12),
                border: const Border(
                  left: BorderSide(color: SajuDawnColors.gold, width: 2.5),
                ),
              ),
              child: Text(
                widget.data.ohaengDiagnosis,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.7,
                  color: SajuDawnColors.ink2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedBaseline extends StatelessWidget {
  const _DashedBaseline();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 1),
      painter: _DashedLinePainter(),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = SajuDawnColors.line.withValues(alpha: 0.7)
      ..strokeWidth = 1;
    const dashWidth = 4.0;
    const dashGap = 4.0;
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, 0),
        Offset(startX + dashWidth, 0),
        paint,
      );
      startX += dashWidth + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
