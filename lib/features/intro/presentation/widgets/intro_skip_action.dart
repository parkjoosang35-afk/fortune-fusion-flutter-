import 'package:flutter/material.dart';
import '../intro_text_styles.dart';

/// [인트로 전면 개편] 스킵 버튼 - 관리자 설정(showSkipButton)에 따라 노출 여부가
/// 결정된다.
///
/// [2026 디자인 핸드오프 콘텐츠 반영] 핸드오프 `.skip-btn`
/// (IBM Plex Mono 11px, letter-spacing 0.2em, uppercase, 우상단 절대위치)
/// 스타일을 그대로 이식했다. 텍스트는 핸드오프 원문 "건너뛰기"를 그대로
/// UPPERCASE 변환 없이 유지한다(한글은 대소문자 개념이 없어 letter-spacing만
/// 적용하면 시각적으로 동일한 톤이 재현된다).
class IntroSkipAction extends StatelessWidget {
  final VoidCallback onSkip;

  const IntroSkipAction({super.key, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onSkip,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text('건너뛰기', style: IntroTextStyles.skipButton()),
    );
  }
}
