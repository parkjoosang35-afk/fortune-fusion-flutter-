import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/wish_item_model.dart';
import '../../domain/enums/prayer_type.dart';
import '../controllers/wish_room_controller.dart';
import '../providers/wish_room_providers.dart';
import '../state/wish_room_ui_state.dart';
import '../theme/wish_room_theme.dart';
import '../widgets/daily_message_card.dart';
import '../widgets/fortune_pouch_status_card.dart';
import '../widgets/growth_progress_card.dart';
import '../widgets/prayer_complete_sheet.dart';
import '../widgets/prayer_streak_badge.dart';
import '../widgets/prayer_type_sheet.dart';
import '../widgets/wish_card_list.dart';
import '../widgets/wish_guide_dialog.dart';
import '../widgets/wish_room_background.dart';
import '../widgets/wish_room_header.dart';
import '../widgets/wish_room_object.dart';
import 'wish_customize_screen.dart';
import 'wish_history_screen.dart';
import 'wish_slot_unlock_screen.dart';
import 'wish_write_screen.dart';

/// [필수 화면 ② 소원방 메인 화면]
///
/// 위젯 트리:
/// Scaffold > SafeArea > Stack(Background, CustomScrollView(Header, Object,
/// DailyMessage, WishCardList, GrowthProgressCard, StatusCards, CTAButtons))
class WishRoomScreen extends ConsumerWidget {
  const WishRoomScreen({super.key});

  Future<void> _openWriteScreen(BuildContext context, WidgetRef ref) async {
    // [흐름 상태 가드] WishRoomFlowStep을 실제로 읽어서 이미 다른 흐름이
    // 진행 중이면(연속 탭 등) 중복 push를 막는다.
    if (ref.read(wishRoomUiProvider).step != WishRoomFlowStep.home) return;

    final uiController = ref.read(wishRoomUiProvider.notifier);
    final controller = ref.read(wishRoomControllerProvider.notifier);
    if (!controller.hasAvailableSlot) {
      // [슬롯 시스템] 빈 슬롯이 없으면 작성 화면 대신 슬롯 확장 화면으로 보낸다.
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

  Future<void> _openHistoryScreen(BuildContext context) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const WishHistoryScreen()));
  }

  Future<void> _openCustomizeScreen(BuildContext context, WidgetRef ref) async {
    // [흐름 상태 가드] 연속 탭으로 화면이 중복 push되는 것을 막는다.
    if (ref.read(wishRoomUiProvider).step != WishRoomFlowStep.home) return;
    final uiController = ref.read(wishRoomUiProvider.notifier);
    uiController.goTo(WishRoomFlowStep.customizing);
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const WishCustomizeScreen()));
    if (context.mounted) uiController.goTo(WishRoomFlowStep.home);
  }

  /// [슬롯 시스템] 소원 카드를 탭했을 때의 분기 처리.
  /// - 탭한 소원이 이미 대표 소원이면: 바로 치성 흐름 시작(기존 동작 유지).
  /// - 탭한 소원이 서브 소원이면: "이 소원을 대표로 바꿀까요?" 확인 다이얼로그
  ///   를 띄우고, 확정 시 [WishRoomController.setRepresentative]를 호출한다
  ///   (정책표 ① "대표 소원 교체" 참고). 취소하면 아무 것도 하지 않는다.
  Future<void> _handleWishCardTap(
    BuildContext context,
    WidgetRef ref,
    WishRoomController controller,
    WishItem wish,
  ) async {
    if (wish.isRepresentative) {
      await _startPrayerFlow(context, ref, controller);
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

  /// [치성 시스템] 치성 종류 선택 → 실행 → 완료 연출까지 이어지는 흐름.
  /// 대표 소원이 없으면(빈 상태) 먼저 소원 작성으로 유도한다.
  ///
  /// [재방문 축하 연출] 이번 치성으로 연속 방문일수가 슬롯 해금 조건(3일/
  /// 7일)에 새로 도달했다면(`beforeCanUnlock`이 false → `afterCanUnlock`이
  /// true로 전환) `WishRoomFlowStep.revisitCelebration`으로 잠시 전환하고
  /// `streakLevelUp` 애니메이션 신호를 올린 뒤, 완료 시트에 "새 자리가
  /// 열렸어요" 배너를 함께 노출한다(정책표 ① + ⑩ 참고).
  Future<void> _startPrayerFlow(
    BuildContext context,
    WidgetRef ref,
    WishRoomController controller,
  ) async {
    // [흐름 상태 가드] 이미 다른 흐름이 진행 중이면(예: 바텀시트가 뜬 상태에서
    // CTA를 다시 탭) 중복 실행을 막는다.
    if (ref.read(wishRoomUiProvider).step != WishRoomFlowStep.home) return;

    final data = ref.read(wishRoomControllerProvider).valueOrNull;
    if (data == null) return;
    final wish = data.room.representativeWish;
    if (wish == null) {
      await _openWriteScreen(context, ref);
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
      final WishItem? updatedWish = updated?.room.wishes.firstOrNull(
        (w) => w.id == wish.id,
      );
      final bool didLevelUp =
          updatedWish != null && updatedWish.growthStage != stageBefore;
      final String? newStageLabel = didLevelUp
          ? updatedWish.growthStage.label
          : null;
      final bool afterCanUnlockSlot =
          updated?.room.canUnlockNextSlotByStreak ?? false;
      final bool didUnlockNewSlot = !beforeCanUnlockSlot && afterCanUnlockSlot;

      // [애니메이션 이벤트 소비] pendingAnimationEvent는 스칼라(단일 값)라
      // 한 번에 하나만 표시할 수 있다. 우선순위: 슬롯 해금 마일스톤
      // (streakLevelUp) > 성장 단계 상승(growthStageUp) > 일반 치성 완료
      // (prayerBurst). 예전에는 streakLevelUp을 트리거한 직후 곧바로
      // prayerBurst를 또 트리거해 같은 프레임에서 streakLevelUp이 바로
      // 덮여 써져 어떤 위젯도 실제로 그 신호를 보지 못하는 문제가 있었다
      // (설계 문서 ㉔-3 참고) — 이제는 상황별로 딱 하나만 트리거한다.
      if (didUnlockNewSlot) {
        // [재방문 축하 연출] 슬롯 해금 자격이 막 열린 순간 — 일반 치성
        // 완료보다 한 단계 위의 마일스톤이므로 별도 flow step으로 표시한다.
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(wishRoomControllerProvider);
    // [애니메이션 이벤트 소비] 오브제가 재생해야 할 1회성 신호. 오브제가
    // 재생을 끝내면 onAnimationConsumed 콜백에서 clearAnimation()을 호출해
    // 이 값을 비운다(중복 재생 방지).
    final pendingAnimationEvent = ref.watch(
      wishRoomUiProvider.select((s) => s.pendingAnimationEvent),
    );

    // 최초 진입 시 가이드 팝업(초회 1회) 노출.
    ref.listen(wishRoomControllerProvider, (previous, next) {
      final data = next.valueOrNull;
      if (data != null && data.isFirstVisit && previous?.valueOrNull == null) {
        Future.microtask(() {
          if (context.mounted) {
            WishGuideDialog.show(context).then((_) {
              ref.read(wishRoomControllerProvider.notifier).markGuideSeen();
            });
          }
        });
      }
    });

    // [애니메이션 이벤트 소비] streakLevelUp(슬롯 해금 마일스톤)과
    // slotUnlocked(슬롯 확장 화면에서 즉시 해금)는 메인 오브제가 아니라
    // 이 화면 레벨의 축하 스낵바로 소비한다(WishRoomObject는 objectTouch/
    // prayerBurst/growthStageUp만 담당 — wish_room_object.dart 클래스 doc
    // 참고). 이 화면은 다른 화면이 push되어 있는 동안에도 offstage 라우트로
    // 계속 마운트되어 있으므로 신호를 놓치지 않는다.
    ref.listen(wishRoomUiProvider.select((s) => s.pendingAnimationEvent), (
      previous,
      next,
    ) {
      if (next == WishRoomAnimationEvent.streakLevelUp ||
          next == WishRoomAnimationEvent.slotUnlocked) {
        final message = next == WishRoomAnimationEvent.streakLevelUp
            ? '연속 방문 보상으로 새 자리가 열렸어요! \ud83c\udf89'
            : '소원 자리가 새로 열렸어요! \ud83c\udf89';
        ref.read(wishRoomUiProvider.notifier).clearAnimation();
        Future.microtask(() {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: WishRoomColors.gold,
              ),
            );
          }
        });
      }
    });

    return Scaffold(
      backgroundColor: WishRoomColors.backgroundDeep,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: WishRoomBackground(
                sparkleLevel:
                    asyncData.valueOrNull?.visualState.backgroundSparkleLevel ??
                    0.3,
              ),
            ),
            asyncData.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: WishRoomColors.gold),
              ),
              error: (err, st) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(WishRoomSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('잠시 후 다시 시도해주세요', style: WishRoomTextStyles.bodyMd),
                      const SizedBox(height: WishRoomSpacing.md),
                      ElevatedButton(
                        onPressed: () =>
                            ref.invalidate(wishRoomControllerProvider),
                        child: const Text('다시 시도'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (data) {
                final controller = ref.read(
                  wishRoomControllerProvider.notifier,
                );
                final representativeWishes = data.room.representativeWishes;
                final representativeWish = data.room.representativeWish;

                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: WishRoomHeader(
                        onHelpTap: () => WishGuideDialog.show(context),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: WishRoomSpacing.lg,
                        ),
                        child: Column(
                          children: [
                            WishRoomObject(
                              visualState: data.visualState,
                              onTap: () => ref
                                  .read(wishRoomUiProvider.notifier)
                                  .triggerAnimation(
                                    WishRoomAnimationEvent.objectTouch,
                                  ),
                              pendingAnimationEvent: pendingAnimationEvent,
                              onAnimationConsumed: () => ref
                                  .read(wishRoomUiProvider.notifier)
                                  .clearAnimation(),
                            ),
                            const SizedBox(height: WishRoomSpacing.md),
                            DailyMessageCard(message: data.dailyMessage),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: WishCardList(
                        wishes: representativeWishes,
                        onWishTap: (wish) =>
                            _handleWishCardTap(context, ref, controller, wish),
                        onEmptyCtaTap: () => _openWriteScreen(context, ref),
                      ),
                    ),
                    if (representativeWish != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            WishRoomSpacing.md,
                            WishRoomSpacing.sm,
                            WishRoomSpacing.md,
                            0,
                          ),
                          child: GrowthProgressCard(wish: representativeWish),
                        ),
                      ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: WishRoomSpacing.md,
                          vertical: WishRoomSpacing.md,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: FortunePouchStatusCard(
                                status: data.pouchStatus,
                              ),
                            ),
                            const SizedBox(width: WishRoomSpacing.sm),
                            Expanded(
                              child: PrayerStreakBadge(
                                consecutivePrayerDays:
                                    data.room.consecutivePrayerDays,
                                totalPrayerCount: data.room.totalPrayerCount,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          WishRoomSpacing.md,
                          WishRoomSpacing.sm,
                          WishRoomSpacing.md,
                          WishRoomSpacing.xxl,
                        ),
                        child: Column(
                          children: [
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
                                onPressed: representativeWish == null
                                    ? () => _openWriteScreen(context, ref)
                                    : () => _startPrayerFlow(
                                        context,
                                        ref,
                                        controller,
                                      ),
                                child: Text(
                                  data.room.hasPrayedToday
                                      ? PrayerType.deep.ctaLabel
                                      : PrayerType.daily.ctaLabel,
                                  style: WishRoomTextStyles.ctaLabel,
                                ),
                              ),
                            ),
                            const SizedBox(height: WishRoomSpacing.sm),
                            Row(
                              children: [
                                Expanded(
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
                                        _openHistoryScreen(context),
                                    child: Text(
                                      '내 소원 보기',
                                      style: WishRoomTextStyles.bodySm.copyWith(
                                        color: WishRoomColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: WishRoomSpacing.sm),
                                Expanded(
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
                                        _openCustomizeScreen(context, ref),
                                    child: Text(
                                      '방 꾸미기',
                                      style: WishRoomTextStyles.bodySm.copyWith(
                                        color: WishRoomColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

extension _FirstWhereOrNullX<T> on Iterable<T> {
  T? firstOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}
