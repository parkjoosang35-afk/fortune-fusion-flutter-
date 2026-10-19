// ═══════════════════════════════════════════════════════════════
// FILE: fe_section_saju_deep.dart — 6.SAJUCORE (세로 타임라인 5단계)
// 출처: design_files/engine-app.jsx SajuDeep().
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import '../fe_tokens.dart';
import '../fe_widgets.dart';

class FeSajuDeepSection extends StatelessWidget {
  const FeSajuDeepSection({super.key});

  static const _steps = [
    ['생년월일시 입력', '태어난 시각까지 받습니다.'],
    ['입춘·12절기 경계 판정', '한 해는 1월 1일이 아니라 입춘의 절입 시각에 바뀝니다. 달도 절기로 나눕니다.'],
    ['60갑자 순환으로 네 기둥', '년·월·일주는 60갑자 순환에서, 시주는 시주 구결로 세웁니다.'],
    ['오행 · 십신 · 신강신약', '오행을 세고, 일간 기준 십신을 붙이고, 정해진 득점 규칙으로 강약을 냅니다.'],
    ['근거와 함께 판정', '"근거 — 십신 중 편관·정관 0개 (일간 기준 산출 규칙)"처럼 문장마다 붙습니다.'],
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
              hanja: '八字',
              mono: 'SAJU CORE · 05',
              title: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '여덟 글자는\n'),
                    TextSpan(
                      text: '계산입니다',
                      style: TextStyle(color: FeColors.glow),
                    ),
                  ],
                ),
              ),
              sub: '입춘이 정하고, 절기가 정하고, 60갑자가 정합니다. 공개 기록과 교차검증된 만세력 원리 그대로.',
            ),
          ),
          FeReveal(
            delay: const Duration(milliseconds: 100),
            child: FeGlowCard(
              altar: true,
              child: Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Stack(
                  children: [
                    Positioned(
                      left: 8,
                      top: 6,
                      bottom: 6,
                      child: Container(
                        width: 1,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [FeColors.glow, Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _steps.asMap().entries.map((entry) {
                          final i = entry.key;
                          final t = entry.value[0], d = entry.value[1];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned(
                                  left: -22,
                                  top: 4,
                                  child: Container(
                                    width: 9,
                                    height: 9,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: FeColors.glow,
                                      boxShadow: [
                                        BoxShadow(
                                          color: FeColors.glow,
                                          blurRadius: 10,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'STEP · 0${i + 1}',
                                      style: const TextStyle(
                                        fontFamily: FeFonts.mono,
                                        fontSize: 9,
                                        color: FeColors.glow,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      t,
                                      style: const TextStyle(
                                        fontFamily: FeFonts.body,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      d,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        color: FeColors.muted,
                                        height: 1.55,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
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
