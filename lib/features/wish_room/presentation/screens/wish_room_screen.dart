import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/wish_item_model.dart';
import '../providers/wish_room_providers.dart';
import '../state/wish_room_state.dart';
import '../state/wish_room_ui_state.dart';
import '../theme/wish_room_theme.dart';
import '../widgets/wish_guide_dialog.dart';
import '../widgets/wish_room_animations.dart';
import '../widgets/wish_room_background.dart';
import '../widgets/wish_room_candle.dart';
import '../widgets/wish_room_seal.dart';
import 'wish_detail_screen.dart';
import 'wish_history_screen.dart';
import 'wish_room_prayer_flow.dart';

/// [대형 작업 — 디자인 핸드오프 8개 화면 재구현] "나의 소원" 탭(Home).
///
/// `design_handoff/wish-screens.jsx`의 `ScreenHome` 스펙을 그대로 재구현한다:
/// BgAtmosphere(sigilSize 340, opacity 0.22) 위에 헤더(eyebrow "나의
/// 소원방" + "오늘도 밝게 켜있어요" + ☾ 아이콘버튼) → Candle altar
/// 카드(4개 촛불 54/62/50/58 + "N개의 소원"/"N일째") → 최근 소원 리스트
/// (Candle 30 + 본문 + Seal 30) → FAB(+, 58px, 우하단 bottom:100).
///
/// [기존 커스텀 UI 삭제 지시 반영] 이전 버전의 성장 진행률 카드/복주머니
/// 현황/연속 기도 배지/소원구슬 클러스터/메인 오브제(WishRoomObject)는 이
/// 화면에서 완전히 제거했다 — 그 기능들은 삭제된 것이 아니라
/// [WishRoomTempleManagementScreen](신전관리 탭)으로 옮겨져 그대로
/// 유지된다(대형 작업 지시 "있는 기능은 페이지 한칸을 더 만들어서 구현
/// 다시 구현" 참고).
///
/// [슬롯 vs 촛불 개수 절충] README Home 스펙은 항상 4개의 촛불을
/// 보여주지만, 데이터 모델(`WishRoom.maxSlotCount = 3`)과
/// `HttpWishRoomRepository`(서버가 슬롯 잠금을 흉내내지 않고 항상 3개를
/// 열어둠)는 최대 3개의 소원만 지원한다. 이 화면은 4개의 촛불 슬롯을
/// 항상 그리되, 실제 등록된 소원 수(`room.wishes.length`, 0~3)만큼만
/// 불을 붙이고 나머지는 항상 꺼진 촛불로 표시해 두 스펙을 절충한다.
///
/// [하단 탭 위임] 이 화면은 [WishRoomShell]의 탭 0번 콘텐츠로만
/// 쓰이므로 자체 BottomNav를 그리지 않는다 — 하단 탭은 Shell이
/// 전담한다.
class WishRoomScreen extends ConsumerWidget {
  const WishRoomScreen({super.key});

  /// [Seal 매핑] `WishItem`에는 도장(Seal) 필드가 없으므로, 소원 카테고리
  /// 로부터 시각적으로 어울리는 도장을 결정론적으로 파생시킨다(저장 데이터
  /// 변경 없이 순수 표시용 매핑 — 매번 같은 카테고리는 항상 같은 도장).
  WishSeal _sealForCategory(WishCategory category) {
    switch (category) {
      case WishCategory.health:
        return WishSeal.health;
      case WishCategory.wealth:
        return WishSeal.wealth;
      case WishCategory.exam:
        return WishSeal.pass;
      case WishCategory.love:
        return WishSeal.bond;
      case WishCategory.family:
        return WishSeal.fortune;
      case WishCategory.achievement:
        return WishSeal.wish;
      case WishCategory.healing:
        return WishSeal.health;
      case WishCategory.custom:
        return WishSeal.wish;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(wishRoomControllerProvider);

    // 최초 진입 시 가이드 팝업(초회 1회) 노출 — 기존 동작 100% 유지.
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

    // [애니메이션 이벤트 소비] 슬롯 해금 마일스톤 축하는 이 화면 레벨의
    // 스낵바로 계속 소비한다(메인 오브제가 제거됐어도 이 알림 자체는
    // 유효한 기능이므로 유지).
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
              SnackBar(content: Text(message), backgroundColor: WishRoomColors.gold),
            );
          }
        });
      }
    });

    return Scaffold(
      backgroundColor: WishRoomColors.backgroundDeep,
      body: asyncData.when(
        loading: () => Stack(
          children: [
            const Positioned.fill(child: WishRoomBackground()),
            const Center(
              child: CircularProgressIndicator(color: WishRoomColors.gold),
            ),
          ],
        ),
        error: (err, st) => Stack(
          children: [
            const Positioned.fill(child: WishRoomBackground()),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(WishRoomSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('잠시 후 다시 시도해주세요', style: WishRoomTextStyles.bodyMd),
                    const SizedBox(height: WishRoomSpacing.md),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(wishRoomControllerProvider),
                      child: const Text('다시 시도'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        data: (data) {
          final controller = ref.read(wishRoomControllerProvider.notifier);
          final isEmpty = data.room.wishes.isEmpty;

          if (isEmpty) {
            return _EmptyHome(onCreateTap: () => WishRoomPrayerFlow.openWriteScreen(context, ref));
          }

          return _HomeContent(
            data: data,
            onWishTap: (wish) =>
                WishRoomPrayerFlow.handleWishCardTap(context, ref, controller, wish),
            // [디자인 핸드오프 — Wish Detail 진입] README 흐름표 "Home wish
            // row tap → Wish Detail"은 짧은 탭을 상세 진입으로 쓰지만, 이
            // 화면의 짧은 탭은 이미 검증된 치성 흐름(handleWishCardTap)이
            // 선점하고 있어 그 동작을 바꾸지 않는다(§ "기존 구현
            // 삭제/재작성 금지"). 대신 롱프레스를 상세 화면 전용 진입점으로
            // 추가해 두 기능을 충돌 없이 공존시킨다.
            onWishLongPress: (wish) => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => WishDetailScreen(
                  wish: wish,
                  index: data.room.wishes.indexOf(wish),
                ),
              ),
            ),
            onSeeAllTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const WishHistoryScreen()),
            ),
            onHelpTap: () => WishGuideDialog.show(context),
            onFabTap: () => WishRoomPrayerFlow.openWriteScreen(context, ref),
            sealForCategory: _sealForCategory,
          );
        },
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  final WishRoomData data;
  final ValueChanged<WishItem> onWishTap;
  final VoidCallback onSeeAllTap;
  final VoidCallback onHelpTap;
  final VoidCallback onFabTap;
  final WishSeal Function(WishCategory) sealForCategory;

  const _HomeContent({
    required this.data,
    required this.onWishTap,
    required this.onSeeAllTap,
    required this.onHelpTap,
    required this.onFabTap,
    required this.sealForCategory,
  });

  @override
  Widget build(BuildContext context) {
    final wishes = data.room.wishes;
    final wishCount = wishes.length;
    final consecutiveDays = data.room.consecutivePrayerDays;
    // README 스펙 촛불 크기 고정 리듬 — 실제로 밝혀진 개수만큼만 lit.
    const candleSizes = [54.0, 62.0, 50.0, 58.0];

    return Stack(
      children: [
        const Positioned.fill(
          child: WishRoomBackground(mainSigilSize: 340, mainSigilOpacity: 0.22),
        ),
        SafeArea(
          child: DramaticEntrance(
            child: Column(
              children: [
                const SizedBox(height: WishRoomSpacing.sm),
                // ── Header ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    WishRoomSpacing.lg,
                    4,
                    WishRoomSpacing.lg,
                    WishRoomSpacing.md,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('나의 소원방', style: WishRoomTextStyles.eyebrow),
                            const SizedBox(height: 4),
                            Text('오늘도 밝게 켜있어요', style: WishRoomTextStyles.sectionTitle),
                          ],
                        ),
                      ),
                      TapBounce(
                        onTap: onHelpTap,
                        child: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: WishRoomColors.surfaceCard,
                            shape: BoxShape.circle,
                            border: Border.all(color: WishRoomColors.surfaceCardBorder),
                          ),
                          child: const Text('☾', style: TextStyle(fontSize: 18)),
                        ),
                      ),
                    ],
                  ),
                ),
                // ── Candle altar ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: WishRoomSpacing.md),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
                    decoration: BoxDecoration(
                      color: WishRoomColors.surfaceCard,
                      border: Border.all(color: WishRoomColors.surfaceCardBorder),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: List.generate(4, (i) {
                            return WishRoomCandle(
                              size: candleSizes[i],
                              lit: i < wishCount,
                              color: i < wishCount
                                  ? WishRoomColors.glow
                                  : WishRoomColors.textSecondary,
                            );
                          }),
                        ),
                        const SizedBox(height: WishRoomSpacing.sm),
                        Container(
                          padding: const EdgeInsets.only(top: WishRoomSpacing.sm),
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(color: WishRoomColors.surfaceCardBorder),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('$wishCount 개의 소원', style: WishRoomTextStyles.metaMono),
                              Text('$consecutiveDays 일째', style: WishRoomTextStyles.metaMono),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: WishRoomSpacing.lg),
                // ── Wish list ──
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      WishRoomSpacing.md,
                      0,
                      WishRoomSpacing.md,
                      120,
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('최근 소원', style: WishRoomTextStyles.wishBodyList),
                            GestureDetector(
                              onTap: onSeeAllTap,
                              child: Text('전체 보기 →', style: WishRoomTextStyles.caption),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: WishRoomSpacing.sm),
                      ...wishes.map((wish) {
                        final days = DateTime.now().difference(wish.createdAt).inDays;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: WishRoomSpacing.sm),
                          child: TapBounce(
                            onTap: () => onWishTap(wish),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: WishRoomColors.surfaceCard,
                                border: Border.all(color: WishRoomColors.surfaceCardBorder),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 36,
                                    height: 50,
                                    child: Align(
                                      alignment: Alignment.bottomCenter,
                                      child: WishRoomCandle(size: 30),
                                    ),
                                  ),
                                  const SizedBox(width: WishRoomSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          wish.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: WishRoomTextStyles.wishBodyList,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '$days일째 밝히는 중',
                                          style: WishRoomTextStyles.metaMono,
                                        ),
                                      ],
                                    ),
                                  ),
                                  WishRoomSeal(
                                    text: sealForCategory(wish.category).glyph,
                                    size: 30,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // ── FAB ──
        Positioned(
          bottom: 100,
          right: 20,
          child: TapBounce(
            onTap: onFabTap,
            child: Container(
              width: 58,
              height: 58,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: WishRoomColors.glow,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: WishRoomColors.glowShadow, blurRadius: 20),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.08),
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Text(
                '+',
                style: TextStyle(
                  fontFamily: 'NotoSerifKRWish',
                  fontWeight: FontWeight.w900,
                  fontSize: 26,
                  color: Color(0xFF3A2515),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// [디자인 핸드오프 — Empty State] README `8. Empty` 스펙 그대로 재구현.
/// `BgAtmosphere(340, 0.15, dust:false)` + 꺼진 촛불(80px, opacity 0.4) +
/// "아직 소원이\n담기지 않았어요" + "♢ 0 개의 소원 ♢" + btnPrimary
/// "+ 첫 소원 담기".
class _EmptyHome extends StatelessWidget {
  final VoidCallback onCreateTap;

  const _EmptyHome({required this.onCreateTap});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: WishRoomBackground(
            mainSigilSize: 340,
            mainSigilOpacity: 0.15,
            showDust: false,
          ),
        ),
        SafeArea(
          child: DramaticEntrance(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                WishRoomSpacing.lg,
                WishRoomSpacing.md,
                WishRoomSpacing.lg,
                120,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text('나의 소원방', style: WishRoomTextStyles.eyebrow),
                  const Spacer(),
                  Opacity(
                    opacity: 0.4,
                    child: WishRoomCandle(
                      size: 80,
                      lit: false,
                      color: WishRoomColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: WishRoomSpacing.xl),
                  Text(
                    '아직 소원이\n담기지 않았어요',
                    textAlign: TextAlign.center,
                    style: WishRoomTextStyles.screenTitle,
                  ),
                  const SizedBox(height: WishRoomSpacing.md),
                  Text(
                    '첫 촛불을 켜보세요.\n마음속 이야기, 조용히 들어드릴게요.',
                    textAlign: TextAlign.center,
                    style: WishRoomTextStyles.bodySm,
                  ),
                  const SizedBox(height: WishRoomSpacing.lg),
                  Text('♢  0 개의 소원  ♢', style: WishRoomTextStyles.metaMono),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: TapBounce(
                      onTap: onCreateTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                        decoration: BoxDecoration(
                          color: WishRoomColors.glow,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(color: WishRoomColors.glowShadow, blurRadius: 20),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '+ 첫 소원 담기',
                          style: WishRoomTextStyles.buttonLabel.copyWith(
                            color: const Color(0xFF2A1A0A),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
