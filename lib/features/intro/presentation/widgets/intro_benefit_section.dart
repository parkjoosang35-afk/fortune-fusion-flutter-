import 'package:flutter/material.dart';
import '../../../../core/theme/app_unified_style.dart';
import '../intro_palette.dart';

/// [인트로 전면 개편] 카드1/카드2 공통 - 제목 + 설명 텍스트 블록.
/// 사용자 요청서에 지정된 카피를 그대로 렌더링한다.
///
/// [Moonlit Crystal 리스킨] 배경이 다크 톤으로 바뀌어 텍스트 색을
/// `IntroPalette.textPrimary`/`textSecondary`(밝은 라벤더 화이트 계열)로
/// 오버라이드한다. 폰트/사이즈/구조는 그대로 유지한다.
class IntroBenefitSection extends StatelessWidget {
  final String title;
  final String description;

  const IntroBenefitSection({
    super.key,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: UnifiedText.titleLarge(color: IntroPalette.textPrimary)
              .copyWith(fontSize: 20, height: 1.35),
        ),
        const SizedBox(height: UnifiedTokens.spaceMd),
        Text(
          description,
          style: UnifiedText.body(color: IntroPalette.textSecondary)
              .copyWith(fontSize: 15, height: 1.5),
        ),
      ],
    );
  }
}
