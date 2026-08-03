import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// [10단계 - 중복 UI 정리] 공통 "바로가기/요약 행" 위젯.
///
/// 복주머니 탭(`_ShortcutCard`)과 마이 탭(`_PassSummaryCard`/`_WalletSummaryCard`/
/// `_SubscriptionSummaryCard`)에서 "원형 이모지 아이콘 + 제목 + 부제목 + 화살표"
/// 구조가 거의 동일하게 반복되고 있어 하나의 공통 위젯으로 정리한다.
///
/// [주의] 바깥 카드(그라디언트/글로우/onTap 등)는 화면마다 CosmicCard로 감싸는
/// 방식이 다르므로 그대로 유지하고, 이 위젯은 카드 "내부 콘텐츠 행"만 표준화한다.
///
/// [Fortune Fusion 디자인 우선 리디자인 프롬프트] 화이트 프리미엄 화면(HomeScreen 등)
/// 에서도 재사용할 수 있도록 [titleColor]/[subtitleColor]를 선택적으로 노출한다.
/// 지정하지 않으면 기존 다크 우주 톤(cosmicTextPrimary/Tertiary)을 그대로 사용하므로
/// 기존 화면(마이/복주머니)은 영향받지 않는다.
class AppShortcutRow extends StatelessWidget {
  const AppShortcutRow({
    super.key,
    required this.emoji,
    required this.accentColor,
    required this.title,
    required this.subtitle,
    this.titleColor,
    this.subtitleColor,
    this.icon,
    this.iconColor,
    this.circleColor,
    this.circleSize,
    this.titleStyle,
    this.subtitleStyle,
    this.arrowColor,
    this.arrowSize,
    this.spacing,
  });

  final String emoji;
  final Color accentColor;
  final String title;
  final String subtitle;
  final Color? titleColor;
  final Color? subtitleColor;

  /// [서브 디자인 통일 확산 프롬프트] 라이트 톤 서브 화면(마이 탭 등)에서
  /// 이모지 대신 라인 아이콘을 사용할 수 있도록 하는 선택적 오버라이드.
  /// 지정하지 않으면 기존 이모지 렌더링을 그대로 유지해 마이 탭 외 다른
  /// 사용처(없음)에도 영향이 없다.
  final IconData? icon;
  final Color? iconColor;
  final Color? circleColor;
  final double? circleSize;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final Color? arrowColor;
  final double? arrowSize;
  final double? spacing;

  @override
  Widget build(BuildContext context) {
    final tColor = titleColor ?? AppColors.cosmicTextPrimary;
    final sColor = subtitleColor ?? AppColors.cosmicTextTertiary;
    final size = circleSize ?? 40;
    return Row(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: circleColor ?? accentColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: icon != null
                ? Icon(icon, size: size * 0.45, color: iconColor ?? accentColor)
                : Text(emoji, style: const TextStyle(fontSize: 18)),
          ),
        ),
        SizedBox(width: spacing ?? AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style:
                    titleStyle ??
                    TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: tColor,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: subtitleStyle ?? TextStyle(fontSize: 11, color: sColor),
              ),
            ],
          ),
        ),
        Icon(
          Icons.arrow_forward_ios_rounded,
          size: arrowSize ?? 14,
          color: arrowColor ?? sColor,
        ),
      ],
    );
  }
}
