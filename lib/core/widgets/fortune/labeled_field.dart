import 'package:flutter/material.dart';
import '../../theme/app_unified_style.dart';

/// 재사용 위젯 ⑩ LabeledField — 정보입력 화면 "라벨 + 인풋" 공통 구조.
///
/// 라벨: Caption12 #6B6B75. 유효성 오류는 인풋 아래 Caption으로 조용히 표시.
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.child,
    this.errorText,
  });

  final String label;
  final Widget child;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: UnifiedText.caption()),
        const SizedBox(height: 6),
        child,
        if (errorText != null) ...[
          const SizedBox(height: 4),
          Text(errorText!, style: UnifiedText.caption()),
        ],
      ],
    );
  }
}

/// 인풋 공통 박스 — 배경 #FFFFFF, radius12, 테두리 #ECECEF 1px.
/// TextField/선택형(날짜·성별·시간·양음력) 모두 이 컨테이너로 통일한다.
class FieldInputBox extends StatelessWidget {
  const FieldInputBox({
    super.key,
    required this.child,
    this.onTap,
    this.height = 44,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: UnifiedTokens.spaceMd),
      decoration: BoxDecoration(
        color: UnifiedColors.bg,
        borderRadius: BorderRadius.circular(UnifiedTokens.radiusSm),
        border: Border.all(color: UnifiedColors.border, width: 1),
      ),
      alignment: Alignment.centerLeft,
      child: child,
    );
    if (onTap == null) return box;
    return InkWell(
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusSm),
      onTap: onTap,
      child: box,
    );
  }
}

/// 선택형 필드용 칩(성별/양음력/모름 등)에 재사용하는 작은 토글 버튼.
class FieldChoiceChip extends StatelessWidget {
  const FieldChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusSm),
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: UnifiedTokens.spaceMd),
        decoration: BoxDecoration(
          color: selected ? UnifiedColors.black : UnifiedColors.bg,
          borderRadius: BorderRadius.circular(UnifiedTokens.radiusSm),
          border: Border.all(
            color: selected ? UnifiedColors.black : UnifiedColors.border,
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: UnifiedText.body(
            color: selected ? Colors.white : UnifiedColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
