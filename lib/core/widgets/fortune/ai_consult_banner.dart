import 'package:flutter/material.dart';
import '../../theme/app_unified_style.dart';

/// 재사용 위젯 ⑦ AIConsultBanner — 결과 화면 섹션12 하단 배너.
///
/// 배경 #F2F0FA(cardBanner), radius14, padding12.
/// 메인(Title15) + 서브(Caption12) + 우측 원형 CTA(32, 블랙+neon 아이콘).
class AIConsultBanner extends StatelessWidget {
  const AIConsultBanner({
    super.key,
    required this.onTap,
    this.title = 'AI 상담으로 더 자세히 보기',
    this.subtitle = '오늘 본 운세를 기반으로 상담받아보세요',
  });

  final VoidCallback onTap;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(UnifiedTokens.spaceMd),
        decoration: BoxDecoration(
          color: UnifiedColors.cardBanner,
          borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: UnifiedText.title()),
                  const SizedBox(height: 2),
                  Text(subtitle, style: UnifiedText.caption()),
                ],
              ),
            ),
            const SizedBox(width: UnifiedTokens.spaceSm),
            Container(
              width: UnifiedTokens.iconCircleLg,
              height: UnifiedTokens.iconCircleLg,
              decoration: const BoxDecoration(
                color: UnifiedColors.black,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_forward_rounded,
                size: UnifiedTokens.iconLg,
                color: UnifiedColors.neon,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
