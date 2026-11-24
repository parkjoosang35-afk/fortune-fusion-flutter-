// ═══════════════════════════════════════════════════════════════
// FILE: fe_section_flow.dart — 4.HOWITWORKS (플로우 4단계 + 입計對據 스텝)
// 출처: design_files/engine-app.jsx HowItFlows().
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import '../fe_data.dart';
import '../fe_tokens.dart';
import '../fe_widgets.dart';

class FeFlowSection extends StatelessWidget {
  const FeFlowSection({super.key});

  static const _rows = [
    [
      '생년월일시',
      '태어난 시각까지',
      ['S', 'G'],
      '여덟 글자',
    ],
    [
      '질문 + 시드',
      '고정된 추출 번호',
      ['T'],
      '카드 스프레드',
    ],
    [
      '얼굴',
      '정면 사진',
      ['F'],
      '비율',
    ],
    [
      '손',
      '손바닥 사진',
      ['P'],
      '네 개의 선',
    ],
  ];

  static const _steps = [
    ['入', '입력', '실제 데이터\n그대로'],
    ['計', '계산', '검증된\n엔진 실행'],
    ['對', '대조', '여섯 차원에\n나란히'],
    ['據', '근거', '구결·측정값\n공개'],
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
              hanja: '流',
              mono: 'HOW IT WORKS · 03',
              title: Text('실제 데이터가\n판정이 되기까지'),
              sub:
                  '생년월일시는 여덟 글자가 되고, 얼굴은 비율이 되고, 손은 네 개의 선이 됩니다. 준비되는 만큼 조합이 깊어집니다.',
            ),
          ),
          FeReveal(
            delay: const Duration(milliseconds: 100),
            child: Column(
              children: _rows.map((r) {
                final k = r[0] as String, v = r[1] as String;
                final ids = r[2] as List<String>;
                final out = r[3] as String;
                final c = feEngineOf(ids.first).color;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: FeColors.card,
                            border: Border.all(color: FeColors.line),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                k,
                                style: const TextStyle(
                                  fontFamily: FeFonts.body,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                v,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: FeColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 26,
                        height: 2,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.transparent, c],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: c.withValues(alpha: 0.09),
                            border: Border.all(
                              color: c.withValues(alpha: 0.45),
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ids.map((i) => feEngineOf(i).ko).join(' · '),
                                style: TextStyle(
                                  fontFamily: FeFonts.body,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: c,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '→ $out',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: FeColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          FeReveal(
            delay: const Duration(milliseconds: 200),
            child: Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Row(
                children: _steps.map((s) {
                  final h = s[0], t = s[1], d = s[2];
                  return Expanded(
                    child: Column(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: FeColors.bg2,
                            border: Border.all(color: FeColors.glow),
                            boxShadow: FeShadow.glow(FeColors.glow, blur: 18),
                          ),
                          child: Text(
                            h,
                            style: const TextStyle(
                              fontFamily: FeFonts.display,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: FeColors.glow,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          t,
                          style: const TextStyle(
                            fontFamily: FeFonts.body,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          d,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 9.5,
                            color: FeColors.muted,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FeReveal(
            delay: const Duration(milliseconds: 240),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: FeColors.card,
                border: Border.all(color: FeColors.line),
                borderRadius: BorderRadius.circular(99),
              ),
              child: RichText(
                textAlign: TextAlign.center,
                text: const TextSpan(
                  style: TextStyle(
                    fontFamily: FeFonts.body,
                    fontSize: 12,
                    color: FeColors.muted,
                  ),
                  children: [
                    TextSpan(text: '☾ 출생 정보만으로도 '),
                    TextSpan(
                      text: '15가지 조합 리딩',
                      style: TextStyle(
                        color: FeColors.glow,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(text: '이 열립니다.'),
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
