import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// [Fortune Fusion 디자인 우선 리디자인 프롬프트] §6-A 카드 스타일
///
/// 화이트/옅은 라벤더 배경, 라운드 20~24, 1px 연보라/연회색 보더,
/// 은은한 그림자, 넉넉한 패딩을 표준화한 프리미엄 카드 컨테이너.
/// 기존 [CosmicCard](다크 우주 화면 전용)는 그대로 유지하고, 이 위젯은
/// 화이트 베이스 리디자인 대상 화면(HomeScreen 등)에서 사용한다.
class PremiumCard extends StatelessWidget {
  const PremiumCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.margin,
    this.borderRadius,
    this.backgroundColor,
    this.gradient,
    this.borderColor,
    this.onTap,
    this.showShadow = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;

  /// 지정 시 [backgroundColor] 대신 그라디언트 배경을 사용한다(히어로 카드 등).
  final Gradient? gradient;
  final Color? borderColor;
  final VoidCallback? onTap;

  /// 은은한 퍼플 톤 그림자 표시 여부.
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(AppSpacing.radiusLg);

    final card = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null
            ? (backgroundColor ?? AppColors.premiumBgSection)
            : null,
        gradient: gradient,
        borderRadius: radius,
        border: Border.all(
          color: borderColor ?? AppColors.premiumCardBorder,
          width: 1,
        ),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: AppColors.premiumCardShadow,
                  blurRadius: 20,
                  offset: const Offset(0, 6),
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
