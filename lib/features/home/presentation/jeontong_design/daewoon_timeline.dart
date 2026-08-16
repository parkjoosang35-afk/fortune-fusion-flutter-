// ============================================================
// 대운(大運) 타임라인 — 정통사주 전용 Dawn Hanji 디자인.
//
// [재계산 금지 원칙] 레거시 `saju_engine.dart`의
// `SajuResult.luckPillars`(List<SajuLuckPillar>{startAge, startYear,
// ganZhi, ganZhiKr})와 `SajuResult.currentAge`/`currentLuck`을 그대로
// 사용한다. 원본 디자인의 자체 `Daewoon(age, gan, ji, wuxing, label,
// isCurrent)` 모델은 도입하지 않는다 — 천간/지지 오행은 레거시
// `saju_engine.dart`의 `ganElement`/`zhiElement` 테이블을 그대로 재사용해
// 별도 계산 없이 조회만 한다.
// ============================================================

import 'package:flutter/material.dart';

import '../../domain/saju_engine.dart'
    show SajuLuckPillar, ganElement, zhiElement;
import 'hanji_card.dart';
import 'hanji_design_tokens.dart';
import 'saju_seal.dart';

/// [SajuLuckPillar.ganZhi]는 한자 2글자('임자' 아닌 '壬子' 형태) —
/// 첫 글자가 천간, 둘째 글자가 지지.
String _ganOf(SajuLuckPillar p) => p.ganZhi.isNotEmpty ? p.ganZhi.substring(0, 1) : '';
String _zhiOf(SajuLuckPillar p) => p.ganZhi.length >= 2 ? p.ganZhi.substring(1, 2) : '';
String _ganKrOf(SajuLuckPillar p) => p.ganZhiKr.isNotEmpty ? p.ganZhiKr.substring(0, 1) : '';
String _zhiKrOf(SajuLuckPillar p) => p.ganZhiKr.length >= 2 ? p.ganZhiKr.substring(1, 2) : '';

class DaewoonTimeline extends StatelessWidget {
  final List<SajuLuckPillar> daewoon;
  final int currentAge;

  const DaewoonTimeline({
    super.key,
    required this.daewoon,
    required this.currentAge,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          for (final d in daewoon) ...[
            _DaewoonCell(d: d, currentAge: currentAge),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _DaewoonCell extends StatelessWidget {
  final SajuLuckPillar d;
  final int currentAge;
  const _DaewoonCell({required this.d, required this.currentAge});

  @override
  Widget build(BuildContext context) {
    final isNow = currentAge >= d.startAge && currentAge < d.startAge + 10;
    final isPast = d.startAge + 10 <= currentAge && !isNow;
    final gan = _ganOf(d);
    final zhi = _zhiOf(d);
    final wxColor = HanjiColors.wuxingColor(zhiElement[zhi]?.$1);
    final ganColor = HanjiColors.wuxingColor(ganElement[gan]?.$1);

    return Opacity(
      opacity: isPast ? 0.45 : 1,
      child: SizedBox(
        width: 62,
        child: Column(
          children: [
            Container(
              height: 76,
              decoration: BoxDecoration(
                color: isNow
                    ? HanjiColors.glow.withValues(alpha: 0.18)
                    : wxColor.withValues(alpha: 0.14),
                border: Border.all(
                  color: isNow ? HanjiColors.glow : wxColor.withValues(alpha: 0.35),
                  width: isNow ? 1.5 : 1,
                ),
                borderRadius: BorderRadius.circular(HanjiRadii.chip),
                boxShadow: isNow
                    ? [BoxShadow(color: HanjiColors.glowShadow, blurRadius: 14)]
                    : null,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_ganKrOf(d),
                          style: HanjiTextStyles.display1(color: ganColor).copyWith(fontSize: 18)),
                      Container(width: 20, height: 0.5, color: const Color(0x4C8B5A2B)),
                      const SizedBox(height: 1),
                      Text(_zhiKrOf(d),
                          style: HanjiTextStyles.display1(color: wxColor).copyWith(fontSize: 15)),
                    ],
                  ),
                  if (isNow)
                    Positioned(
                      top: -8,
                      right: -6,
                      child: Transform.rotate(
                        angle: 0.1,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: HanjiColors.accent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'NOW',
                            style: TextStyle(
                              color: Color(0xFFFFF9E8),
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${d.startAge}세~',
              style: HanjiTextStyles.bodyTitle(color: isNow ? HanjiColors.fg : HanjiColors.muted)
                  .copyWith(fontSize: 11),
            ),
            Text(d.ganZhiKr, style: HanjiTextStyles.bodySmall().copyWith(fontSize: 9)),
          ],
        ),
      ),
    );
  }
}

class CurrentDaewoonCard extends StatelessWidget {
  final SajuLuckPillar d;
  const CurrentDaewoonCard({super.key, required this.d});

  @override
  Widget build(BuildContext context) {
    final gan = _ganOf(d);
    final zhi = _zhiOf(d);
    final ganColor = HanjiColors.wuxingColor(ganElement[gan]?.$1);
    final zhiColor = HanjiColors.wuxingColor(zhiElement[zhi]?.$1);
    return HanjiCard(
      glow: true,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 66,
            decoration: BoxDecoration(
              color: zhiColor.withValues(alpha: 0.15),
              border: Border.all(color: zhiColor.withValues(alpha: 0.4), width: 1.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_ganKrOf(d), style: HanjiTextStyles.display1(color: ganColor).copyWith(fontSize: 20)),
                Container(width: 20, height: 1, color: const Color(0x408B5A2B)),
                Text(_zhiKrOf(d), style: HanjiTextStyles.display1(color: zhiColor).copyWith(fontSize: 16)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MonoLabel('◈ 현재 대운 · ${d.startAge} ~ ${d.startAge + 9}세',
                    color: HanjiColors.accent),
                const SizedBox(height: 4),
                Text('${d.ganZhiKr} 대운',
                    style: HanjiTextStyles.bodyTitle().copyWith(fontSize: 15)),
                const SizedBox(height: 6),
                Text(
                  '이 10년의 흐름을 잘 살펴 주세요.',
                  style: HanjiTextStyles.bodySmall().copyWith(fontSize: 12, height: 1.6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
