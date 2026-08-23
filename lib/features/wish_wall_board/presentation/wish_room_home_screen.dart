import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../application/wish_wall_provider.dart';
import '../domain/wish_wall_models.dart';
import '../theme/wish_room_theme.dart';
import '../widgets/blessing_bag_bottom_sheet.dart';
import '../widgets/wish_room_candle.dart';
import '../widgets/wish_room_dust.dart';
import '../widgets/wish_room_seal.dart';
import '../widgets/wish_room_sigil.dart';
import 'wish_wall_board_screen.dart';
import 'wish_wall_compose_screen.dart';
import 'wish_wall_detail_screen.dart';
import 'wish_wall_my_screen.dart';

/// 00. 소원방(Wish Room) — "마법진이 소환되는 신전" 제단 홈 화면.
///
/// [소원방 리스킨] `design_handoff_wish_room.zip`의 V2(달빛크리스탈,
/// anim-dramatic) 디자인을 적용한 새 소원방 대표 화면. 메인화면의 "소원방"
/// 카드와 하단 탭바의 "소원방" 탭이 모두 이 화면으로 연결된다(완전히
/// 동일한 화면 = 하나의 진입점).
///
/// [재화 정책] 이 화면은 새 화폐를 만들지 않는다. 복주머니 잔액/적립/차감은
/// 전부 [WishWallProvider.policy]([BlessingBagPolicyAdapter]) →
/// [LuckPouchProvider] → [WalletProvider] 경로로만 처리된다.
///
/// 기존에 이미 완성되어 있던 소원벽 피드(카테고리/세그먼트/댓글 등 전체
/// 기능)는 [WishWallBoardScreen]으로 그대로 보존하고, 이 제단 화면 하단의
/// "전체 소원 게시판 보러가기"에서 계속 접근할 수 있게 유지한다(기존 기능을
/// 삭제하지 않는다는 원칙).
class WishRoomHomeScreen extends StatefulWidget {
  const WishRoomHomeScreen({super.key});

  @override
  State<WishRoomHomeScreen> createState() => _WishRoomHomeScreenState();
}

class _WishRoomHomeScreenState extends State<WishRoomHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final provider = context.read<WishWallProvider>();
      await provider.ensureLoaded();
      if (!mounted) return;
      final granted = await provider.policy.earnAltarVisitBonus();
      if (!mounted || granted <= 0) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: WishRoomColors.backgroundMid,
          content: Text(
            '🕯 제단 참배 보너스로 복주머니 $granted개를 받았어요',
            style: WishRoomTextStyles.bodySm.copyWith(
              color: WishRoomColors.textPrimary,
            ),
          ),
        ),
      );
    });
  }

  void _openDetail(WishPost wish) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WishWallDetailScreen(wishId: wish.id)),
    );
  }

  void _openCompose() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const WishWallComposeScreen()));
  }

  void _openMy() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const WishWallMyScreen()));
  }

  void _openFullBoard() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const WishWallBoardScreen()));
  }

  Future<void> _openPouchHub({WishPost? wish, required bool receive}) async {
    await showBlessingBagBottomSheet(
      context,
      wish: wish,
      initialTab: receive ? BlessingBagSheetTab.receive : BlessingBagSheetTab.send,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WishWallProvider>();
    final feed = provider.feed;
    final altarWishes = List<WishPost>.of(feed)
      ..sort((a, b) => b.sincerityScore.compareTo(a.sincerityScore));
    final topAltar = altarWishes.take(5).toList();
    final recent = List<WishPost>.of(feed)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      backgroundColor: WishRoomColors.backgroundDeep,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: WishRoomColors.backgroundGradient,
        ),
        child: Stack(
          children: [
            // 배경 마법진 이중 링(정회전 40s / 역회전 55s) — 배경 장식이므로
            // RepaintBoundary로 감싸 전경 리스트 리페인트와 분리한다.
            Positioned(
              top: -80,
              left: -60,
              child: RepaintBoundary(
                child: Opacity(
                  opacity: 0.5,
                  child: WishRoomSigilRing(size: 340, opacity: 0.35),
                ),
              ),
            ),
            Positioned(
              bottom: -100,
              right: -80,
              child: RepaintBoundary(
                child: Opacity(
                  opacity: 0.4,
                  child: WishRoomSigilRing(
                    size: 300,
                    opacity: 0.3,
                    reverse: true,
                    color: WishRoomColors.crystal,
                  ),
                ),
              ),
            ),
            const Positioned.fill(child: WishRoomDust(count: 12)),
            SafeArea(
              child: Column(
                children: [
                  _TopBar(
                    balance: provider.policy.balance,
                    onOpenMy: _openMy,
                    onOpenPouch: () => _openPouchHub(receive: true),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      color: WishRoomColors.accent,
                      backgroundColor: WishRoomColors.backgroundMid,
                      onRefresh: provider.loadFeed,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(
                          WishRoomSpacing.md,
                          WishRoomSpacing.sm,
                          WishRoomSpacing.md,
                          140,
                        ),
                        children: [
                          Text('오늘의 제단', style: WishRoomTextStyles.sectionTitle),
                          const SizedBox(height: 4),
                          Text(
                            '가장 정성이 모인 소원에 촛불이 켜져요',
                            style: WishRoomTextStyles.bodySm,
                          ),
                          const SizedBox(height: WishRoomSpacing.md),
                          if (provider.isLoading && topAltar.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: WishRoomColors.accent,
                                ),
                              ),
                            )
                          else
                            _AltarRow(wishes: topAltar, onTap: _openDetail),
                          const SizedBox(height: WishRoomSpacing.xl),
                          Row(
                            children: [
                              Text(
                                '오늘 밝혀진 소원들',
                                style: WishRoomTextStyles.sectionTitle,
                              ),
                              const Spacer(),
                              _GhostButton(
                                label: '전체 보기',
                                onTap: _openFullBoard,
                              ),
                            ],
                          ),
                          const SizedBox(height: WishRoomSpacing.sm),
                          ...recent
                              .take(8)
                              .map(
                                (w) => _WishSealCard(
                                  wish: w,
                                  onTap: () => _openDetail(w),
                                  onSendPouch: () =>
                                      _openPouchHub(wish: w, receive: false),
                                ),
                              ),
                          if (recent.isEmpty && !provider.isLoading)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 40),
                              child: Center(
                                child: Text(
                                  '아직 밝혀진 소원이 없어요',
                                  style: WishRoomTextStyles.bodySm,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: WishRoomSpacing.lg,
              bottom: WishRoomSpacing.lg,
              child: _ComposeFab(onPressed: _openCompose),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.balance,
    required this.onOpenMy,
    required this.onOpenPouch,
  });

  final int balance;
  final VoidCallback onOpenMy;
  final VoidCallback onOpenPouch;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        WishRoomSpacing.md,
        WishRoomSpacing.sm,
        WishRoomSpacing.md,
        WishRoomSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('THE ALTAR', style: WishRoomTextStyles.eyebrow),
                const SizedBox(height: 2),
                Text('소원방', style: WishRoomTextStyles.screenTitle),
              ],
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(WishRoomRadius.pill),
            onTap: onOpenPouch,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: WishRoomColors.surfaceCard,
                borderRadius: BorderRadius.circular(WishRoomRadius.pill),
                border: Border.all(color: WishRoomColors.surfaceCardBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('✨', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(
                    '$balance',
                    style: WishRoomTextStyles.pillLabel.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: WishRoomColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onOpenMy,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: WishRoomColors.surfaceCard,
                border: Border.all(color: WishRoomColors.surfaceCardBorder),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.person_outline_rounded,
                size: 19,
                color: WishRoomColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AltarRow extends StatelessWidget {
  const _AltarRow({required this.wishes, required this.onTap});
  final List<WishPost> wishes;
  final ValueChanged<WishPost> onTap;

  @override
  Widget build(BuildContext context) {
    if (wishes.isEmpty) {
      return SizedBox(
        height: 150,
        child: Center(
          child: Text('아직 켜진 촛불이 없어요', style: WishRoomTextStyles.bodySm),
        ),
      );
    }
    return WishRoomSigilSummon(
      builder: (context, drawProgress) {
        return SizedBox(
          height: 168,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: wishes.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final wish = wishes[index];
              final stage = wish.glow.toGrowthStage;
              return GestureDetector(
                onTap: () => onTap(wish),
                child: Opacity(
                  opacity: drawProgress,
                  child: Container(
                    width: 108,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: WishRoomColors.surfaceCard,
                      borderRadius: BorderRadius.circular(WishRoomRadius.md),
                      border: Border.all(
                        color: WishRoomColors.surfaceCardBorder,
                      ),
                    ),
                    child: Column(
                      children: [
                        WishRoomCandle(
                          size: 42,
                          color: WishRoomColors.forGrowthStage(stage),
                          flickerDuration: const Duration(
                            milliseconds: 1800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            wish.categoryId.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: WishRoomTextStyles.caption,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

WishSeal _sealForCategory(WishCategory c) {
  switch (c) {
    case WishCategory.exam:
    case WishCategory.job:
      return WishSeal.pass;
    case WishCategory.money:
      return WishSeal.wealth;
    case WishCategory.love:
    case WishCategory.family:
      return WishSeal.bond;
    case WishCategory.health:
      return WishSeal.health;
    case WishCategory.travel:
    case WishCategory.growth:
    case WishCategory.etc:
      return WishSeal.wish;
  }
}

class _WishSealCard extends StatelessWidget {
  const _WishSealCard({
    required this.wish,
    required this.onTap,
    required this.onSendPouch,
  });

  final WishPost wish;
  final VoidCallback onTap;
  final VoidCallback onSendPouch;

  @override
  Widget build(BuildContext context) {
    final seal = _sealForCategory(wish.categoryId);
    return Padding(
      padding: const EdgeInsets.only(bottom: WishRoomSpacing.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(WishRoomRadius.md),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: WishRoomColors.surfaceCard,
            borderRadius: BorderRadius.circular(WishRoomRadius.md),
            border: Border.all(color: WishRoomColors.surfaceCardBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WishRoomSeal(text: seal.glyph, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            wish.displayName,
                            style: WishRoomTextStyles.bodySm.copyWith(
                              fontWeight: FontWeight.w700,
                              color: WishRoomColors.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          wish.categoryId.label,
                          style: WishRoomTextStyles.caption,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      wish.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: WishRoomTextStyles.wishBodyList,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: onSendPouch,
                borderRadius: BorderRadius.circular(WishRoomRadius.pill),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: WishRoomColors.accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(WishRoomRadius.pill),
                  ),
                  child: const Text('✨', style: TextStyle(fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(WishRoomRadius.pill),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: WishRoomTextStyles.bodySm.copyWith(
                color: WishRoomColors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: WishRoomColors.accent,
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposeFab extends StatelessWidget {
  const _ComposeFab({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          color: WishRoomColors.accent,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: WishRoomColors.glowShadow,
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              '새 소원 담기',
              style: WishRoomTextStyles.buttonLabel.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
