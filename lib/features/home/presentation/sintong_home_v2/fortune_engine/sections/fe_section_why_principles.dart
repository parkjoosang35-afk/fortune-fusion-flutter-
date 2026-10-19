// ═══════════════════════════════════════════════════════════════
// FILE: fe_section_why_principles.dart — 2.WHY / 3.PRINCIPLES
// 출처: design_files/engine-app.jsx Why() / Principles().
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import '../fe_tokens.dart';
import '../fe_widgets.dart';

/// 2. WHY — 보통의 운세 vs 신통방통 대비 카드.
class FeWhySection extends StatelessWidget {
  const FeWhySection({super.key});
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
              hanja: '事實',
              mono: 'WHY · 01',
              title: Text('결과만 주는 운세,\n근거까지 주는 운세'),
            ),
          ),
          FeReveal(
            delay: const Duration(milliseconds: 80),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _FeVsCard.dim()),
                  const SizedBox(
                    width: 30,
                    child: Center(
                      child: Text(
                        'VS',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: FeFonts.mono,
                          fontSize: 11,
                          color: FeColors.muted,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                  Expanded(child: _FeVsCard.lit()),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          FeReveal(
            delay: const Duration(milliseconds: 140),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: FeColors.line),
                borderRadius: BorderRadius.circular(16),
              ),
              child: RichText(
                text: const TextSpan(
                  style: TextStyle(
                    fontFamily: FeFonts.body,
                    fontSize: 13.5,
                    height: 1.75,
                    color: FeColors.muted,
                  ),
                  children: [
                    TextSpan(text: '사주 여덟 글자는 '),
                    TextSpan(
                      text: '천문 계산',
                      style: TextStyle(
                        color: FeColors.fg,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(text: '으로, 귀인은 '),
                    TextSpan(
                      text: '전래 구결',
                      style: TextStyle(
                        color: FeColors.fg,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(text: '로, 카드는 '),
                    TextSpan(
                      text: '100년 원전',
                      style: TextStyle(
                        color: FeColors.fg,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(text: '의 정의로, 얼굴과 손은 '),
                    TextSpan(
                      text: '측정값',
                      style: TextStyle(
                        color: FeColors.fg,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(text: '으로 다룹니다. 그리고 하나의 엔진만 믿지 않습니다.'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeVsCard extends StatelessWidget {
  final bool lit;
  const _FeVsCard({required this.lit});
  factory _FeVsCard.dim() => const _FeVsCard(lit: false);
  factory _FeVsCard.lit() => const _FeVsCard(lit: true);

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 190),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: lit ? null : Colors.black.withValues(alpha: 0.3),
        gradient: lit
            ? RadialGradient(
                center: Alignment.topCenter,
                radius: 1.4,
                colors: [FeColors.glowShadow, FeColors.card],
                stops: const [0, 0.7],
              )
            : null,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: lit ? FeColors.glow.withValues(alpha: 0.45) : FeColors.line,
        ),
        boxShadow: lit
            ? [
                BoxShadow(
                  color: FeColors.glow.withValues(alpha: 0.15),
                  blurRadius: 30,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            lit ? '신통방통' : '보통의 운세',
            style: TextStyle(
              fontFamily: FeFonts.mono,
              fontSize: 10,
              letterSpacing: 2,
              color: lit ? FeColors.glow : FeColors.muted,
            ),
          ),
          const SizedBox(height: 12),
          Opacity(
            opacity: lit ? 1 : 0.55,
            child: Text(
              lit ? '據' : '🂠',
              style: const TextStyle(
                fontFamily: FeFonts.display,
                fontWeight: FontWeight.w900,
                fontSize: 40,
                color: FeColors.glow,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Opacity(
            opacity: lit ? 1 : 0.55,
            child: RichText(
              textAlign: TextAlign.center,
              text: lit
                  ? const TextSpan(
                      style: TextStyle(
                        fontFamily: FeFonts.body,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        height: 1.5,
                        color: FeColors.fg,
                      ),
                      children: [
                        TextSpan(text: '결과와 함께\n'),
                        TextSpan(
                          text: '계산서',
                          style: TextStyle(color: FeColors.glow),
                        ),
                        TextSpan(text: '를 드립니다'),
                      ],
                    )
                  : const TextSpan(
                      style: TextStyle(
                        fontFamily: FeFonts.body,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        height: 1.5,
                        color: FeColors.fg,
                      ),
                      text: '결과만 주고\n근거는 감춥니다',
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            lit ? '"갈림까지 보여줍니다"' : '"팔짱을 끼고 있다"',
            style: const TextStyle(fontSize: 11, color: FeColors.muted),
          ),
        ],
      ),
    );
  }
}

/// 3. PRINCIPLES — 計·對·據 3도장.
class FePrinciplesSection extends StatelessWidget {
  const FePrinciplesSection({super.key});

  static const _items = [
    [
      '計',
      '계산',
      '여덟 글자는 감이 아니라 천문학',
      '입춘과 12절기의 절입 시각, 60갑자의 순환, 시주 구결 — 공개 기록과 교차검증된 만세력 원리 그대로 계산합니다.',
    ],
    [
      '對',
      '대조',
      '하나의 체계만 믿으면, 그 체계의 편견을 믿는 것',
      '사주·귀인지도·타로·관상·손금을 같은 질문에 놓고, 어디서 일치하고 어디서 갈리는지 나란히 보여드립니다.',
    ],
    [
      '據',
      '근거',
      '근거 없는 문장은 엔진 안에서 나오지 않습니다',
      '모든 판정에는 어떤 구결·어떤 측정값으로 나왔는지가 붙습니다.',
    ],
  ];

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
              hanja: '三則',
              mono: 'PRINCIPLES · 02',
              title: Text("왜 '근거'를 내밀까\n— 세 가지 원칙"),
            ),
          ),
          ..._items.asMap().entries.map((entry) {
            final i = entry.key;
            final h = entry.value[0],
                k = entry.value[1],
                t = entry.value[2],
                d = entry.value[3];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FeReveal(
                delay: Duration(milliseconds: i * 120),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: FeColors.card,
                    border: Border.all(color: FeColors.line),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Transform.rotate(
                        angle: -0.0873, // -5deg
                        child: Container(
                          width: 64,
                          height: 64,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                FeColors.accentLight,
                                FeColors.accentDark,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: FeColors.accent.withValues(alpha: 0.45),
                                blurRadius: 18,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              Center(
                                child: Text(
                                  h,
                                  style: const TextStyle(
                                    fontFamily: FeFonts.display,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 30,
                                    color: FeColors.sealText,
                                  ),
                                ),
                              ),
                              Positioned(
                                right: -4,
                                bottom: -4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: FeColors.bg2,
                                    border: Border.all(color: FeColors.glow),
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Text(
                                    '0${i + 1}',
                                    style: const TextStyle(
                                      fontFamily: FeFonts.mono,
                                      fontSize: 8,
                                      color: FeColors.glow,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              k,
                              style: const TextStyle(
                                fontFamily: FeFonts.display,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                color: FeColors.glow,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              t,
                              style: const TextStyle(
                                fontFamily: FeFonts.body,
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                                height: 1.4,
                                color: FeColors.fg,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              d,
                              style: const TextStyle(
                                fontSize: 12,
                                color: FeColors.muted,
                                height: 1.55,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
