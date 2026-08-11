import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/wish_item_model.dart';
import '../../domain/enums/prayer_type.dart';
import '../controllers/wish_room_controller.dart';
import '../providers/wish_room_providers.dart';
import '../state/wish_room_ui_state.dart';
import '../theme/wish_room_theme.dart';
import '../widgets/prayer_complete_sheet.dart';
import '../widgets/prayer_type_sheet.dart';
import 'wish_slot_unlock_screen.dart';
import 'wish_write_screen.dart';

/// [디자인 핸드오프 8개 화면 재구현] 치성/소원 작성 흐름 공용 헬퍼.
///
/// 기존 `wish_room_screen.dart`(삭제된 구 Home 화면) 안에 인스턴스 메서드로
/// 있던 `_openWriteScreen`/`_startPrayerFlow`/`_handleWishCardTap`/
/// `_handleWakeTap` 로직을 화면 독립적인 static 메서드로 그대로 옮겼다 —
/// 로직/분기/애니메이션 트리거/analytics 호출은 100% 동일하게 유지하고,
/// 이제 새 Home/Detail/신전관리 화면 여러 곳에서 재사용할 수 있게 했다.
class WishRoomPrayerFlow {
  const WishRoomPrayerFlow._();

  static Future<void> openWriteScreen(BuildContext context, WidgetRef ref) async {
    if (ref.read(wishRoomUiProvider).step != WishRoomFlowStep.home) return;

    final uiController = ref.read(wishRoomUiProvider.notifier);
    final controller = ref.read(wishRoomControllerProvider.notifier);
    if (!controller.hasAvailableSlot) {
      uiController.goTo(WishRoomFlowStep.unlockingSlot);
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const WishSlotUnlockScreen()));
      if (context.mounted) uiController.goTo(WishRoomFlowStep.home);
      return;
    }
    uiController.goTo(WishRoomFlowStep.writingWish);
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const WishWriteScreen()));
    if (context.mounted) uiController.goTo(WishRoomFlowStep.home);
  }

  static Future<void> handleWishCardTap(
    BuildContext context,
    WidgetRef ref,
    WishRoomController controller,
    WishItem wish,
  ) async {
    if (wish.isRepresentative) {
      await startPrayerFlow(context, ref, controller);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: WishRoomColors.backgroundMid,
        title: Text('대표 소원을 바꿀까요?', style: WishRoomTextStyles.titleLg),
        content: Text(
          '"${wish.title}"을 대표 소원으로 설정하면\n'
          '메인 오브제와 정성 진행률이 이 소원을 기준으로 바뀌어요',
          style: WishRoomTextStyles.bodySm,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              '취소',
              style: WishRoomTextStyles.bodySm.copyWith(
                color: WishRoomColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              '대표로 설정',
              style: WishRoomTextStyles.bodySm.copyWith(
                color: WishRoomColors.gold,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final success = await controller.setRepresentative(wish.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? '"${wish.title}"이 대표 소원이 되었어요' : '대표 소원 변경에 실패했어요',
        ),
      ),
    );
  }

  static Future<void> startPrayerFlow(
    BuildContext context,
    WidgetRef ref,
    WishRoomController controller, {
    WishItem? forWish,
  }) async {
    if (ref.read(wishRoomUiProvider).step != WishRoomFlowStep.home) return;

    final data = ref.read(wishRoomControllerProvider).valueOrNull;
    if (data == null) return;
    final wish = forWish ?? data.room.representativeWish;
    if (wish == null) {
      await openWriteScreen(context, ref);
      return;
    }

    final uiController = ref.read(wishRoomUiProvider.notifier);
    uiController.goTo(WishRoomFlowStep.praying);
    final selectedType = await PrayerTypeSheet.show(
      context,
      wish: wish,
      pouchStatus: data.pouchStatus,
      hasPrayedToday: data.room.hasPrayedToday,
    );
    if (selectedType == null || !context.mounted) {
      uiController.goTo(WishRoomFlowStep.home);
      return;
    }

    final stageBefore = wish.growthStage;
    final beforeCanUnlockSlot = data.room.canUnlockNextSlotByStreak;
    final success = await controller.prayForWish(
      wishId: wish.id,
      type: selectedType,
    );
    if (!context.mounted) return;

    if (success) {
      final updated = ref.read(wishRoomControllerProvider).valueOrNull;
      final WishItem? updatedWish = updated?.room.wishes
          .where((w) => w.id == wish.id)
          .cast<WishItem?>()
          .firstWhere((w) => w != null, orElse: () => null);
      final bool didLevelUp =
          updatedWish != null && updatedWish.growthStage != stageBefore;
      final String? newStageLabel = didLevelUp
          ? updatedWish.growthStage.label
          : null;
      final bool afterCanUnlockSlot =
          updated?.room.canUnlockNextSlotByStreak ?? false;
      final bool didUnlockNewSlot = !beforeCanUnlockSlot && afterCanUnlockSlot;

      if (didUnlockNewSlot) {
        uiController.goTo(WishRoomFlowStep.revisitCelebration);
        uiController.triggerAnimation(WishRoomAnimationEvent.streakLevelUp);
      } else if (didLevelUp) {
        uiController.goTo(WishRoomFlowStep.prayerCompleted);
        uiController.triggerAnimation(WishRoomAnimationEvent.growthStageUp);
      } else {
        uiController.goTo(WishRoomFlowStep.prayerCompleted);
        uiController.triggerAnimation(WishRoomAnimationEvent.prayerBurst);
      }

      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => PrayerCompleteSheet(
          pouchUsed: selectedType.pouchCost,
          consecutivePrayerDays: updated?.room.consecutivePrayerDays ?? 1,
          didLevelUp: didLevelUp,
          newStageLabel: newStageLabel,
          didUnlockNewSlot: didUnlockNewSlot,
        ),
      );
      if (context.mounted) uiController.goTo(WishRoomFlowStep.home);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('복주머니가 부족해요. 상점에서 채워보세요.')));
      uiController.goTo(WishRoomFlowStep.home);
    }
  }

  static Future<bool> handleWakeTap(
    BuildContext context,
    WishRoomController controller,
    WishItem wish,
  ) async {
    final success = await controller.wakeWish(wish.id);
    if (!context.mounted) return success;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? '소원이 다시 밝게 빛나요 🌟 (+2 복주머니)' : '아직 깨울 필요가 없어요.',
        ),
      ),
    );
    return success;
  }
}
