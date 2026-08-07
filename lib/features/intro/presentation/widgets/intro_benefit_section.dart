import 'package:flutter/material.dart';
import '../../../../core/theme/app_unified_style.dart';

/// [인트로 전면 개편] 카드1/카드2 공통 - 제목 + 설명 텍스트 블록.
/// 사용자 요청서에 지정된 카피를 그대로 렌더링하며, 색/폰트는 UnifiedText를
/// 그대로 사용한다(과한 강조/장식 없이 타이틀+본문 2단 구성).
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
          style: UnifiedText.titleLarge().copyWith(fontSize: 20, height: 1.35),
        ),
        const SizedBox(height: UnifiedTokens.spaceMd),
        Text(description, style: UnifiedText.body().copyWith(fontSize: 15, height: 1.5)),
      ],
    );
  }
}
