import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../intro_palette.dart';

/// [온보딩 전면 교체 2026-11 — design_handoff_onboarding_v2.zip 반영]
/// `Onboarding v2.html` `.copy`/`.dots` 블록 — 소개 3장 캐러셀(eyebrow +
/// 강조 H1 + 본문)과 진행 점(활성 점 안에 5.2초 progress bar) 조합.
///
/// README §3 "Stage — 카피 캐러셀" 표를 그대로 이식한다. 캐러셀 자체의
/// 자동전환 타이머·스와이프 제스처는 호출부([_IntroPagerScreenState])가
/// 담당하고, 이 위젯은 `index`가 바뀔 때의 전환 애니메이션(opacity/
/// translateY/blur)과 점 UI만 책임진다.
class OnboardingSlideData {
  const OnboardingSlideData({
    required this.eyebrow,
    required this.titlePrefix,
    required this.titleEmphasis,
    required this.titleSuffix,
    required this.body,
  });

  final String eyebrow;
  final String titlePrefix;
  final String titleEmphasis;
  final String titleSuffix;
  final String body;
}

const List<OnboardingSlideData> kOnboardingSlides = [
  OnboardingSlideData(
    eyebrow: 'SAJU · 01',
    titlePrefix: '태어난 그 순간에\n',
    titleEmphasis: '당신의 이야기',
    titleSuffix: '가 있어요',
    body: '생년월일시에 담긴 결을\n천천히, 깊이 읽어드릴게요',
  ),
  OnboardingSlideData(
    eyebrow: 'WISH · 02',
    titlePrefix: '마음속 바람은\n',
    titleEmphasis: '달빛에 담아',
    titleSuffix: '두세요',
    body: '소원을 적고 봉인하면\n이루어질 때까지 함께 밝혀둘게요',
  ),
  OnboardingSlideData(
    eyebrow: 'TODAY · 03',
    titlePrefix: '매일 아침,\n',
    titleEmphasis: '오늘의 기운',
    titleSuffix: '을 살펴봐요',
    body: '하루를 여는 짧은 한마디로\n조금 더 단단한 하루를 보내요',
  ),
];

class OnboardingCopyCarousel extends StatelessWidget {
  const OnboardingCopyCarousel({
    super.key,
    required this.index,
    required this.isCompact,
  });

  final int index;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final titleSize = isCompact ? 23.0 : 27.0;
    final titleMarginTop = isCompact ? 10.0 : 14.0;

    return Semantics(
      liveRegion: true,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          for (var i = 0; i < kOnboardingSlides.length; i++)
            _SlideLayer(
              data: kOnboardingSlides[i],
              visible: i == index,
              titleSize: titleSize,
              titleMarginTop: titleMarginTop,
            ),
        ],
      ),
    );
  }
}

/// `.slide` — 겹쳐둔 3장 중 현재 장만 보여주는 교차 전환(crossfade +
/// translateY + blur).
class _SlideLayer extends StatelessWidget {
  const _SlideLayer({
    required this.data,
    required this.visible,
    required this.titleSize,
    required this.titleMarginTop,
  });

  final OnboardingSlideData data;
  final bool visible;
  final double titleSize;
  final double titleMarginTop;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 1000),
        curve: Curves.easeInOut,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(0, 0.03),
          duration: const Duration(milliseconds: 1200),
          curve: const Cubic(0.2, 0.7, 0.2, 1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  data.eyebrow,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 10 * 0.38,
                    color: IntroPalette.crystal,
                  ),
                ),
                SizedBox(height: titleMarginTop),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: GoogleFonts.notoSerifKr(
                      fontSize: titleSize,
                      fontWeight: FontWeight.w900,
                      height: 1.32,
                      letterSpacing: titleSize * -0.025,
                      color: IntroPalette.textPrimary,
                    ),
                    children: [
                      TextSpan(text: data.titlePrefix),
                      TextSpan(
                        text: data.titleEmphasis,
                        style: const TextStyle(
                          color: IntroPalette.primary,
                          shadows: [
                            Shadow(
                              color: IntroPalette.glowShadow,
                              blurRadius: 20,
                            ),
                          ],
                        ),
                      ),
                      TextSpan(text: data.titleSuffix),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  data.body,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.gowunBatang(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    height: 1.7,
                    color: IntroPalette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `.dots` — 기본 6×6 원, 현재 장은 너비 26px + 내부 progress bar(5.2초
/// linear fill). [progress]는 호출부 타이머와 동기화된 0~1 값(활성 점
/// 전용)이다.
class OnboardingDots extends StatelessWidget {
  const OnboardingDots({
    super.key,
    required this.count,
    required this.activeIndex,
    required this.activeProgress,
    required this.onTapDot,
  });

  final int count;
  final int activeIndex;
  final double activeProgress;
  final ValueChanged<int> onTapDot;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          _Dot(
            active: i == activeIndex,
            progress: i == activeIndex ? activeProgress : 0.0,
            label: '${i + 1}번째',
            onTap: () => onTapDot(i),
          ),
        ],
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({
    required this.active,
    required this.progress,
    required this.label,
    required this.onTap,
  });

  final bool active;
  final double progress;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 800),
            curve: const Cubic(0.2, 0.7, 0.2, 1),
            width: active ? 26 : 6,
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: active
                  ? IntroPalette.introDotActiveBg
                  : IntroPalette.cardBorder,
            ),
            clipBehavior: Clip.hardEdge,
            child: active
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: progress.clamp(0.0, 1.0),
                      heightFactor: 1.0,
                      child: Container(color: IntroPalette.primary),
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}
