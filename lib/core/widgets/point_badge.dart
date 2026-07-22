import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// 03단계 §3.2 전역 내비게이션 보조요소 - 포인트 잔액 요약 칩
/// "포인트 잔액은 거의 모든 화면 상단에 상시 노출"
class PointBadge extends StatelessWidget {
  final int balance;
  final VoidCallback? onTap;

  const PointBadge({super.key, required this.balance, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
        decoration: BoxDecoration(
          gradient: AppColors.goldGradient,
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome, size: 14, color: AppColors.textPrimary),
            const SizedBox(width: 4),
            Text(
              _formatBalance(balance),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatBalance(int value) {
    if (value >= 10000) {
      return '${(value / 10000).toStringAsFixed(1)}만';
    }
    final str = value.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write(',');
      buffer.write(str[i]);
    }
    return buffer.toString();
  }
}
