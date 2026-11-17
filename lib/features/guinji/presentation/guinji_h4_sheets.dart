// lib/features/guinji/presentation/guinji_h4_sheets.dart
// [2026 디자인 핸드오프 v5 — SPEC.md §6 H4-a/H4-b] 지도 메인(H4)에서
// "빈 자리" 또는 "바깥 인장(유형, 인원 0)"을 탭했을 때 띄우는 두 바텀시트.
//
// 이전까지 두 인터랙션(§5-5)이 전혀 구현되지 않아, 빈 자리를 탭하면 시트
// 없이 바로 H10(직접 추가)으로 직행하고, 인원 0인 유형 인장을 탭하면
// 의미 없는 필터 토글만 수행했다 — SPEC §5-5 표와 QA_CHECKLIST.md의
// H4-a("빈 자리 탭 → 시트, 초대 / 직접 입력(이름 채움)")·
// H4-b("하단 `확인` 하나(초대 버튼 없음)") 요구를 둘 다 위반하는 상태였다.
// 이 파일이 그 공백을 채운다.
//
// 시트 뼈대는 `guinji_node_sheet.dart`의 `DraggableScrollableSheet` 패턴
// (initialChildSize 0.86/minChildSize 0.5/maxChildSize 0.94, 상단 유형색
// 테두리, GmRadius.sheet 라운드, 40×4 핸들)을 그대로 모방한다.
import 'package:flutter/material.dart';

import '../domain/guinji_person.dart';
import '../theme/guinji_map_theme.dart';
import '../theme/guinji_type_spec.dart';
import '../widgets/guinji_layout.dart' show GuinjiTpSlot, tpSlotTotal;
import '../widgets/guinji_map_widgets.dart';

/// COPY.md §1-3 "어떻게 판정하나요" — H4-b `how.title` 본문.
const Map<String, String> _gjHowJudged = {
  'CHEON_GWII': '일간 오행이 서로 살리고, 부족한 오행까지 크게 채워 줄 때 나와요. 여섯 유형 중 가장 높은 단계예요.',
  'SANG_SAENG': '한쪽의 일간이 다른 쪽을 생(生)해 줄 때 나와요. 한 사람이 다른 사람을 키워 주는 흐름이에요.',
  'HAP': '두 사람의 일지(태어난 날의 지지)가 합을 이룰 때 나와요. 자연스럽게 끌리는 인연이에요.',
  'BI_HWA': '두 사람의 일간 오행이 같을 때 나와요. 결이 비슷해 편안한 동행이에요.',
  'SANG_GEUK': '일간 오행이 서로 극할 때 나와요. 긴장이 있지만 조율하면 서로를 다듬어 줘요.',
  'CHUNG': '일지가 충(沖)할 때 나와요. 부딪히는 만큼 배울 점도 많은 인연이에요.',
};

/// COPY.md §1-1 "이어가는 법" 3개 전부(유형 안내 시트는 3개 모두 노출).
const Map<String, List<String>> _gjTipsAll3 = {
  'CHEON_GWII': [
    '중요한 결정 앞에서 먼저 의견을 물어보세요',
    '고마운 마음을 말로 전하면 인연이 더 깊어져요',
    '좋은 소식이 생기면 가장 먼저 나눠 주세요',
  ],
  'SANG_SAENG': [
    '서로의 성장을 응원하는 말 한마디가 큰 힘이 돼요',
    '한쪽만 주는 관계가 되지 않게 균형을 살펴 주세요',
    '새로운 도전을 함께 계획해 보세요',
  ],
  'HAP': [
    '자주 연락하지 않아도 괜찮아요. 함께한 시간을 기억해 주세요',
    '작은 약속을 꾸준히 지켜 주세요',
    '기념일을 챙기면 정이 한층 깊어져요',
  ],
  'BI_HWA': [
    '결이 비슷해 편안한 사이예요. 새로운 경험을 함께해 보세요',
    '비슷해서 생기는 고집은 한 걸음 양보해 주세요',
    '서로의 루틴을 존중해 주세요',
  ],
  'SANG_GEUK': [
    '의견이 다를 땐 결론보다 이유를 먼저 들어 주세요',
    '거리를 조금 두면 오히려 관계가 편해져요',
    '역할을 나누면 부딪힘이 줄어들어요',
  ],
  'CHUNG': [
    '부딪힘은 성장의 신호예요. 감정이 가라앉은 뒤 이야기해 주세요',
    '서로의 다른 점을 장점으로 바라봐 주세요',
    '중요한 일은 글로 정리해 오해를 줄여 주세요',
  ],
};

const List<String> _gjDirectionLabel = ['12시', '2시', '4시', '6시', '8시', '10시'];

Widget _gjSheetHandle() => Container(
  width: 40,
  height: 4,
  margin: const EdgeInsets.only(top: 10, bottom: 6),
  decoration: BoxDecoration(
    color: const Color(0x40FFEBC8),
    borderRadius: BorderRadius.circular(9999),
  ),
);

BoxDecoration _gjSheetDecoration(Color accent) => BoxDecoration(
  gradient: const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF22163A), GmColors.sheet],
    stops: [0, 0.4],
  ),
  borderRadius: BorderRadius.circular(GmRadius.sheet),
  border: Border(top: BorderSide(color: accent.withValues(alpha: 0.4))),
  boxShadow: const [
    BoxShadow(color: Color(0x66000000), blurRadius: 32, offset: Offset(0, -8)),
  ],
);

Widget _gjCloseButton(BuildContext context) => GestureDetector(
  onTap: () => Navigator.of(context).maybePop(),
  child: Container(
    width: 34,
    height: 34,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: GmColors.line),
      color: const Color(0x800A0716),
    ),
    alignment: Alignment.center,
    child: const Text('✕', style: TextStyle(color: GmColors.fg, fontSize: 14)),
  ),
);

// ─────────────────────────────────────────────────────────────
// H4-a 빈 자리 시트
// ─────────────────────────────────────────────────────────────

/// SPEC §6 H4-a — 빈 자리 별을 탭했을 때. footer: Primary(초대장 보내기 →
/// H9) / Ghost(직접 입력, 이름 미리 채움 → H10).
Future<void> showGuinjiEmptySlotSheet({
  required BuildContext context,
  required GuinjiTpSlot slot,
  required int filled,
  required VoidCallback onInvite,
  required void Function(String prefillName) onDirect,
}) {
  return showGmBottomSheet<void>(
    context: context,
    builder: (sheetContext) => _GuinjiEmptySlotSheetBody(
      slot: slot,
      filled: filled,
      onInvite: () {
        Navigator.of(sheetContext).pop();
        onInvite();
      },
      onDirect: () {
        Navigator.of(sheetContext).pop();
        onDirect(slot.label);
      },
    ),
  );
}

class _GuinjiEmptySlotSheetBody extends StatelessWidget {
  const _GuinjiEmptySlotSheetBody({
    required this.slot,
    required this.filled,
    required this.onInvite,
    required this.onDirect,
  });

  final GuinjiTpSlot slot;
  final int filled;
  final VoidCallback onInvite;
  final VoidCallback onDirect;

  @override
  Widget build(BuildContext context) {
    final shown = filled.clamp(0, tpSlotTotal);
    return DraggableScrollableSheet(
      initialChildSize: 0.62,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, scrollController) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          decoration: _gjSheetDecoration(GmColors.gold),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _gjSheetHandle(),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const GmLabelMini('EMPTY SEAT · 貴'),
                          _gjCloseButton(context),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // 일러스트 박스(높이 120) — 나(金) --- 점선 --- (+)빈자리.
                      Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: GmColors.line),
                          gradient: RadialGradient(
                            center: Alignment.center,
                            radius: 1.1,
                            colors: [
                              GmColors.gold.withValues(alpha: 0.16),
                              const Color(0x990A0716),
                            ],
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: GmColors.gold,
                                      width: 1.6,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: const Text(
                                    '나',
                                    style: TextStyle(
                                      color: Color(0xFFFFE9A8),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Expanded(
                              child: CustomPaint(
                                size: const Size(double.infinity, 2),
                                painter: _GjDashedLinePainter(
                                  color: GmColors.gold.withValues(alpha: 0.55),
                                ),
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xCC1A0D2E),
                                    border: Border.all(
                                      color: GmColors.gold,
                                      width: 1.2,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: const Text(
                                    '+',
                                    style: TextStyle(
                                      color: Color(0xFFFFE9A8),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  slot.label,
                                  style: const TextStyle(
                                    fontFamily: GmText.body,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: GmColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '이 자리에 ${slot.label}의 별을\n띄워 볼까요',
                        style: const TextStyle(
                          fontFamily: GmText.display,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.03,
                          height: 1.4,
                          color: GmColors.fg,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${slot.hint}와 생년월일로 관계를 보면 이 자리에 별이 떠요. '
                        '어떤 인연인지는 결과가 나와야 알 수 있고, 케미가 높을수록 '
                        '나와 가까운 곳에 자리 잡아요.',
                        style: const TextStyle(
                          fontFamily: GmText.ui,
                          fontSize: 13.5,
                          height: 1.65,
                          color: GmColors.muted,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x0AFFEBC8),
                          border: Border.all(color: GmColors.hair),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Row(
                              children: List.generate(
                                tpSlotTotal,
                                (i) => Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(right: 3),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: i < shown
                                        ? GmColors.gold
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: GmColors.gold.withValues(
                                        alpha: 0.6,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '귀인지도 $shown / $tpSlotTotal',
                                style: const TextStyle(
                                  fontFamily: GmText.ui,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: GmColors.fg,
                                ),
                              ),
                            ),
                            const Text(
                              '앱 참여 시 +20P',
                              style: TextStyle(
                                fontFamily: GmText.ui,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: GmColors.gold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '생년월일을 몰라도 초대장으로 채울 수 있어요. 상대가 직접 '
                        '입력하면 별이 떠요.',
                        style: TextStyle(
                          fontFamily: GmText.ui,
                          fontSize: 12,
                          height: 1.6,
                          color: GmColors.dim,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: GmColors.hair)),
                ),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: onInvite,
                        style: gmPrimary(),
                        child: Text('✉ ${slot.label}에게 초대장 보내기'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: onDirect,
                        style: gmGhost(),
                        child: const Text('생년월일을 알아요 · 직접 입력'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 점선을 수평으로 그리는 경량 페인터(H4-a 일러스트 전용).
class _GjDashedLinePainter extends CustomPainter {
  const _GjDashedLinePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    const dash = 4.0, gap = 4.0;
    var x = 0.0;
    final y = size.height / 2;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset(x + dash, y), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _GjDashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}

// ─────────────────────────────────────────────────────────────
// H4-b 유형 안내 시트
// ─────────────────────────────────────────────────────────────

/// SPEC §6 H4-b — 인원 0명인 바깥 인장(유형)을 탭했을 때. footer: Ghost
/// "확인" 하나만(초대 버튼 없음).
Future<void> showGuinjiTypeInfoSheet({
  required BuildContext context,
  required String typeKey,
  required List<GuinjiPerson> people,
  required void Function(GuinjiPerson person) onPerson,
}) {
  return showGmBottomSheet<void>(
    context: context,
    builder: (sheetContext) => _GuinjiTypeInfoSheetBody(
      typeKey: typeKey,
      people: people,
      onPerson: (p) {
        Navigator.of(sheetContext).pop();
        onPerson(p);
      },
    ),
  );
}

class _GuinjiTypeInfoSheetBody extends StatelessWidget {
  const _GuinjiTypeInfoSheetBody({
    required this.typeKey,
    required this.people,
    required this.onPerson,
  });

  final String typeKey;
  final List<GuinjiPerson> people;
  final void Function(GuinjiPerson person) onPerson;

  @override
  Widget build(BuildContext context) {
    final spec = guinjiTypeOf(typeKey);
    final color = spec.color;
    final idx = guinjiTypeOrder.indexOf(typeKey).clamp(0, 5);
    final list = people.where((p) => p.relation == typeKey).toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    final isShort = (spec.dash != null && spec.dash!.isNotEmpty)
        ? spec.dash!.first < 5
        : null;
    final lineLabel = spec.dash == null
        ? '실선'
        : (isShort == true ? '짧은 점선' : '긴 점선');
    final tips = _gjTipsAll3[typeKey] ?? const <String>[];

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      builder: (_, scrollController) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          decoration: _gjSheetDecoration(color),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _gjSheetHandle(),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Transform.rotate(
                            angle: -5 * 3.1415926535 / 180,
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.33),
                                    blurRadius: 20,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                spec.hanja,
                                style: const TextStyle(
                                  fontFamily: GmText.display,
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                  color: GmColors.onFg,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GmLabelMini(
                                  'TYPE · ${(idx + 1).toString().padLeft(2, '0')} / 06',
                                  color: color,
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  spec.label,
                                  style: const TextStyle(
                                    fontFamily: GmText.display,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.03,
                                    color: GmColors.fg,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _gjCloseButton(context),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        spec.desc,
                        style: const TextStyle(
                          fontFamily: GmText.body,
                          fontSize: 16,
                          height: 1.7,
                          color: GmColors.fg,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _GjInfoCard(
                        title: '◇ 어떻게 판정하나요',
                        color: color,
                        child: Text(
                          _gjHowJudged[typeKey] ?? spec.desc,
                          style: const TextStyle(
                            fontFamily: GmText.ui,
                            fontSize: 14,
                            height: 1.65,
                            color: GmColors.fg,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _GjInfoCard(
                        title: '◇ 지도에서 이렇게 보여요',
                        color: color,
                        child: Column(
                          children: [
                            _GjShowRow(
                              leading: Container(
                                width: 22,
                                height: 22,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  spec.hanja,
                                  style: const TextStyle(
                                    fontFamily: GmText.display,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: GmColors.onFg,
                                  ),
                                ),
                              ),
                              child: RichText(
                                text: TextSpan(
                                  style: const TextStyle(
                                    fontFamily: GmText.ui,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w500,
                                    color: GmColors.fg,
                                  ),
                                  children: [
                                    const TextSpan(text: '인장 '),
                                    TextSpan(
                                      text: spec.hanja,
                                      style: TextStyle(
                                        color: color,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const TextSpan(text: ' · 사진 오른쪽 아래에 찍혀요'),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            _GjShowRow(
                              leading: SizedBox(
                                width: 40,
                                height: 10,
                                child: CustomPaint(
                                  painter: _GjSampleLinePainter(
                                    color: color,
                                    dash: spec.dash,
                                  ),
                                ),
                              ),
                              child: Text(
                                '$lineLabel · 색이 안 보여도 구분돼요',
                                style: const TextStyle(
                                  fontFamily: GmText.ui,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                  color: GmColors.fg,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            _GjShowRow(
                              leading: SizedBox(
                                width: 40,
                                child: Text(
                                  _gjDirectionLabel[idx],
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: GmText.display,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: color,
                                  ),
                                ),
                              ),
                              child: const Text(
                                '지도에서 이 방향에 모여요',
                                style: TextStyle(
                                  fontFamily: GmText.ui,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                  color: GmColors.fg,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      GmLabelMini('지도 속 ${spec.short} · ${list.length}명'),
                      const SizedBox(height: 10),
                      if (list.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: GmColors.line,
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: const Text(
                            '아직 이 유형의 인연이 없어요\n어떤 인연이 될지는 미리 고를 수 '
                            '없고, 두 사람의 생년월일로 정해져요',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: GmText.ui,
                              fontSize: 13.5,
                              height: 1.6,
                              color: GmColors.muted,
                            ),
                          ),
                        )
                      else
                        Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          children: [
                            for (final p in list)
                              _GjPersonFace(
                                person: p,
                                color: color,
                                onTap: () => onPerson(p),
                              ),
                          ],
                        ),
                      if (tips.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        const GmLabelMini('이 인연과는 이렇게'),
                        const SizedBox(height: 9),
                        for (var i = 0; i < tips.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    fontFamily: GmText.display,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    height: 1.5,
                                    color: color,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    tips[i],
                                    style: const TextStyle(
                                      fontFamily: GmText.ui,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                      height: 1.6,
                                      color: GmColors.fg,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              // footer: Ghost "확인" 하나만 — SPEC §6 H4-b "초대 버튼 없음".
              Container(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: GmColors.hair)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    style: gmGhost(),
                    child: const Text('확인'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GjInfoCard extends StatelessWidget {
  const _GjInfoCard({
    required this.title,
    required this.color,
    required this.child,
  });

  final String title;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: GmColors.cardTint,
        border: Border.all(color: GmColors.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: GmText.ui,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _GjShowRow extends StatelessWidget {
  const _GjShowRow({required this.leading, required this.child});
  final Widget leading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [leading, const SizedBox(width: 14), Expanded(child: child)],
    );
  }
}

class _GjSampleLinePainter extends CustomPainter {
  const _GjSampleLinePainter({required this.color, required this.dash});
  final Color color;
  final List<double>? dash;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    if (dash == null) {
      canvas.drawLine(Offset(2, y), Offset(size.width - 2, y), paint);
      return;
    }
    final d = dash![0].toDouble() * 1.6;
    final g = (dash!.length > 1 ? dash![1] : dash![0]).toDouble() * 1.6;
    var x = 2.0;
    while (x < size.width - 2) {
      final end = (x + d).clamp(0, size.width - 2).toDouble();
      canvas.drawLine(Offset(x, y), Offset(end, y), paint);
      x += d + g;
    }
  }

  @override
  bool shouldRepaint(covariant _GjSampleLinePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.dash != dash;
}

class _GjPersonFace extends StatelessWidget {
  const _GjPersonFace({
    required this.person,
    required this.color,
    required this.onTap,
  });

  final GuinjiPerson person;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 56,
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.16),
                border: Border.all(color: color, width: 1.4),
              ),
              child: Text(
                person.name.isNotEmpty ? person.name.substring(0, 1) : '?',
                style: TextStyle(
                  fontFamily: GmText.display,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              person.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: GmText.body,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: GmColors.fg,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${person.score}',
              style: TextStyle(
                fontFamily: GmText.mono,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
