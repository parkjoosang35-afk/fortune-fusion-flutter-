import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';

/// 03단계 §9.1 공통 컴포넌트 - Card 표준 (Phase1-1 보강)
///
/// 전역 [AppTheme]의 cardTheme(색상/그림자/라운드)을 그대로 상속받는 래퍼로,
/// 03단계 §9.2 "도메인특화카드"(부적카드/복주머니카드 등)가 공통 기반으로
/// 확장(compose)할 수 있도록 padding/onTap만 표준화한다.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Gradient? gradient;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
    this.color,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final cardTheme = Theme.of(context).cardTheme;

    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? cardTheme.color) : null,
        gradient: gradient,
        borderRadius:
            (cardTheme.shape as RoundedRectangleBorder?)?.borderRadius
                as BorderRadius? ??
            BorderRadius.circular(16),
        boxShadow: gradient == null
            ? [
                BoxShadow(
                  color: cardTheme.shadowColor ?? Colors.transparent,
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: child,
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      borderRadius:
          (cardTheme.shape as RoundedRectangleBorder?)?.borderRadius
              as BorderRadius? ??
          BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius:
            (cardTheme.shape as RoundedRectangleBorder?)?.borderRadius
                as BorderRadius? ??
            BorderRadius.circular(16),
        child: content,
      ),
    );
  }
}
