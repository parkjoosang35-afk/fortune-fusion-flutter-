import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import 'consultation_type_style.dart';

/// 07단계(추가) §3.4 - 재사용 가능한 채팅 입력창 컴포넌트.
/// isLoading(전송/스트리밍 중)일 때 전송 버튼을 비활성화하고, 상담 유형별
/// 포인트 컬러(typeStyle.primaryColor)로 전송 버튼을 강조한다.
///
/// 07단계(추가) §3.5 - 사주상담의 생년월일/출생시간 입력 단계에서는 텍스트 직접
/// 입력과 함께 네이티브 피커(showDatePicker/showTimePicker)도 이용할 수 있도록
/// [leadingIcon]/[onLeadingTap](피커 버튼)과 [trailingAction](건너뛰기 등 보조 버튼)
/// 슬롯을 추가한다. 두 값 모두 기본값(null)이면 기존 UI와 완전히 동일하게 렌더링되어
/// 일반상담 등 기존 사용 지점의 동작·모양에는 영향이 없다.
class InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;
  final ConsultationTypeStyle typeStyle;

  /// 07단계(추가) §3.5 - hint 문구를 단계별로 오버라이드하고 싶을 때 사용.
  /// null이면 기존 기본 문구('메시지를 입력하세요' / 'AI가 답변하고 있어요...')를 사용한다.
  final String? hintText;

  /// 07단계(추가) §3.5 - 텍스트 입력창 앞에 표시할 보조 아이콘 버튼(예: 날짜/시간 피커 열기).
  final IconData? leadingIcon;
  final VoidCallback? onLeadingTap;

  /// 07단계(추가) §3.5 - 입력창 아래(또는 옆)에 배치할 보조 액션 위젯(예: "건너뛰기" 텍스트 버튼).
  final Widget? trailingAction;

  const InputBar({
    super.key,
    required this.controller,
    required this.enabled,
    required this.onSend,
    required this.typeStyle,
    this.hintText,
    this.leadingIcon,
    this.onLeadingTap,
    this.trailingAction,
  });

  @override
  Widget build(BuildContext context) {
    // 07단계(추가) §3.4 반응형 - 키보드가 올라오면 SafeArea bottom inset이 0이 되므로
    // 별도 처리 없이 Scaffold의 resizeToAvoidBottomInset(기본 true)에 맡긴다.
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (leadingIcon != null) ...[
                  IconButton(
                    onPressed: enabled ? onLeadingTap : null,
                    icon: Icon(
                      leadingIcon,
                      color: enabled
                          ? typeStyle.primaryColor
                          : AppColors.textHint,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Expanded(
                  child: TextField(
                    controller: controller,
                    enabled: enabled,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    decoration: InputDecoration(
                      hintText:
                          hintText ??
                          (enabled ? '메시지를 입력하세요' : 'AI가 답변하고 있어요...'),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.sm,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: enabled
                        ? typeStyle.primaryColor
                        : AppColors.textHint,
                  ),
                  child: IconButton(
                    onPressed: enabled ? onSend : null,
                    icon: const Icon(
                      Icons.send_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            if (trailingAction != null) trailingAction!,
          ],
        ),
      ),
    );
  }
}
