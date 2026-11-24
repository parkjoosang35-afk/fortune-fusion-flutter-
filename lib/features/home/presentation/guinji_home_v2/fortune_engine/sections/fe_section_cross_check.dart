// ═══════════════════════════════════════════════════════════════
// FILE: fe_section_cross_check.dart — 8.CROSSCHECK (6차원 그리드,
// 편차계산기)
// 출처: design_files/engine-app.jsx CrossCheck().
// State: calc(Map<String,int>) — README "State Management" 표 3행.
// [결정론적 규칙] feAgreementOf()는 LLM을 사용하지 않는 순수 함수
// (최대편차 계산)이다.
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import '../fe_data.dart';
import '../fe_tokens.dart';
import '../fe_widgets.dart';

class FeCrossCheckSection extends StatefulWidget {
  const FeCrossCheckSection({super.key});
  @override
  State<FeCrossCheckSection> createState() => _FeCrossCheckSectionState();
}

class _FeCrossCheckSectionState extends State<FeCrossCheckSection> {
  final Map<String, int> _v = {'S': 0, 'G': 2, 'P': 2};

  static const _three = [
    [FeAgreement.ok, FeColors.ok],
    [FeAgreement.mid, FeColors.mid],
    [FeAgreement.tense, FeColors.tense],
  ];

  @override
  Widget build(BuildContext context) {
    final vals = _v.values.toList();
    final dev =
        vals.reduce((a, b) => a > b ? a : b) -
        vals.reduce((a, b) => a < b ? a : b);
    final agreement = dev == 0
        ? FeAgreement.ok
        : dev == 1
        ? FeAgreement.mid
        : FeAgreement.tense;
    final stColor = agreement == FeAgreement.ok
        ? FeColors.ok
        : agreement == FeAgreement.mid
        ? FeColors.mid
        : FeColors.tense;

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
              hanja: '對照',
              mono: 'CROSS-CHECK · 07',
              title: Text("'대조' 결과\n읽는 법"),
              sub: '조합 리딩에서는 엔진별 판정을 여섯 차원으로 환산해 나란히 놓습니다. 놓고 보면 세 가지가 나타납니다.',
            ),
          ),
          FeReveal(
            delay: const Duration(milliseconds: 60),
            child: _FeDimGrid(),
          ),
          const SizedBox(height: 10),
          Column(
            children: _three.asMap().entries.map((entry) {
              final i = entry.key;
              final ag = entry.value[0] as FeAgreement;
              final c = entry.value[1] as Color;
              final copy = feAgreementCopy[ag]!;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: FeReveal(
                  delay: Duration(milliseconds: i * 100),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: c.withValues(alpha: 0.4)),
                      gradient: LinearGradient(
                        colors: [c.withValues(alpha: 0.14), Colors.transparent],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: c,
                                boxShadow: [
                                  BoxShadow(color: c, blurRadius: 10),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              copy[0],
                              style: TextStyle(
                                fontFamily: FeFonts.display,
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                                color: c,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '편차 $i',
                              style: const TextStyle(
                                fontFamily: FeFonts.mono,
                                fontSize: 10,
                                letterSpacing: 1.5,
                                color: FeColors.muted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '"${copy[1]}"',
                          style: const TextStyle(
                            fontFamily: FeFonts.body,
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          copy[2],
                          style: const TextStyle(
                            fontSize: 12,
                            color: FeColors.muted,
                            height: 1.55,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          FeReveal(
            child: FeGlowCard(
              altar: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '◈ 직접 환산해 보기 · 방향성',
                    style: TextStyle(
                      fontFamily: FeFonts.mono,
                      fontSize: 10,
                      color: FeColors.glow,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._v.keys.map((id) {
                    final e = feEngineOf(id);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 36,
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
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.3),
                                border: Border.all(color: FeColors.line),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: feLevelLabel.asMap().entries.map((
                                  lvEntry,
                                ) {
                                  final n = lvEntry.key;
                                  final l = lvEntry.value;
                                  final on = _v[id] == n;
                                  return Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(() => _v[id] = n),
                                      child: Container(
                                        height: 34,
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 1,
                                        ),
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: on
                                              ? e.color
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            9,
                                          ),
                                          boxShadow: on
                                              ? [
                                                  BoxShadow(
                                                    color: e.color.withValues(
                                                      alpha: 0.5,
                                                    ),
                                                    blurRadius: 12,
                                                  ),
                                                ]
                                              : null,
                                        ),
                                        child: Text(
                                          '$l $n',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: on
                                                ? FeColors.ink
                                                : FeColors.muted,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: stColor.withValues(alpha: 0.12),
                      border: Border.all(color: stColor),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '최대편차 = ${vals.reduce((a, b) => a > b ? a : b)} − ${vals.reduce((a, b) => a < b ? a : b)} = $dev',
                            style: const TextStyle(
                              fontFamily: FeFonts.mono,
                              fontSize: 12,
                              color: FeColors.muted,
                            ),
                          ),
                        ),
                        Text(
                          feAgreementCopy[agreement]![0],
                          style: TextStyle(
                            fontFamily: FeFonts.display,
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                            color: stColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '강함=2 · 보통=1 · 약함=0 · 최대편차 0이면 일치 · 1이면 보완 · 2면 긴장',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: FeColors.muted,
                      height: 1.4,
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
}

class _FeDimGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: feDimensions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 1.1,
      ),
      itemBuilder: (context, i) {
        final d = feDimensions[i][0], s = feDimensions[i][1];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.22),
            border: Border.all(color: FeColors.line),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                d,
                style: const TextStyle(
                  fontFamily: FeFonts.body,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                  color: FeColors.glow,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                s,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 9, color: FeColors.muted),
              ),
            ],
          ),
        );
      },
    );
  }
}
