import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// 03단계 §3.2 전역 내비게이션 보조요소 - 복주머니 잔액 요약 칩
/// "복주머니 잔액은 거의 모든 화면 상단에 상시 노출"
///
/// [Fortune Fusion UI 리뉴얼 프롬프트] §2-2 PointBadge 스타일 개선.
/// 🍀 이모지 아이콘 + accentGold 15% 오파시티 pill 배경으로 우주 감성 톤에 맞춘다.
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
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.accentGold.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🍀', style: TextStyle(fontSize: 14)),
            const SizedBox(width: AppSpacing.xs),
            Text(
              _formatBalance(balance),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.accentGold,
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
