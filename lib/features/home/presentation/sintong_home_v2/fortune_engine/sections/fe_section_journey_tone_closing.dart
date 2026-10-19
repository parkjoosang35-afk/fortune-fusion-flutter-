// ═══════════════════════════════════════════════════════════════
// FILE: fe_section_journey_tone_closing.dart — 11.JOURNEY / 12.WHATWESAY
// / 13.HONESTLIMITS(+약속)
// 출처: design_files/engine-app.jsx Journey() / Tone() / Closing().
// [카피규칙 준수] 느낌표 금지·단정어 금지·검증불가 숫자 금지·
// 수명질병예측 금지 원문 그대로 유지.
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import '../fe_tokens.dart';
import '../fe_widgets.dart';

/// 11. JOURNEY — 입력부터 결과 하단까지 6장 인용 카드.
class FeJourneySection extends StatelessWidget {
  const FeJourneySection({super.key});

  static const _items = [
    ['첫 화면', '"신통방통 — 운세를 지어내지 않습니다. 계산하고, 대조하고, 근거를 보여드립니다."'],
    ['온보딩', '"생년월일시는 여덟 글자가 되고, 얼굴은 비율이 되고, 손은 네 개의 선이 됩니다."'],
    ['조합 선택', '"29가지 조합, 전부 열려 있습니다. 가벼운 단일 리딩부터 다섯 엔진의 오경 종합까지."'],
    ['결과 상단', '"첫 문장을 읽기 전에, 몇 개의 관점이 동의하고 몇 개가 갈렸는지부터 보세요."'],
    [
      '근거 카드',
      '"각 항목의 판정에는 적용한 구결(한자 원문), 측정값, 환산 기준이 붙어 있습니다. 근거를 펼쳐 보고 리딩을 읽으세요."',
    ],
    ['신뢰 고지', '"전통 해석 체계를 코드로 구현한 자기 성찰 도구입니다. 과학적 확률 예측이 아닙니다."'],
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
              hanja: '道',
              mono: 'JOURNEY · 10',
              title: Text('입력부터\n결과 하단까지'),
            ),
          ),
          Column(
            children: _items.asMap().entries.map((entry) {
              final i = entry.key;
              final t = entry.value[0], q = entry.value[1];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: FeReveal(
                  delay: Duration(milliseconds: i * 60),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: FeColors.card,
                      border: Border.all(color: FeColors.line),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 44,
                          child: Text(
                            '${i + 1}'.padLeft(2, '0'),
                            style: const TextStyle(
                              fontFamily: FeFonts.mono,
                              fontSize: 18,
                              color: FeColors.glow,
                              shadows: [
                                Shadow(
                                  color: FeColors.glowShadow,
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t,
                                style: const TextStyle(
                                  fontFamily: FeFonts.body,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                q,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: FeColors.muted,
                                  height: 1.6,
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
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// 12. WHAT WE SAY — ✓/✕ 박스.
class FeToneSection extends StatelessWidget {
  const FeToneSection({super.key});

  static const _yes = [
    '근거 — 십신 중 편관·정관 0개 (일간 기준 산출 규칙)',
    '두 관점이 갈립니다 — 각각의 근거를 비교해 보세요',
    '귀인이 여덟 글자에 뜨지 않았습니다 — 없다는 뜻이 아니라 대운에서 옵니다',
    '이 판정의 환산 기준은 이렇습니다: 강함=2 · 보통=1 · 약함=0',
  ];
  static const _no = [
    ['적중률 99%', '검증할 수 없는 숫자는 쓰지 않습니다'],
    ['반드시, 틀림없이, 무조건', '확정적 단정은 하지 않습니다'],
    ['생명선이 짧으니 건강을 조심하세요', '수명·질병 예측은 하지 않습니다'],
    ['AI가 특별하게 느껴서', '엔진 밖의 직관으로 판정하지 않습니다'],
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
              hanja: '言',
              mono: 'WHAT WE SAY · 11',
              title: Text('하는 말과\n하지 않는 말'),
            ),
          ),
          FeReveal(
            delay: const Duration(milliseconds: 60),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: FeColors.ok.withValues(alpha: 0.08),
                    border: Border.all(
                      color: FeColors.ok.withValues(alpha: 0.4),
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          '✓ 이렇게 말합니다',
                          style: TextStyle(
                            fontFamily: FeFonts.body,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Color(0xFF9CC8B6),
                          ),
                        ),
                      ),
                      ..._yes.map(
                        (t) => Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color: FeColors.line,
                                style: BorderStyle.solid,
                              ),
                            ),
                          ),
                          child: Text(
                            '"$t"',
                            style: const TextStyle(
                              fontSize: 12.5,
                              height: 1.55,
                              color: FeColors.fg,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: FeColors.accent.withValues(alpha: 0.07),
                    border: Border.all(
                      color: FeColors.accent.withValues(alpha: 0.35),
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          '✕ 이렇게 말하지 않습니다',
                          style: TextStyle(
                            fontFamily: FeFonts.body,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: FeColors.tense,
                          ),
                        ),
                      ),
                      ..._no.map(
                        (pair) => Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color: FeColors.line,
                                style: BorderStyle.solid,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '"${pair[0]}"',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: FeColors.muted,
                                  decoration: TextDecoration.lineThrough,
                                  decorationColor: FeColors.tense,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                pair[1],
                                style: const TextStyle(
                                  fontFamily: FeFonts.ui,
                                  fontSize: 11.5,
                                  color: FeColors.fg,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 13. HONESTLIMITS + 신통방통의 약속 (클로징).
class FeClosingSection extends StatelessWidget {
  const FeClosingSection({super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 60),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              FeSpace.screenH,
              FeSpace.sectionTop,
              FeSpace.screenH,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FeReveal(
                  child: FeSectionHead(
                    hanja: '限',
                    mono: 'HONEST LIMITS · 12',
                    title: Text('한계도 함께 말씀드립니다'),
                  ),
                ),
                FeReveal(
                  delay: const Duration(milliseconds: 100),
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
                          height: 1.7,
                          color: FeColors.muted,
                        ),
                        children: [
                          TextSpan(text: '신통방통은 '),
                          TextSpan(
                            text: '전통 해석 체계를 코드로 구현한 자기 성찰 도구',
                            style: TextStyle(
                              color: FeColors.fg,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: '입니다. 과학적 확률 예측이 아니며, 의료·법률·투자·인생의 중대 결정은 ',
                          ),
                          TextSpan(
                            text: '리딩이 아닌 판단',
                            style: TextStyle(
                              color: FeColors.fg,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(text: '으로 하시기 바랍니다.'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: FeSpace.screenH),
            child: FeReveal(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 30,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: FeColors.glow.withValues(alpha: 0.3),
                  ),
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.3,
                    colors: [
                      FeColors.glow.withValues(alpha: 0.18),
                      const Color(0xFF0D0820),
                    ],
                    stops: const [0, 0.7],
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Opacity(
                      opacity: 0.35,
                      child: FeSigil(
                        size: 300,
                        color: FeColors.glow,
                        opacity: 0.6,
                      ),
                    ),
                    const Positioned.fill(
                      child: FeDust(count: 10, color: FeColors.glow),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '✦ 신통방통의 약속 ✦',
                          style: TextStyle(
                            fontFamily: FeFonts.body,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: FeColors.glow,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          '운세를 지어내지 않습니다.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: FeFonts.display,
                            fontWeight: FontWeight.w700,
                            fontSize: 19,
                            height: 1.6,
                            color: FeColors.fg,
                          ),
                        ),
                        const Text(
                          '계산하고, 대조하고,\n근거를 보여드립니다.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: FeFonts.display,
                            fontWeight: FontWeight.w700,
                            fontSize: 19,
                            height: 1.3,
                            color: FeColors.glow,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          '"결과만 파는 운세는 팔짱을 끼고 있고,\n신통방통은 계산서를 함께 줍니다."',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: FeFonts.body,
                            fontSize: 13,
                            height: 1.6,
                            color: FeColors.muted,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'fortune_engine 1.1 · 30 TESTS PASSED',
                          style: TextStyle(
                            fontFamily: FeFonts.mono,
                            fontSize: 10,
                            color: FeColors.muted,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
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
