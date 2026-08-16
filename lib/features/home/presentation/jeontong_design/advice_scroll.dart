// ============================================================
// 정통사주 전용 · 조언 두루마리
// 원본: flutter_handoff.zip theme의 _AdviceScroll을 이식하되, 새
// handoff의 Advice(가짜 데이터 모델)는 채택하지 않는다. 새로운 조언
// 텍스트를 생성하지 않고, 이미 계산된 [SajuFullInterpretation]의
// wealthFortune.message / careerFortune.message / healthFortune의
// recommendedFood·warnings를 그대로 3개 조언으로 노출한다.
// ============================================================

import 'package:flutter/material.dart';

import '../../domain/saju_interpreter.dart' show SajuFullInterpretation;
import 'hanji_design_tokens.dart';
import 'saju_seal.dart';

class AdviceItem {
  final String num; // '一' '二' '三' 인장 라벨
  final String title;
  final String text;
  const AdviceItem({
    required this.num,
    required this.title,
    required this.text,
  });
}

/// [interp]에서 재물/커리어/건강 3개 해석의 message(문장)을 그대로 뽑아
/// [AdviceItem] 3개를 만든다 — 재계산·재생성 없음, 이미 계산된 문장의
/// 재배치일 뿐.
List<AdviceItem> buildAdviceItemsFrom(SajuFullInterpretation interp) {
  final health = interp.healthFortune;
  final healthText = health.warnings.isNotEmpty
      ? '주의: ${health.warnings.join(', ')}. 추천 음식: ${health.recommendedFood.join(', ')}.'
      : '추천 음식: ${health.recommendedFood.join(', ')}.';
  return [
    AdviceItem(num: '一', title: '재물운', text: interp.wealthFortune.message),
    AdviceItem(num: '二', title: '커리어운', text: interp.careerFortune.message),
    AdviceItem(num: '三', title: '건강 참고', text: healthText),
  ];
}

class AdviceScroll extends StatelessWidget {
  final AdviceItem advice;
  const AdviceScroll({super.key, required this.advice});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF3E5C3), Color(0xFFECD9AB)],
              ),
              borderRadius: BorderRadius.circular(HanjiRadii.scroll),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SajuSeal(
                  glyph: advice.num,
                  size: 40,
                  color: HanjiColors.accent,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        advice.title,
                        style: HanjiTextStyles.display2().copyWith(
                          fontSize: 15,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        advice.text,
                        style: HanjiTextStyles.body(
                          color: const Color(0xD12A1F14),
                        ).copyWith(fontSize: 12.5, height: 1.7),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: -5,
            left: -6,
            right: -6,
            height: 10,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFA06D3C), Color(0xFF4A2F15)],
                ),
                borderRadius: BorderRadius.all(Radius.circular(5)),
              ),
            ),
          ),
          Positioned(
            bottom: -5,
            left: -6,
            right: -6,
            height: 10,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF4A2F15), Color(0xFFA06D3C)],
                ),
                borderRadius: BorderRadius.all(Radius.circular(5)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
