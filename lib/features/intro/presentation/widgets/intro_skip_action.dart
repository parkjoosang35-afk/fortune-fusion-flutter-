import 'package:flutter/material.dart';
import '../../../../core/theme/app_unified_style.dart';
import '../intro_palette.dart';

/// [인트로 전면 개편] 스킵 버튼 - 관리자 설정(showSkipButton)에 따라 노출 여부가
/// 결정된다. 우상단에 작게 배치, 눈에 띄지만 방해되지 않는 톤.
///
/// [2026-08-21 인트로 3종 색상 정리] 텍스트 색을 브랜드 톤(짙은 마젠타)으로
/// 살짝 바꿔 다른 인트로 요소들과 톤을 맞췄다.
class IntroSkipAction extends StatelessWidget {
  final VoidCallback onSkip;

  const IntroSkipAction({super.key, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onSkip,
      style: TextButton.styleFrom(
        foregroundColor: IntroPalette.primaryDark,
        padding: const EdgeInsets.symmetric(
          horizontal: UnifiedTokens.spaceLg,
          vertical: UnifiedTokens.spaceSm,
        ),
      ),
      child: Text(
        '건너뛰기',
        style: UnifiedText.bodySmall(color: IntroPalette.primaryDark),
      ),
    );
  }
}
