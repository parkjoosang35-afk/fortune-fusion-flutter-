// ============================================================
// 정통사주 전용 · 세운(歲運) 월별 그리드
// 원본: flutter_handoff.zip theme의 _SeunGrid/_MonthCell/_Legend를
// 이식하되, 새 handoff의 SeunMonth/SeunTone(가짜 데이터 모델)은
// 채택하지 않는다. 대신 PHASE1~4에서 이미 계산된
// [SajuProfile.wolwoon](월운 12개월, WolwoonEntry)과
// [SajuProfile.yongsin](억부+조후 종합 용신/희신/기신/구신)을 그대로
// 조합해 각 월의 길흉 톤을 산출한다 — 새로운 판정 공식이 아니라,
// 이미 계산된 용신 체계를 색상으로 시각화하는 것뿐이다.
// ============================================================

import 'package:flutter/material.dart';

import '../../domain/manseryeok/saju_profile.dart'
    show Pillar, WolwoonEntry, YongsinProfile;
import 'hanji_card.dart';
import 'hanji_design_tokens.dart';
import 'saju_seal.dart';

/// 이 월(月)이 사용자에게 유리한지/보통인지/주의가 필요한지를 나타내는
/// 표시용 톤. 새 handoff의 `SeunTone`과 이름이 겹치지 않도록 `Hanji`
/// 접두어를 붙인다.
enum HanjiTone { best, ok, warn }

/// [Pillar]의 천간/지지 오행을 이미 계산된 [YongsinProfile]
/// (용신/희신/기신/구신)과 대조해 [HanjiTone]을 산출한다.
///
/// - 천간 또는 지지 오행이 용신·희신과 일치 → best(최상)
/// - 천간 또는 지지 오행이 기신·구신과 일치 → warn(주의)
/// - 그 외 → ok(순조)
///
/// [절대 원칙] 이 함수는 새로운 길흉 판정 공식을 만들지 않는다.
/// 용신/희신/기신/구신은 이미 [YongsinEngine.combine]에서 전통
/// 억부법·조후법에 따라 계산되어 있으며, 여기서는 그 결과를 단순
/// 조회해 색으로 매핑할 뿐이다.
HanjiTone toneForPillar(Pillar pillar, YongsinProfile yongsin) {
  final elements = {pillar.stemElement, pillar.branchElement};
  if (elements.contains(yongsin.yongsin) || elements.contains(yongsin.heesin)) {
    return HanjiTone.best;
  }
  if (elements.contains(yongsin.gisin) || elements.contains(yongsin.gusin)) {
    return HanjiTone.warn;
  }
  return HanjiTone.ok;
}

/// [WolwoonEntry] 12개월 전체를 6열 그리드로 표시한다.
class SeunGrid extends StatelessWidget {
  final List<WolwoonEntry> wolwoon;
  final YongsinProfile yongsin;
  final int year;

  const SeunGrid({
    super.key,
    required this.wolwoon,
    required this.yongsin,
    required this.year,
  });

  @override
  Widget build(BuildContext context) {
    return HanjiCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [MonoLabel('MONTH · N°01 - 12'), MonoLabel('$year년 월운')],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: wolwoon.map((entry) {
              final tone = toneForPillar(entry.pillar, yongsin);
              return SizedBox(
                width:
                    (MediaQuery.of(context).size.width -
                        HanjiSpacing.xl * 2 -
                        HanjiSpacing.lg * 2 -
                        6 * 5) /
                    6,
                child: _MonthCell(entry: entry, tone: tone),
              );
            }).toList(),
          ),
          const Divider(color: HanjiColors.line, height: 24),
          const Row(
            children: [
              _Legend(color: HanjiColors.glow, label: '최상'),
              SizedBox(width: 10),
              _Legend(color: HanjiColors.su, label: '순조'),
              SizedBox(width: 10),
              _Legend(color: HanjiColors.accent, label: '주의'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthCell extends StatelessWidget {
  final WolwoonEntry entry;
  final HanjiTone tone;
  const _MonthCell({required this.entry, required this.tone});

  @override
  Widget build(BuildContext context) {
    final (bg, bd, color) = switch (tone) {
      HanjiTone.best => (
        HanjiColors.glow.withValues(alpha: 0.18),
        HanjiColors.glow,
        const Color(0xFF8B5A2B),
      ),
      HanjiTone.warn => (
        HanjiColors.accent.withValues(alpha: 0.1),
        HanjiColors.accent.withValues(alpha: 0.4),
        HanjiColors.accent,
      ),
      HanjiTone.ok => (
        HanjiColors.su.withValues(alpha: 0.1),
        HanjiColors.su.withValues(alpha: 0.4),
        HanjiColors.su,
      ),
    };
    // 그레고리력 달력 월이 아니라 전통 월건 순서(1=寅월 ...)이므로,
    // 절기 이름을 함께 보여줘 혼동을 방지한다.
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: bd),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              entry.jieQiName,
              style: HanjiTextStyles.bodyTitle(
                color: color,
              ).copyWith(fontSize: 11),
            ),
            const SizedBox(height: 2),
            Text(
              entry.pillar.hanja,
              style: HanjiTextStyles.display1(
                color: HanjiColors.wuxingColor(entry.pillar.branchElement),
              ).copyWith(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: HanjiTextStyles.bodySmall().copyWith(fontSize: 10)),
      ],
    );
  }
}
