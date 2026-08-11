import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/wish_room_providers.dart';
import '../theme/wish_room_theme.dart';
import '../widgets/fortune_pouch_status_card.dart';
import '../widgets/growth_progress_card.dart';
import '../widgets/prayer_streak_badge.dart';
import '../widgets/wish_room_animations.dart';
import '../widgets/wish_room_background.dart';
import 'wish_customize_screen.dart';
import 'wish_history_screen.dart';
import 'wish_slot_unlock_screen.dart';

/// [대형 작업 — 신전관리 허브] 사용자 지시("있는 기능은 페이지 한칸을 더
/// 만들어서 구현 다시 구현")에 따라, 기존에 메인 화면(Home)에 있던 게임성
/// 기능(성장 진행률/복주머니 현황/연속 기도/소원 기록/방 꾸미기/소원 자리
/// 넓히기)을 삭제하지 않고 이 별도 탭으로 모아 그대로 접근할 수 있게 한다.
///
/// [기존 화면 재사용] `wish_history_screen.dart`/`wish_customize_screen.dart`/
/// `wish_slot_unlock_screen.dart`는 이미 완성되어 있고 새 디자인(크리스탈
/// 팔레트 + WishRoomBackground + DramaticEntrance)이 적용된 상태이므로,
/// 이 허브는 그 화면들로의 진입점(카드형 메뉴)만 제공하고 화면 자체는 그대로
/// push해서 재사용한다 — 로직/UI를 다시 작성하지 않는다.
///
/// [상태 카드 재사용] 성장 진행률(GrowthProgressCard)/복주머니 현황
/// (FortunePouchStatusCard)/연속 기도(PrayerStreakBadge)는 기존
/// wish_room_screen.dart Home에서 쓰던 것과 동일한 위젯을 그대로 가져와
/// 이 허브 상단에 요약으로 보여준다.
class WishRoomTempleManagementScreen extends ConsumerWidget {
  const WishRoomTempleManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(wishRoomControllerProvider);

    return Scaffold(
      backgroundColor: WishRoomColors.backgroundDeep,
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(
              child: WishRoomBackground(mainSigilOpacity: 0.16),
            ),
            asyncData.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: WishRoomColors.gold),
              ),
              error: (err, st) => Center(
                child: Text('잠시 후 다시 시도해주세요', style: WishRoomTextStyles.bodyMd),
              ),
              data: (data) {
                final representativeWish = data.room.representativeWish;
                return DramaticEntrance(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      WishRoomSpacing.md,
                      WishRoomSpacing.lg,
                      WishRoomSpacing.md,
                      WishRoomSpacing.xxl,
                    ),
                    children: [
                      Text('◈', style: TextStyle(fontSize: 28, color: WishRoomColors.glow)),
                      const SizedBox(height: WishRoomSpacing.sm),
                      Text('신전관리', style: WishRoomTextStyles.screenTitle),
                      const SizedBox(height: WishRoomSpacing.xs),
                      Text(
                        '소원의 성장과 방을 관리하는 곳이에요',
                        style: WishRoomTextStyles.bodySm,
                      ),
                      const SizedBox(height: WishRoomSpacing.lg),
                      if (representativeWish != null) ...[
                        GrowthProgressCard(wish: representativeWish),
                        const SizedBox(height: WishRoomSpacing.md),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: FortunePouchStatusCard(status: data.pouchStatus),
                          ),
                          const SizedBox(width: WishRoomSpacing.sm),
                          Expanded(
                            child: PrayerStreakBadge(
                              consecutivePrayerDays: data.room.consecutivePrayerDays,
                              totalPrayerCount: data.room.totalPrayerCount,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: WishRoomSpacing.lg),
                      _MenuTile(
                        emoji: '📜',
                        title: '내 소원 보기',
                        subtitle: '지금까지 빌었던 소원들을 모아봐요',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const WishHistoryScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(height: WishRoomSpacing.sm),
                      _MenuTile(
                        emoji: '🎨',
                        title: '방 꾸미기',
                        subtitle: '소원방을 나만의 공간으로 꾸며보아요',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const WishCustomizeScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(height: WishRoomSpacing.sm),
                      _MenuTile(
                        emoji: '🔓',
                        title: '소원 자리 넓히기',
                        subtitle: '연속 방문 또는 복주머니로 자리를 늘려요',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const WishSlotUnlockScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuTile({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TapBounce(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(WishRoomSpacing.md),
        decoration: BoxDecoration(
          color: WishRoomColors.surfaceCard,
          borderRadius: BorderRadius.circular(WishRoomRadius.md),
          border: Border.all(color: WishRoomColors.surfaceCardBorder),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: WishRoomSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: WishRoomTextStyles.bodyMd.copyWith(
                      color: WishRoomColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: WishRoomTextStyles.caption),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: WishRoomColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
