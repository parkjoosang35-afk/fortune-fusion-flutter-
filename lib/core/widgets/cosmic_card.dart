import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// [Fortune Fusion UI 리뉴얼 프롬프트] §2-1 CosmicCard - 카드의 기본형
///
/// 우주 감성 다크 테마의 표준 카드 컨테이너. 배경/테두리/그림자/라운드를
/// 웹 프로토타입 톤(딥네이비 + 은은한 보라빛 글로우)에 맞춰 통일한다.
/// 기존 core/widgets/app_card.dart는 그대로 유지하고, 이 위젯은 신규
/// 우주 테마 화면(HomeScreen, FortuneHubScreen 등)에서 사용한다.
class CosmicCard extends StatelessWidget {
  const CosmicCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    this.margin,
    this.borderRadius,
    this.gradient,
    this.backgroundColor,
    this.borderColor,
    this.onTap,
    this.showGlow = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;

  /// 지정 시 [backgroundColor] 대신 그라디언트 배경을 사용한다.
  final Gradient? gradient;
  final Color? backgroundColor;
  final Color? borderColor;
  final VoidCallback? onTap;

  /// 카드 하단에 은은한 보라빛 글로우 그림자를 표시할지 여부.
  final bool showGlow;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(AppSpacing.radiusLg);

    final card = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null
            ? (backgroundColor ?? AppColors.bgSecondary)
            : null,
        gradient: gradient,
        borderRadius: radius,
        border: Border.all(color: borderColor ?? AppColors.border, width: 1),
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: const Color(0x339D7BFF),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: child,
    );

    if (onTap == null) return card;

    return ClipRRect(
      borderRadius: radius,
      child: Material(
        color: Colors.transparent,
        child: InkWell(onTap: onTap, child: card),
      ),
    );
  }
}
