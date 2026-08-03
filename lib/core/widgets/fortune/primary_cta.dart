import 'package:flutter/material.dart';
import '../../theme/app_unified_style.dart';

/// 재사용 위젯 ⑧ PrimaryCTA — 진입/입력 화면 하단 고정 CTA(블랙 pill).
/// 배경 #111111, radius24, height48. disabled 시 옅게 처리.
class PrimaryCTA extends StatelessWidget {
  const PrimaryCTA({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 48,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return SizedBox(
      width: double.infinity,
      height: height,
      child: Material(
        color: enabled
            ? UnifiedColors.black
            : UnifiedColors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
        child: InkWell(
          borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
          onTap: onPressed,
          child: Center(
            child: Text(
              label,
              style: UnifiedText.bodyStrong(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
