import 'package:flutter/material.dart';
import '../../../../core/theme/app_unified_style.dart';
import '../../../../core/widgets/premium_card.dart';
import 'wish_room_flame_widget.dart';

/// [소원방 MVP §7/§8] "항상 살아 있는 제단"처럼 보이는 메인 비주얼 영역.
/// 메인 카피 + 오늘의 치성 상태 문구까지 포함한다(§7 구성 2·3번을 하나의
/// 시각 블록으로 묶어, 화면이 산만한 리스트가 아니라 "제단 앞에 서 있는"
/// 느낌을 준다).
class WishRoomShrineView extends StatelessWidget {
  const WishRoomShrineView({
    super.key,
    required this.ritualDoneToday,
  });

  final bool ritualDoneToday;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      backgroundColor: UnifiedColors.cardMain,
      borderColor: Colors.transparent,
      showShadow: false,
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
      padding: const EdgeInsets.symmetric(
        vertical: UnifiedTokens.spaceXxl,
        horizontal: UnifiedTokens.spaceLg,
      ),
      child: Column(
        children: [
          // 촛불은 오늘 치성을 마쳤을 때만 "완료(성화)" 강도로, 그 전에는
          // 항상 은은한 기본 강도로 켜져 있다(0으로 절대 내려가지 않음).
          WishRoomFlameWidget(
            intensity: ritualDoneToday ? 1.0 : 0.32,
            size: 128,
          ),
          const SizedBox(height: UnifiedTokens.spaceLg),
          Text(
            ritualDoneToday
                ? '매일의 마음이 소원의 빛이 됩니다'
                : '오늘도 당신의 정성을 기다리고 있어요',
            style: UnifiedText.titleLarge(),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: UnifiedTokens.spaceXs),
          Text(
            ritualDoneToday ? '오늘의 치성을 완료했어요' : '아직 치성을 드리지 않았어요',
            style: UnifiedText.body(),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
