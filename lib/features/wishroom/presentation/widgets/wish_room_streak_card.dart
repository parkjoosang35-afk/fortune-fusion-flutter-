import 'package:flutter/material.dart';
import '../../../../core/theme/app_unified_style.dart';
import '../../../../core/widgets/premium_card.dart';

/// [소원방 MVP §11 연속 치성 시스템] "압박감보다 꾸준함의 성취감을 준다"
/// 원칙에 따라, 숫자 강조 + 7일 주기 도트 트래커로 담백하게 보여준다.
class WishRoomStreakCard extends StatelessWidget {
  const WishRoomStreakCard({super.key, required this.streakDays});

  final int streakDays;

  String get _caption {
    if (streakDays <= 0) return '오늘 첫 치성으로 시작해보세요';
    if (streakDays % 7 == 0) return '한 주를 꽉 채웠어요, 정말 대단해요';
    return '오늘도 이어가고 싶은 마음, 그 자체가 정성이에요';
  }

  @override
  Widget build(BuildContext context) {
    // 현재 주기(streakDays를 7로 나눈 나머지, 0이면 방금 7일을 채운 상태로
    // 7개 모두 채워진 것으로 표시)의 도트 채움 개수.
    final filledDots = streakDays <= 0
        ? 0
        : (streakDays % 7 == 0 ? 7 : streakDays % 7);

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
                Icons.auto_awesome_outlined,
                size: UnifiedTokens.iconMd,
                color: UnifiedColors.textSecondary,
              ),
              const SizedBox(width: UnifiedTokens.spaceSm),
              Text('연속 치성', style: UnifiedText.title()),
              const Spacer(),
              Text(
                streakDays <= 0 ? '0일' : '$streakDays일 연속',
                style: UnifiedText.bodyStrong(),
              ),
            ],
          ),
          const SizedBox(height: UnifiedTokens.spaceMd),
          Row(
            children: List.generate(7, (i) {
              final filled = i < filledDots;
              return Padding(
                padding: const EdgeInsets.only(right: UnifiedTokens.spaceSm),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled
                        ? UnifiedColors.textPrimary
                        : UnifiedColors.bg,
                    border: Border.all(
                      color: filled
                          ? UnifiedColors.textPrimary
                          : UnifiedColors.border,
                      width: 1.2,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: UnifiedTokens.spaceSm),
          Text(_caption, style: UnifiedText.caption()),
        ],
      ),
    );
  }
}
