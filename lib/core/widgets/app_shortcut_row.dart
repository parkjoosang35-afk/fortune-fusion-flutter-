import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// [10단계 - 중복 UI 정리] 공통 "바로가기/요약 행" 위젯.
///
/// 행복머니 탭(`_ShortcutCard`)과 마이 탭(`_PassSummaryCard`/`_WalletSummaryCard`/
/// `_SubscriptionSummaryCard`)에서 "원형 이모지 아이콘 + 제목 + 부제목 + 화살표"
/// 구조가 거의 동일하게 반복되고 있어 하나의 공통 위젯으로 정리한다.
///
/// [주의] 바깥 카드(그라디언트/글로우/onTap 등)는 화면마다 CosmicCard로 감싸는
/// 방식이 다르므로 그대로 유지하고, 이 위젯은 카드 "내부 콘텐츠 행"만 표준화한다.
///
/// [Fortune Fusion 디자인 우선 리디자인 프롬프트] 화이트 프리미엄 화면(HomeScreen 등)
/// 에서도 재사용할 수 있도록 [titleColor]/[subtitleColor]를 선택적으로 노출한다.
/// 지정하지 않으면 기존 다크 우주 톤(cosmicTextPrimary/Tertiary)을 그대로 사용하므로
/// 기존 화면(마이/행복머니)은 영향받지 않는다.
class AppShortcutRow extends StatelessWidget {
  const AppShortcutRow({
    super.key,
    required this.emoji,
    required this.accentColor,
    required this.title,
    required this.subtitle,
    this.titleColor,
    this.subtitleColor,
  });

  final String emoji;
  final Color accentColor;
  final String title;
  final String subtitle;
  final Color? titleColor;
  final Color? subtitleColor;

  @override
  Widget build(BuildContext context) {
    final tColor = titleColor ?? AppColors.cosmicTextPrimary;
    final sColor = subtitleColor ?? AppColors.cosmicTextTertiary;
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 18))),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: tColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: sColor),
              ),
            ],
          ),
        ),
        Icon(Icons.arrow_forward_ios_rounded, size: 14, color: sColor),
      ],
    );
  }
}
