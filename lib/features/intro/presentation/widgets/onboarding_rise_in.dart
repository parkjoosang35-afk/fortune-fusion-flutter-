import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// [온보딩 화면 교체 2026-10-11] `Onboarding.html` `.rise` —
/// `@keyframes rise{from{opacity:0;translateY(12px);blur(4px)}to{opacity:1;
/// transform:none;blur(0)}}` 공용 등장 애니메이션. Eyebrow/H1/부제(A3)와
/// 버튼/Footer(A4)가 모두 이 효과를 재사용한다(README §1-4).
///
/// 스플래시 화면과 동일하게 "하나의 진입 시퀀스 컨트롤러가 흘려주는
/// 경과 시간(초)"을 받아 [startSeconds]/[durationSeconds]로 로컬
/// 진행률을 계산한다 — 여러 자식이 각자 다른 지연으로 똑같은 타임라인을
/// 공유해도 어긋나지 않는다.
class OnboardingRiseIn extends StatelessWidget {
  const OnboardingRiseIn({
    super.key,
    required this.elapsedSeconds,
    required this.startSeconds,
    this.durationSeconds = 1.2,
    required this.child,
  });

  final double elapsedSeconds;
  final double startSeconds;
  final double durationSeconds;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = durationSeconds <= 0
        ? (elapsedSeconds >= startSeconds ? 1.0 : 0.0)
        : ((elapsedSeconds - startSeconds) / durationSeconds).clamp(0.0, 1.0);
    final eased = Curves.easeOutCubic.transform(p);
    final blur = 4 * (1 - eased);

    Widget result = Opacity(
      opacity: eased,
      child: Transform.translate(
        offset: Offset(0, 12 * (1 - eased)),
        child: child,
      ),
    );
    if (blur > 0.01) {
      result = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: result,
      );
    }
    return result;
  }
}
