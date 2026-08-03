import 'package:flutter/material.dart';
import '../../../../core/theme/app_unified_style.dart';
import '../../../../core/widgets/premium_card.dart';

/// [소원방 MVP §10 소원의 빛 게이지] "소원의 빛 42%" 형태로 표시하며,
/// 값이 바뀔 때마다 부드럽게(500ms easeOut) 채워지는 애니메이션을 갖는다.
class WishRoomLightGauge extends StatelessWidget {
  const WishRoomLightGauge({super.key, required this.percent});

  /// 0~100.
  final double percent;

  String get _levelLabel {
    if (percent < 34) return '이제 막 피어나는 빛이에요';
    if (percent < 70) return '꾸준히 자라고 있어요';
    return '아주 환하게 빛나고 있어요';
  }

  @override
  Widget build(BuildContext context) {
    final clamped = percent.clamp(0, 100).toDouble();

    return PremiumCard(
      backgroundColor: UnifiedColors.cardSection,
      borderColor: Colors.transparent,
      showShadow: false,
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
      padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.local_fire_department_outlined,
                size: UnifiedTokens.iconMd,
                color: UnifiedColors.textSecondary,
              ),
              const SizedBox(width: UnifiedTokens.spaceSm),
              Text('소원의 빛', style: UnifiedText.title()),
              const Spacer(),
              Text(
                '${clamped.toStringAsFixed(0)}%',
                style: UnifiedText.bodyStrong(),
              ),
            ],
          ),
          const SizedBox(height: UnifiedTokens.spaceMd),
          ClipRRect(
            borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
            child: Container(
              height: 10,
              color: UnifiedColors.chipInactiveBg,
              child: Align(
                alignment: Alignment.centerLeft,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: clamped / 100),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOut,
                  builder: (context, value, _) => FractionallySizedBox(
                    widthFactor: value,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          UnifiedTokens.radiusPill,
                        ),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFD8CFF3), Color(0xFFE9C989)],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: UnifiedTokens.spaceSm),
          Text(_levelLabel, style: UnifiedText.caption()),
        ],
      ),
    );
  }
}
