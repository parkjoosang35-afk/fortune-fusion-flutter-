import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/domain/access/access_checker.dart';
import '../../../core/theme/app_unified_style.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/fortune/primary_cta.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/premium_graphics.dart';
import '../../luckpouch/application/luck_pouch_provider.dart';
import '../application/wish_room_provider.dart';
import '../domain/wish_room_model.dart';
import 'wish_room_candle_lab_screen.dart';
import 'wish_room_intro_modal.dart';
import 'wish_room_ritual_screen.dart';
import 'widgets/luck_pouch_reward_toast.dart';
import 'widgets/wish_room_light_gauge.dart';
import 'widgets/wish_room_shrine_view.dart';
import 'widgets/wish_room_streak_card.dart';
import 'widgets/wish_room_wish_card.dart';

/// [소원방 MVP §7 메인 화면 구조] 소원방 메인 — "항상 살아 있는 제단".
///
/// [통합정책] 이 화면은 커뮤니티군(주 자산 복주머니)이다. 열림패스는 절대
/// 노출/사용하지 않고(§2 정책 고정), 복주머니도 이번 MVP 기본 자산으로
/// 사용하지 않는다(§2). 복주머니 잔액만 헤더에 보조 노출한다(§7 헤더 규칙
/// "필요 시 복주머니 잔액 보조 노출 가능").
class WishRoomMainScreen extends StatefulWidget {
  const WishRoomMainScreen({super.key});

  @override
  State<WishRoomMainScreen> createState() => _WishRoomMainScreenState();
}

class _WishRoomMainScreenState extends State<WishRoomMainScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // [공통 정책 체크] 화면이 스스로 판단하지 않고 AccessChecker를 거친다.
      // 소원방은 진입을 무겁게 막지 않는 정책(§2)이라 항상 true를 반환하지만,
      // 향후 정책이 바뀌어도 이 화면 코드를 다시 손댈 필요가 없도록 게이트를
      // 유지한다.
      if (!context.read<AccessChecker>().canEnterWishRoom()) {
        AppToast.show(context, '지금은 소원방에 들어올 수 없어요', isError: true);
        Navigator.of(context).pop();
        return;
      }
      final provider = context.read<WishRoomProvider>();
      await provider.load();
      if (!mounted) return;
      if (!provider.introSeen) {
        await showWishRoomIntroModal(context);
      }
    });
  }

  Future<void> _startRitual(BuildContext context) async {
    final result = await Navigator.of(context).push<RitualRewardResult>(
      MaterialPageRoute(builder: (_) => const WishRoomRitualScreen()),
    );
    if (result != null && context.mounted) {
      LuckPouchRewardToast.show(context, result.luckPouch);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wishRoom = context.watch<WishRoomProvider>();
    final luckPouch = context.watch<LuckPouchProvider>();
    final ritualDoneToday = wishRoom.getTodayRitualStatus();

    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _Header(luckPouchBalance: luckPouch.balance),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  UnifiedTokens.screenPadding,
                  UnifiedTokens.spaceMd,
                  UnifiedTokens.screenPadding,
                  UnifiedTokens.spaceXxl,
                ),
                children: [
                  FadeSlideIn(
                    child: WishRoomShrineView(ritualDoneToday: ritualDoneToday),
                  ),
                  const SizedBox(height: UnifiedTokens.spaceLg),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 60),
                    child: ritualDoneToday
                        ? _DoneTodayPill()
                        : PrimaryCTA(
                            label: '오늘의 치성 드리기',
                            onPressed: () => _startRitual(context),
                          ),
                  ),
                  const SizedBox(height: UnifiedTokens.spaceXxl),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 100),
                    child: WishRoomLightGauge(percent: wishRoom.room.wishLightPercent),
                  ),
                  const SizedBox(height: UnifiedTokens.spaceMd),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 140),
                    child: WishRoomStreakCard(streakDays: wishRoom.room.streakDays),
                  ),
                  const SizedBox(height: UnifiedTokens.spaceMd),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 180),
                    child: WishRoomWishCard(wishText: wishRoom.room.wishText),
                  ),
                  const SizedBox(height: UnifiedTokens.spaceMd),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 220),
                    child: const _ComingSoonBanner(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.luckPouchBalance});

  final int luckPouchBalance;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        UnifiedTokens.screenPadding,
        UnifiedTokens.spaceMd,
        UnifiedTokens.screenPadding,
        0,
      ),
      child: Row(
        children: [
          Expanded(child: Text('소원방', style: UnifiedText.titleLarge())),
          if (kDebugMode)
            IconButton(
              tooltip: '촛불 시안 비교(디버그)',
              icon: Icon(
                Icons.palette_outlined,
                size: UnifiedTokens.iconMd,
                color: UnifiedColors.textCaption,
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const WishRoomCandleLabScreen(),
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: UnifiedTokens.spaceMd,
              vertical: UnifiedTokens.spaceXs,
            ),
            decoration: BoxDecoration(
              color: UnifiedColors.chipInactiveBg,
              borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.shopping_bag_outlined,
                  size: UnifiedTokens.iconSm,
                  color: UnifiedColors.textSecondary,
                ),
                const SizedBox(width: UnifiedTokens.spaceXs),
                Text('$luckPouchBalance', style: UnifiedText.chipLabel()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DoneTodayPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: UnifiedColors.cardSection,
        borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: UnifiedTokens.iconMd,
            color: UnifiedColors.textSecondary,
          ),
          const SizedBox(width: UnifiedTokens.spaceSm),
          Text('오늘의 치성을 완료했어요', style: UnifiedText.bodyStrong(color: UnifiedColors.textSecondary)),
        ],
      ),
    );
  }
}

/// [소원방 MVP §5 이번 단계 제외] 함께 기도하기/장식 꾸미기 등은 이번
/// 단계에서 제외되지만, "곧 만나요" 정도의 절제된 예고만 남겨 확장 여지를
/// 보여준다(assist banner 색상 #F2F0FA 그대로 사용).
class _ComingSoonBanner extends StatelessWidget {
  const _ComingSoonBanner();

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      backgroundColor: UnifiedColors.cardBanner,
      borderColor: Colors.transparent,
      showShadow: false,
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
      padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
      child: Row(
        children: [
          Icon(
            Icons.lock_clock_outlined,
            size: UnifiedTokens.iconMd,
            color: UnifiedColors.textCaption,
          ),
          const SizedBox(width: UnifiedTokens.spaceSm),
          Expanded(
            child: Text(
              '함께 기도하기 · 제단 꾸미기는 곧 만나요',
              style: UnifiedText.caption(),
            ),
          ),
        ],
      ),
    );
  }
}
