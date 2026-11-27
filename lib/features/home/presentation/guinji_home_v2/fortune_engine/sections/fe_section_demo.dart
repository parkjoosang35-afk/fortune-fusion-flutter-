// ═══════════════════════════════════════════════════════════════
// FILE: fe_section_demo.dart — 9.LIVEOUTPUT (티켓카드, 6차원 아코디언)
// 출처: design_files/engine-app.jsx Demo().
// State: demoOpen(int) — README "State Management" 표 4행.
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import '../fe_data.dart';
import '../fe_tokens.dart';
import '../fe_widgets.dart';

class FeDemoSection extends StatefulWidget {
  const FeDemoSection({super.key});
  @override
  State<FeDemoSection> createState() => _FeDemoSectionState();
}

class _FeDemoSectionState extends State<FeDemoSection> {
  int _open = 0;

  static const _order = [
    ['방향성', FeAgreement.tense],
    ['재물감각', FeAgreement.tense],
    ['표현력', FeAgreement.tense],
    ['추진력', FeAgreement.mid],
    ['사고력', FeAgreement.mid],
    ['귀인 조력', FeAgreement.solo],
  ];

  static const _lvColor = [FeColors.tense, FeColors.mid, FeColors.ok];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FeSpace.screenH,
        FeSpace.sectionTop,
        FeSpace.screenH,
        10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FeReveal(
            child: FeSectionHead(
              hanja: '實測',
              mono: 'LIVE OUTPUT · 08',
              title: Text('실제 엔진 출력,\n그대로'),
              sub: '오경(五鏡) 종합 데모 — 다섯 엔진을 모두 가동한 실제 결과입니다. (얼굴·손은 데모 데이터)',
            ),
          ),
          FeReveal(
            delay: const Duration(milliseconds: 60),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: FeColors.glow.withValues(alpha: 0.35),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    FeColors.glow.withValues(alpha: 0.12),
                    FeColors.crystal.withValues(alpha: 0.06),
                  ],
                ),
              ),
              child: Column(
                children: [
                  _ticketRow('BIRTH', '1990 · 05 · 15 · 10:30'),
                  _ticketRow('ASK', '"이직해도 될까요"'),
                  _ticketRow('SPREAD', '셀틱 크로스'),
                  _ticketRow('SEED', 'demo1', valueColor: FeColors.tarot),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: feEngines
                        .map(
                          (e) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: e.color),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: e.color.withValues(alpha: 0.4),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: Text(
                                e.hanja,
                                style: TextStyle(
                                  fontFamily: FeFonts.display,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                  color: e.color,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          FeReveal(
            delay: const Duration(milliseconds: 100),
            child: Row(
              children: const [
                _FeSumSeg(flex: 3, n: 3, label: '긴장', c: FeColors.tense),
                SizedBox(width: 4),
                _FeSumSeg(flex: 2, n: 2, label: '보완', c: FeColors.mid),
                SizedBox(width: 4),
                _FeSumSeg(flex: 1, n: 1, label: '단일', c: FeColors.solo),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Column(
            children: _order.asMap().entries.map((entry) {
              final i = entry.key;
              final d = entry.value[0] as String;
              final ag = entry.value[1] as FeAgreement;
              final rows = feDemoRows[d]!;
              final c = ag == FeAgreement.ok
                  ? FeColors.ok
                  : ag == FeAgreement.mid
                  ? FeColors.mid
                  : ag == FeAgreement.tense
                  ? FeColors.tense
                  : FeColors.solo;
              final label = feAgreementCopy[ag]![0];
              final on = _open == i;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: FeColors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: on ? c.withValues(alpha: 0.6) : FeColors.line,
                  ),
                  boxShadow: on
                      ? [
                          BoxShadow(
                            color: c.withValues(alpha: 0.18),
                            blurRadius: 18,
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => setState(() => _open = on ? -1 : i),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 13,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  d,
                                  style: const TextStyle(
                                    fontFamily: FeFonts.body,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14.5,
                                  ),
                                ),
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: rows
                                    .map(
                                      (r) => Container(
                                        margin: const EdgeInsets.only(left: 3),
                                        width: 5,
                                        height: (6 + r.level * 6).toDouble(),
                                        decoration: BoxDecoration(
                                          color: feEngineOf(r.engine).color,
                                          borderRadius: BorderRadius.circular(
                                            3,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                              const SizedBox(width: 10),
                              FeStatusBadge(label, c),
                              const SizedBox(width: 8),
                              Text(
                                on ? '−' : '+',
                                style: const TextStyle(
                                  color: FeColors.muted,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    AnimatedCrossFade(
                      firstChild: const SizedBox(
                        width: double.infinity,
                        height: 0,
                      ),
                      secondChild: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                        child: Column(
                          children: rows.map((r) {
                            final e = feEngineOf(r.engine);
                            return Container(
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              decoration: const BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: FeColors.line,
                                    style: BorderStyle.solid,
                                  ),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 44,
                                    child: Text(
                                      e.short,
                                      style: TextStyle(
                                        fontFamily: FeFonts.body,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: e.color,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          r.text,
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            height: 1.4,
                                          ),
                                        ),
                                        if (r.rule.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 2,
                                            ),
                                            child: Text(
                                              r.rule,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: FeColors.muted,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: _lvColor[r.level].withValues(
                                          alpha: 0.33,
                                        ),
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${feLevelLabel[r.level]} ${r.level}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: _lvColor[r.level],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      crossFadeState: on
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 300),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          FeReveal(
            child: FeScroll(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '해설 · INTERPRETATION',
                    style: TextStyle(
                      fontFamily: FeFonts.mono,
                      fontSize: 10,
                      letterSpacing: 3,
                      color: FeColors.scrollInk,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    feDemoInterpretation,
                    style: const TextStyle(
                      fontFamily: FeFonts.body,
                      fontSize: 14,
                      height: 1.85,
                      color: FeColors.scrollInk,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ticketRow(
    String label,
    String value, {
    Color valueColor = FeColors.fg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: FeColors.line, style: BorderStyle.solid),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: FeFonts.mono,
              fontSize: 9.5,
              letterSpacing: 1.5,
              color: FeColors.muted,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: FeFonts.body,
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeSumSeg extends StatelessWidget {
  final int flex, n;
  final String label;
  final Color c;
  const _FeSumSeg({
    required this.flex,
    required this.n,
    required this.label,
    required this.c,
  });
  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.18),
          border: Border.all(color: c),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '$n',
              style: TextStyle(
                fontFamily: FeFonts.display,
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: c,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: c,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
