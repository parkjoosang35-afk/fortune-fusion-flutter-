// ============================================================
// 일간(日干) 카드 — 정통사주 전용 Dawn Hanji 디자인.
//
// [naming collision 회피 + 재계산 금지 원칙] 원본은 자체 `DayMaster(gan,
// wuxing, label, desc)` 모델(data/models/saju_result.dart)에 의존했지만,
// 이 프로젝트는 이미 레거시 `saju_engine.dart`의 `SajuDayMaster(gan, kr,
// element, yinYang, image)`와, PHASE1~4 해석 계층
// `saju_interpreter.dart`의 `DayMasterInterpretation(title, nature,
// personality, strengths, weaknesses, careerFit)`을 갖고 있다. 새 모델을
// 만들지 않고 이 두 실계산 결과를 그대로 조합해 렌더링한다.
// ============================================================

import 'package:flutter/material.dart';

import '../../domain/saju_engine.dart' show SajuDayMaster;
import '../../domain/saju_interpreter.dart' show DayMasterInterpretation;
import 'hanji_card.dart';
import 'hanji_design_tokens.dart';
import 'saju_seal.dart';

class DayMasterCard extends StatelessWidget {
  final SajuDayMaster dayMaster;
  final DayMasterInterpretation analysis;

  const DayMasterCard({
    super.key,
    required this.dayMaster,
    required this.analysis,
  });

  @override
  Widget build(BuildContext context) {
    final wxColor = HanjiColors.wuxingColor(dayMaster.element);
    return HanjiCard(
      glow: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 66,
            decoration: BoxDecoration(
              color: wxColor.withValues(alpha: 0.15),
              border: Border.all(
                color: wxColor.withValues(alpha: 0.4),
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              dayMaster.kr,
              style: HanjiTextStyles.display1(
                color: wxColor,
              ).copyWith(fontSize: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MonoLabel('◈ 일간 · DAY MASTER', color: HanjiColors.accent),
                const SizedBox(height: 4),
                Text(
                  '${dayMaster.kr} (${dayMaster.image}) · ${dayMaster.yinYang}',
                  style: HanjiTextStyles.bodyTitle().copyWith(fontSize: 15),
                ),
                const SizedBox(height: 6),
                Text(
                  analysis.personality,
                  style: HanjiTextStyles.body(
                    color: HanjiColors.muted,
                  ).copyWith(fontSize: 13, height: 1.6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
