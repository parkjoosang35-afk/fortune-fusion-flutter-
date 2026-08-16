// ============================================================
// 정통사주 전용 · 이달/오늘 요약 카드
// 원본: flutter_handoff.zip theme의 _TodayCard를 이식하되, 새 handoff의
// TodaySummary(가짜 데이터 모델)는 채택하지 않는다. "이달"은 기존
// D01(이달의 운세)이 이미 사용하는 [getMonthlyFortune], "오늘"은
// D02/D03가 이미 사용하는 [getDailyFortune](saju_fortune_modules.dart)의
// 결과를 그대로 받아 렌더링한다 — 새로운 날짜/간지 계산 없음.
// ============================================================

import 'package:flutter/material.dart';

import '../../domain/manseryeok/saju_profile.dart' show YongsinProfile;
import '../../domain/saju_engine.dart' show ganElement, zhiElement;
import 'hanji_card.dart';
import 'hanji_design_tokens.dart';
import 'seun_grid.dart' show HanjiTone;

/// [gan]/[zhi] 한자 1글자씩을 이미 계산된 [yongsin](용신/희신/기신/구신)과
/// 대조해 표시 톤을 산출한다 — seun_grid.dart의 toneForPillar와 동일한
/// 원칙(새 판정 공식 없음, 기존 계산 결과의 색상 매핑일 뿐).
HanjiTone toneForGanZhiHanja(String gan, String zhi, YongsinProfile yongsin) {
  final ganEl = ganElement[gan]?.$1;
  final zhiEl = zhiElement[zhi]?.$1;
  final elements = {if (ganEl != null) ganEl, if (zhiEl != null) zhiEl};
  if (elements.contains(yongsin.yongsin) || elements.contains(yongsin.heesin)) {
    return HanjiTone.best;
  }
  if (elements.contains(yongsin.gisin) || elements.contains(yongsin.gusin)) {
    return HanjiTone.warn;
  }
  return HanjiTone.ok;
}

/// 이달·오늘 요약 카드. [period]는 '이달 · 8월' / '오늘 · 08.15' 같은
/// 라벨, [ganjiLabel]은 해당 기간의 간지(예: '乙未月' / '己丑日'),
/// [text]는 SajuFortuneRules 룩업으로 이미 만들어진 안내 문구.
class TodayCard extends StatelessWidget {
  final String period;
  final String ganjiLabel;
  final String text;
  final HanjiTone tone;

  const TodayCard({
    super.key,
    required this.period,
    required this.ganjiLabel,
    required this.text,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final isWarn = tone == HanjiTone.warn;
    return HanjiCard(
      borderColor: isWarn ? HanjiColors.accent.withValues(alpha: 0.35) : HanjiColors.line,
      backgroundColor: isWarn ? HanjiColors.accent.withValues(alpha: 0.05) : HanjiColors.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(period, style: HanjiTextStyles.bodyTitle().copyWith(fontSize: 13)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isWarn ? HanjiColors.accent : HanjiColors.su.withValues(alpha: 0.15),
                  border: isWarn ? null : Border.all(color: HanjiColors.su.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  ganjiLabel,
                  style: HanjiTextStyles.display1(
                    color: isWarn ? const Color(0xFFFFF9E8) : HanjiColors.su,
                  ).copyWith(fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: HanjiTextStyles.body(color: HanjiColors.muted).copyWith(fontSize: 13, height: 1.65),
          ),
        ],
      ),
    );
  }
}
