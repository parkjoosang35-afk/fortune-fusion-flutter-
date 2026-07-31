import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';
import '../theme/app_unified_style.dart';
import 'app_button.dart';

/// 03단계 §9.1 공통 컴포넌트 - Dialog 표준 (Phase1-1 보강)
/// 확인/취소형 다이얼로그를 표준화하여 각 Phase(부적 사용 확인, 결제 확인,
/// 신고 확인 등)에서 재사용한다.
Future<bool> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = '확인',
  String cancelLabel = '취소',
  bool isDanger = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: UnifiedColors.bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
      ),
      title: Text(title, style: UnifiedText.title()),
      content: message != null ? Text(message, style: UnifiedText.body()) : null,
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      actions: [
        Expanded(
          child: AppButton.ghost(
            label: cancelLabel,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: isDanger
              ? AppButton.danger(
                  label: confirmLabel,
                  onPressed: () => Navigator.of(ctx).pop(true),
                )
              : AppButton(
                  label: confirmLabel,
                  onPressed: () => Navigator.of(ctx).pop(true),
                ),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// 단순 안내(확인 버튼 1개)용 다이얼로그
Future<void> showAppInfoDialog(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = '확인',
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: UnifiedColors.bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
      ),
      title: Text(title, style: UnifiedText.title()),
      content: message != null ? Text(message, style: UnifiedText.body()) : null,
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: AppButton(
            label: confirmLabel,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ),
      ],
    ),
  );
}
