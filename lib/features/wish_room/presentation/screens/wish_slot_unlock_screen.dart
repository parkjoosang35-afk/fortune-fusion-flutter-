import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/enums/wish_slot_status.dart';
import '../providers/wish_room_providers.dart';
import '../state/wish_room_ui_state.dart';
import '../theme/wish_room_theme.dart';

/// [필수 화면 ⑨ 슬롯 확장 또는 보상 해금 화면]
///
/// 화면 목적: 대표 슬롯 1개 + 서브 슬롯 2개의 현재 상태(대표/보조/빈자리/
/// 잠김)를 한눈에 보여주고, 잠긴 서브 슬롯을 스트릭 무료 해금 또는
/// 복주머니 즉시 해금으로 열 수 있게 한다(정책표 ① 참고).
class WishSlotUnlockScreen extends ConsumerWidget {
  const WishSlotUnlockScreen({super.key});

  Future<void> _unlock(
    BuildContext context,
    WidgetRef ref, {
    required bool viaPouch,
  }) async {
    final controller = ref.read(wishRoomControllerProvider.notifier);
    final success = await controller.unlockSubSlot(viaPouch: viaPouch);
    if (!context.mounted) return;
    if (success) {
      // [애니메이션 이벤트 소비] slotUnlocked 신호를 올려둔다. 이 화면은
      // 곧바로 pop()되므로 실제 소비(스낵바 표시 + clearAnimation 호출)는
      // 메인 화면(WishRoomScreen)의 ref.listen이 담당한다 — 이 화면이
      // 사라진 뒤에도 메인 화면은 계속 마운트되어 있으므로 신호를 놓치지
      // 않는다(설계 문서 ㉔-3 참고).
      ref
          .read(wishRoomUiProvider.notifier)
          .triggerAnimation(WishRoomAnimationEvent.slotUnlocked);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('새로운 자리가 열렸어요. 소원을 채워보세요')));
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('복주머니가 부족해요')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(wishRoomControllerProvider);
    final canUnlockByStreak = ref.watch(canUnlockSlotByStreakProvider);

    return Scaffold(
      backgroundColor: WishRoomColors.backgroundDeep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('소원 자리 넓히기', style: WishRoomTextStyles.titleLg),
        iconTheme: const IconThemeData(color: WishRoomColors.textPrimary),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: WishRoomColors.backgroundGradient,
        ),
        child: SafeArea(
          top: false,
          child: asyncData.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: WishRoomColors.gold),
            ),
            error: (err, st) => Center(
              child: Text('잠시 후 다시 시도해주세요', style: WishRoomTextStyles.bodyMd),
            ),
            data: (data) {
              final statuses = data.room.slotStatuses;
              final allUnlocked = data.room.unlockedSubSlotCount >= 2;

              return Padding(
                padding: const EdgeInsets.all(WishRoomSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '이 방에는 소원을 담을\n자리가 세 곳 있어요',
                      style: WishRoomTextStyles.titleLg,
                    ),
                    const SizedBox(height: WishRoomSpacing.lg),
                    Row(
                      children: statuses
                          .map(
                            (status) => Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: WishRoomSpacing.xs,
                                ),
                                child: _SlotTile(status: status),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: WishRoomSpacing.xl),
                    if (allUnlocked)
                      Text(
                        '모든 자리가 열렸어요.\n이제 세 가지 소원을 함께 키워보세요',
                        style: WishRoomTextStyles.bodyMd,
                        textAlign: TextAlign.center,
                      )
                    else ...[
                      if (canUnlockByStreak)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: WishRoomColors.gold,
                              padding: const EdgeInsets.symmetric(
                                vertical: WishRoomSpacing.md,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  WishRoomRadius.pill,
                                ),
                              ),
                            ),
                            onPressed: () =>
                                _unlock(context, ref, viaPouch: false),
                            child: Text(
                              '무료로 자리 열기 (연속 방문 보상)',
                              style: WishRoomTextStyles.ctaLabel,
                            ),
                          ),
                        )
                      else
                        Text(
                          '연속 ${data.room.unlockedSubSlotCount == 0 ? 3 : 7}일 방문하면 '
                          '무료로 자리가 열려요 (현재 ${data.room.consecutivePrayerDays}일째)',
                          style: WishRoomTextStyles.caption,
                        ),
                      const SizedBox(height: WishRoomSpacing.sm),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: WishRoomColors.surfaceCardBorder,
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: WishRoomSpacing.md,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                WishRoomRadius.pill,
                              ),
                            ),
                          ),
                          onPressed: () =>
                              _unlock(context, ref, viaPouch: true),
                          child: Text(
                            '복주머니 30개로 바로 열기',
                            style: WishRoomTextStyles.bodyMd.copyWith(
                              color: WishRoomColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SlotTile extends StatelessWidget {
  final WishSlotStatus status;

  const _SlotTile({required this.status});

  @override
  Widget build(BuildContext context) {
    final isLocked = status.isLocked;
    return Container(
      height: 96,
      decoration: BoxDecoration(
        color: WishRoomColors.surfaceCard,
        borderRadius: BorderRadius.circular(WishRoomRadius.md),
        border: Border.all(
          color: status == WishSlotStatus.representative
              ? WishRoomColors.gold
              : WishRoomColors.surfaceCardBorder,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isLocked
                  ? Icons.lock_outline
                  : Icons.local_fire_department_outlined,
              color: isLocked
                  ? WishRoomColors.textTertiary
                  : WishRoomColors.goldSoft,
              size: 28,
            ),
            const SizedBox(height: WishRoomSpacing.xs),
            Text(status.label, style: WishRoomTextStyles.caption),
          ],
        ),
      ),
    );
  }
}
