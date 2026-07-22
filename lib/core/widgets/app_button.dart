import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// 03단계 §9.1 공통 컴포넌트 - Button 표준 (Phase1-1 보강)
///
/// 전역 [AppTheme]에 이미 Elevated/Outlined/Text 버튼 스타일이 정의되어 있으므로
/// 이 위젯은 "로딩 상태 처리"와 "variant 선택"만 얇게 감싸는 래퍼로 구현한다.
/// (중복 스타일 코드 금지 원칙 준수 - 스타일은 Theme에서 단일 관리)
enum AppButtonVariant { primary, secondary, ghost, danger }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final bool fullWidth;
  final IconData? icon;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.fullWidth = true,
    this.icon,
  });

  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.fullWidth = true,
    this.icon,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.ghost({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.fullWidth = true,
    this.icon,
  }) : variant = AppButtonVariant.ghost;

  const AppButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.fullWidth = true,
    this.icon,
  }) : variant = AppButtonVariant.danger;

  bool get _disabled => isLoading || onPressed == null;

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: variant == AppButtonVariant.ghost
                  ? AppColors.primary
                  : Colors.white,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: AppSpacing.sm),
              ],
              Text(label),
            ],
          );

    Widget button;
    switch (variant) {
      case AppButtonVariant.primary:
        button = ElevatedButton(
          onPressed: _disabled ? null : onPressed,
          child: child,
        );
        break;
      case AppButtonVariant.secondary:
        button = ElevatedButton(
          onPressed: _disabled ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.secondary,
            foregroundColor: AppColors.textPrimary,
          ),
          child: child,
        );
        break;
      case AppButtonVariant.ghost:
        button = OutlinedButton(
          onPressed: _disabled ? null : onPressed,
          child: child,
        );
        break;
      case AppButtonVariant.danger:
        button = ElevatedButton(
          onPressed: _disabled ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
          ),
          child: child,
        );
        break;
    }

    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}
