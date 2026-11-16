// ═══════════════════════════════════════════════════════════════
// FILE: intro_sheet.dart
// [궁합지도 핸드오프 v4] `00_DEV_MAPPING.md` §5 S07 "궁합지도 소개"
// (신규·정적) — 원본 핸드오프에 대응 Dart 파일이 전혀 없어 명세
// 텍스트(§5 S07, line 375-386) 기준으로 새로 작성했다.
//
// 구성(위→아래)
//  1. mono "ABOUT · 宮合之圖" + ✕
//  2. sheetTitle "두 사람의 운명을 잇는 / 별의 지도, 궁합지도"
//  3. 13.5 설명문
//  4. 4단계 카드(번호 28×28 gradPrimary)
//  5. 12 안내 문구
//  Footer: Primary "✦ 새 궁합 시작하기" → S08 direct
//
// [진입점] S01 홈 우상단 68×68 "궁합지도" 소개 버튼 → 이 시트.
// [onStart] "✦ 새 궁합 시작하기" — 호출부가 GunghapMajorScreen
// (method: 'direct')으로 네비게이션한다(이 위젯은 콜백만 노출).
import 'package:flutter/material.dart';

import '../theme/gh_tokens.dart';
import '../theme/gh_typography.dart';
import 'gh_button.dart';

Future<void> showGunghapIntroSheet(
  BuildContext context, {
  required VoidCallback onStart,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: GHColors.scrim,
    builder: (ctx) => _IntroSheet(onStart: onStart),
  );
}

class _IntroStep {
  const _IntroStep(this.title, this.desc);
  final String title;
  final String desc;
}

const _steps = [
  _IntroStep(
    '궁합을 보면 별이 떠요',
    '궁합을 본 사람마다 지도에 별이 하나씩 생겨요. 한 사람은 별 하나, 가장 최근 궁합으로 표시돼요.',
  ),
  _IntroStep(
    '가까울수록 잘 맞아요',
    '가운데 「나」와 가까울수록 궁합 점수가 높아요. 새로 궁합을 보면 별이 새 자리로 옮겨 가요.',
  ),
  _IntroStep(
    '네모는 궁합 분야예요',
    '연애·결혼·가족 등 8개 분야를 누르면 그 분야로 본 사람만 모아 볼 수 있어요.',
  ),
  _IntroStep(
    '별을 누르면 관계가 열려요',
    '두 사람의 점수, 오행 관계, 함께 본 궁합 기록을 한눈에 볼 수 있어요.',
  ),
];

class _IntroSheet extends StatelessWidget {
  const _IntroSheet({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .86),
      child: Container(
        decoration: BoxDecoration(
          gradient: GHGradients.sheet,
          border: Border.all(color: GHColors.line),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(GHRadius.sheet)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              decoration: BoxDecoration(
                color: GHColors.gray.withValues(alpha: .35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. header
                    Row(
                      children: [
                        Expanded(
                          child: Text('ABOUT · 宮合之圖', style: GHText.mono(color: GHColors.gold)),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Text('✕', style: TextStyle(color: GHColors.ivory)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // 2. sheetTitle
                    Text(
                      '두 사람의 운명을 잇는\n별의 지도, 궁합지도',
                      style: GHText.sheetTitle(),
                    ),
                    const SizedBox(height: 10),
                    // 3. 설명문
                    Text(
                      '신통방통 정통사주로 본 궁합이 한 장의 지도로 모여요. 나를 중심으로 어떤 인연이 곁에 있는지 살펴보세요.',
                      style: GHText.ui(size: 13.5, color: GHColors.gray, height: 1.6),
                    ),
                    const SizedBox(height: 18),
                    // 4. 4단계 카드
                    for (var i = 0; i < _steps.length; i++) ...[
                      _StepCard(index: i + 1, step: _steps[i]),
                      if (i != _steps.length - 1) const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 16),
                    // 5. 안내 문구
                    Text(
                      '궁합 점수는 사주 엔진이 계산한 값이에요. 관계를 단정하기보다 서로를 이해하는 참고로 봐 주세요.',
                      style: GHText.ui(size: 12, color: GHColors.gray, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + MediaQuery.of(context).padding.bottom),
              child: GHButton(
                label: '✦ 새 궁합 시작하기',
                size: GHButtonSizeT.lg,
                onPressed: () {
                  Navigator.of(context).pop();
                  onStart();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.index, required this.step});
  final int index;
  final _IntroStep step;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: GHColors.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: GHColors.lineSoft, width: GHBorder.width),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            gradient: GHGradients.primary,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$index',
            style: GHText.ui(size: 13, weight: FontWeight.w800, color: Colors.white),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(step.title, style: GHText.cardTitle(size: 14.5)),
              const SizedBox(height: 4),
              Text(
                step.desc,
                style: GHText.ui(size: 12.5, color: GHColors.gray, height: 1.55),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
