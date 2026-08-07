import 'package:flutter/material.dart';
import '../../../../core/theme/app_unified_style.dart';

/// [인트로 전면 개편] 스킵 버튼 - 관리자 설정(showSkipButton)에 따라 노출 여부가
/// 결정된다. 우상단에 작게 배치, 눈에 띄지만 방해되지 않는 톤.
class IntroSkipAction extends StatelessWidget {
  final VoidCallback onSkip;

  const IntroSkipAction({super.key, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onSkip,
      style: TextButton.styleFrom(
        foregroundColor: UnifiedColors.textSecondary,
        padding: const EdgeInsets.symmetric(
          horizontal: UnifiedTokens.spaceLg,
          vertical: UnifiedTokens.spaceSm,
        ),
      ),
      child: Text('건너뛰기', style: UnifiedText.bodySmall()),
    );
  }
}
