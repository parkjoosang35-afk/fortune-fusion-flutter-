import 'package:flutter/material.dart';
import '../data/models/interpret_result.dart';
import '../theme/saju_dark_tokens.dart';

/// [saju-handoff-spec.pdf v2.0 §4-C5 "주제별 대운 브리핑 표(지난/현재/앞으로)"
/// — TK-7] 서버(admin_web `interpret-service.ts`)가 `InterpretDetailResult.
/// daeun_timeline`에 facts.luck_pillars를 그대로 옮겨 내려준 구조화 데이터를
/// "대운 · 기간(연도) · 나이(세는) · 시제" 4열 표로 그린다.
///
/// [C5 원문 "표 문자열을 새로 쓰지 말고 facts에서 복사"] 이 위젯은 LLM 본문
/// 텍스트(n=4 블록의 body)를 전혀 참고하지 않는다 — 서버가 엔진 facts에서
/// 직접 만든 `daeunTimeline` 배열만 그대로 렌더링한다. 같은 화면에 이미 있는
/// `_DetailBlockView`의 "대운 스트림 카드"(C-06 LuckStream, 그래픽 별줄기
/// 시각화)와는 별개의 보강 컴포넌트다 — LuckStream은 디자인 컴포넌트 계약
/// (docs/11_API_계약서.md `timing.luck_index`)을 그대로 유지한 채, 이 표는
/// PDF C5가 요구하는 "나이·연도·시제가 명시된 표" 형태를 추가로 제공한다.
///
/// [내부 정보 비노출] 이 위젯이 다루는 필드(간지/연도/나이/시제)는 모두 facts
/// 그대로이며 topic_id/score/evaluator 같은 내부 코드를 포함하지 않는다.
class SajuDaeunTimelineTable extends StatelessWidget {
  const SajuDaeunTimelineTable({
    super.key,
    required this.entries,
    this.accentColor = SajuGold.g300,
  });

  final List<InterpretDaeunTimelineEntry> entries;
  final Color accentColor;

  static const Map<String, String> _tenseKo = {
    'past': '지난',
    'now': '현재',
    'future': '앞으로',
  };

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16, top: 4),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SajuText.lineGold),
        color: const Color(0x66201D31),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '대운 흐름',
                style: TextStyle(
                  fontFamily: SajuType.ui,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: accentColor,
                ),
              ),
              const Text(
                '지난 · 현재 · 앞으로',
                style: TextStyle(
                  fontFamily: SajuType.ui,
                  fontSize: 11,
                  color: SajuText.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _HeaderRow(),
          const SizedBox(height: 6),
          Container(height: 1, color: SajuText.line),
          const SizedBox(height: 2),
          ...entries.map(
            (e) => _TimelineRow(entry: e, accentColor: accentColor),
          ),
        ],
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  static const TextStyle _style = TextStyle(
    fontFamily: SajuType.ui,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: SajuText.faint,
  );

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(flex: 2, child: Text('대운', style: _style)),
        Expanded(flex: 4, child: Text('기간(연도)', style: _style)),
        Expanded(flex: 3, child: Text('나이(세는)', style: _style)),
        Expanded(
          flex: 2,
          child: Text('시제', style: _style, textAlign: TextAlign.right),
        ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.entry, required this.accentColor});

  final InterpretDaeunTimelineEntry entry;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final isNow = entry.isNow;
    final tenseLabel =
        SajuDaeunTimelineTable._tenseKo[entry.tense] ?? entry.tense;
    final rowColor = isNow ? accentColor : SajuText.fg2;
    final rowWeight = isNow ? FontWeight.w700 : FontWeight.w400;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: isNow
          ? BoxDecoration(
              color: accentColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            )
          : null,
      margin: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text(
                entry.ganZhiKr,
                style: TextStyle(
                  fontFamily: SajuType.serif,
                  fontSize: 13,
                  fontWeight: rowWeight,
                  color: rowColor,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              '${entry.startYear}–${entry.endYear}',
              style: TextStyle(
                fontFamily: SajuType.mono,
                fontSize: 12,
                fontWeight: rowWeight,
                color: rowColor,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              '${entry.startAge}–${entry.endAge}세',
              style: TextStyle(
                fontFamily: SajuType.mono,
                fontSize: 12,
                fontWeight: rowWeight,
                color: rowColor,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: isNow
                      ? Border.all(color: accentColor)
                      : Border.all(color: SajuText.line),
                ),
                child: Text(
                  tenseLabel,
                  style: TextStyle(
                    fontFamily: SajuType.ui,
                    fontSize: 10.5,
                    fontWeight: isNow ? FontWeight.w700 : FontWeight.w500,
                    color: isNow ? accentColor : SajuText.muted,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
