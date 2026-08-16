// ============================================================
// [정통사주 결과 화면 개편] 소비자용 "진솔한 이야기체" 해석 카드.
//
// [배경] jeontong_narrative_interpreter.dart(JeontongNarrativeInterpreter)가
// 만들어낸 여러 문단짜리 이야기체 텍스트를, HeroSummaryCard 바로 아래
// (전문 원국판보다 먼저) 화면 최상단부에 노출하기 위한 카드 위젯.
//
// [설계 원칙] 순수하게 이미 계산된 문자열 리스트를 받아 렌더링만 하는
// StatelessWidget이다. 자체적으로 어떤 계산·로딩·setState도 하지 않으므로
// jeontong_eighty_result_frame_bench_test.dart의 프레임 예산(warm≤3/
// cold≤6)에 영향을 주지 않는다.
// ============================================================

import 'package:flutter/material.dart';

import 'hanji_design_tokens.dart';
import 'saju_seal.dart';

/// [paragraphs]를 문단 사이 여백을 두고 이야기체 카드로 렌더링한다.
class JeontongNarrativeCard extends StatelessWidget {
  const JeontongNarrativeCard({
    super.key,
    required this.paragraphs,
    this.label = '◈ 사주 이야기 · 당신을 위한 풀이',
  });

  final List<String> paragraphs;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (paragraphs.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(HanjiSpacing.xl),
      decoration: BoxDecoration(
        color: HanjiColors.card,
        borderRadius: BorderRadius.circular(HanjiRadii.card),
        border: Border.all(color: HanjiColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MonoLabel(label, color: HanjiColors.accent),
          const SizedBox(height: HanjiSpacing.md),
          for (var i = 0; i < paragraphs.length; i++) ...[
            Text(paragraphs[i], style: HanjiTextStyles.body()),
            if (i != paragraphs.length - 1)
              const SizedBox(height: HanjiSpacing.lg),
          ],
        ],
      ),
    );
  }
}
