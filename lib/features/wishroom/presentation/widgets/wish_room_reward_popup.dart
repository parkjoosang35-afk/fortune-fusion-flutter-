import 'package:flutter/material.dart';
import '../../../../core/theme/app_unified_style.dart';
import '../../../../core/widgets/fortune/primary_cta.dart';
import '../../domain/wish_room_model.dart';

/// [소원방 MVP §12/§13] 치성 완료 보상 팝업.
/// "왜 받았는지, 얼마나 받았는지, 무엇이 올랐는지 명확히 보이게 한다"를
/// 만족하도록 3개 보상 라인을 숫자 카운트업 애니메이션과 함께 보여준다.
class WishRoomRewardPopup extends StatelessWidget {
  const WishRoomRewardPopup({super.key, required this.result});

  final RitualRewardResult result;

  static const _blessings = [
    '오늘도 당신의 정성이 소원에 닿았습니다',
    '당신의 마음이 조용히 빛나고 있어요',
    '오늘의 소원에 따뜻한 빛이 더해졌어요',
  ];

  String get _blessing => _blessings[result.streakAfter % _blessings.length];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: UnifiedColors.bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(UnifiedTokens.spaceXxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.4, end: 1.0),
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: Row(
                children: [
                  Container(
                    width: UnifiedTokens.iconCircleLg,
                    height: UnifiedTokens.iconCircleLg,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: UnifiedColors.cardMain,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.volunteer_activism_outlined,
                      size: UnifiedTokens.iconLg,
                      color: UnifiedColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: UnifiedTokens.spaceMd),
                  Expanded(
                    child: Text('오늘의 치성 보상', style: UnifiedText.titleLarge()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: UnifiedTokens.spaceLg),
            _RewardLine(
              icon: Icons.shopping_bag_outlined,
              label: '복주머니',
              value: result.luckPouch,
              suffix: '',
            ),
            const SizedBox(height: UnifiedTokens.spaceSm),
            _RewardLine(
              icon: Icons.auto_awesome_outlined,
              label: '치성 경험치',
              value: result.exp,
              suffix: '',
            ),
            const SizedBox(height: UnifiedTokens.spaceSm),
            _RewardLine(
              icon: Icons.local_fire_department_outlined,
              label: '소원의 빛',
              value: result.lightIncrease.round(),
              suffix: '%',
            ),
            const SizedBox(height: UnifiedTokens.spaceLg),
            Text(_blessing, style: UnifiedText.body()),
            const SizedBox(height: UnifiedTokens.spaceXs),
            Text('오늘도 감사합니다', style: UnifiedText.caption()),
            const SizedBox(height: UnifiedTokens.spaceXxl),
            PrimaryCTA(
              label: '확인',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardLine extends StatelessWidget {
  const _RewardLine({
    required this.icon,
    required this.label,
    required this.value,
    required this.suffix,
  });

  final IconData icon;
  final String label;
  final int value;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: UnifiedTokens.iconMd, color: UnifiedColors.textSecondary),
        const SizedBox(width: UnifiedTokens.spaceSm),
        Expanded(child: Text(label, style: UnifiedText.body())),
        TweenAnimationBuilder<int>(
          tween: IntTween(begin: 0, end: value),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOut,
          builder: (context, animatedValue, _) => Text(
            '+$animatedValue$suffix',
            style: UnifiedText.bodyStrong(),
          ),
        ),
      ],
    );
  }
}
