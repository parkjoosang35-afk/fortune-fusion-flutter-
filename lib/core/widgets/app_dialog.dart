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
      content: message != null
          ? Text(message, style: UnifiedText.body())
          : null,
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      // [버그 수정] AlertDialog.actions는 내부적으로 OverflowBar(가로 폭을
      // 콘텐츠에 맞추는 MainAxisSize.min Row 계열)로 감싸지므로, 그 자식으로
      // Expanded/Flexible을 "직접" 넣으면 "incoming width constraints are
      // unbounded" 레이아웃 오류가 발생해 다이얼로그 내용이 전혀 그려지지
      // 않는(배경색만 남는) 빈 박스가 된다. 두 버튼을 폭이 고정된 하나의
      // Row로 감싸 actions에는 그 Row 자체를 단일 항목으로 전달해야 한다.
      actions: [
        Row(
          children: [
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
      content: message != null
          ? Text(message, style: UnifiedText.body())
          : null,
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      // [버그 수정] 위 showAppConfirmDialog와 동일한 이유로, SizedBox(width:
      // double.infinity) 역시 OverflowBar의 unbounded 폭 컨텍스트에서는
      // 크기를 확정할 수 없어 빈 박스로 렌더링된다. 고정 폭을 갖는 Row +
      // Expanded로 감싸 실제 사용 가능한 폭(다이얼로그 - actionsPadding)만큼만
      // 채우도록 한다.
      actions: [
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: confirmLabel,
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
