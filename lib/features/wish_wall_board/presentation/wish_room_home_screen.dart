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
import 'wish_room_compose_screen.dart';
import 'wish_room_detail_screen.dart';
import 'wish_room_feed_screen.dart';
import 'wish_wall_my_screen.dart';

/// 소원방(Wish Room) — "나의 소원방" 홈 화면.
///
/// [디자인 핸드오프 — pixel-perfect 재현] `design_handoff_v2_dramatic.zip`
/// (V2 단일 프로덕션 핸드오프 패키지, dev-spec.md 기준)의
/// `design_files/wish-screens.jsx`에 정의된 `ScreenHome` 컴포넌트(V2
/// "마법진이 소환되는 신전" · Moonlit Crystal 팔레트, dramatic 애니메이션)를
/// **발명 없이 그대로** Flutter로 재구현한다. 이 zip의 wish-screens.jsx는
/// 이전 `design_handoff_wish_room.zip`과 바이트 단위로 동일함을 diff로
/// 확인했으므로 레이아웃 자체는 이미 이 파일에 pixel-perfect로 구현되어
/// 있다(재작성 불필요, 복주머니 통합만 추가).
///
/// 절대 하지 말 것(과거 세션에서 사용자가 강하게 거부한 실수):
/// - 기존 소원벽(bottle-feed)의 "정성지수 랭킹", "공개 피드 기준 정렬",
///   "이중 마법진 배경" 등을 이 화면에 섞어 넣는 것.
/// 이 화면은 디자인 문서의 구조를 그대로 따른다:
///   헤더(eyebrow+title, [복주머니 잔액 칩]+☾버튼) → 제단 카드(고정 4촛불
///   행 + meta strip) → "최근 소원" 리스트(촛불+텍스트+[탭 가능한]Seal)
///   → 자체 BottomNav(3탭) → FAB(+)
///
/// [데이터] 디자인 원본은 정적 샘플(4개)이지만, 실제 앱에서는 사용자 자신의
/// 소원 목록([WishWallProvider.myWishes])을 그대로 바인딩한다("나의
/// 소원방"이므로 공개 피드가 아니라 내 소원 목록을 사용해야 의미가 맞다).
///
/// [복주머니 시스템 통합 — 사용자 명시적 위임] dev-spec.md는 결제/화폐
/// 관련 요소를 스코프에서 제외하지만, 사용자가 "요디자인에 복주머니
/// 시스템을 니가 잘 만들어봐"라고 직접 위임했다. 새 화폐를 만들지 않고
/// 기존 경로만 사용한다:
/// [BlessingBagPolicyAdapter] → [LuckPouchProvider] → [WalletProvider].
/// 통합 지점 2곳(디자인 레이아웃을 깨지 않는 최소 침습):
/// 1) 헤더의 ☾ 버튼 왼쪽에 잔액 칩(🎁 N) — 탭하면 "받기" 탭 팝업
///    ([showBlessingBagBottomSheet], 제단참배/기도/소원함/성취 4채널).
/// 2) 각 소원 행의 Seal(원래도 있던 도장 요소)을 탭하면 그 소원에
///    "보내기" 팝업.
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
      // [비로그인/네트워크 실패 방어] 미로그인 상태에서는 fetchMyWishes가
      // 401("로그인이 필요합니다")을 던진다. 이 경우에도 화면은 빈 소원
      // 목록으로 정상 표시되어야 한다.
      try {
        await provider.loadMyWishes();
      } catch (_) {
        // 비로그인/네트워크 실패는 조용히 무시 - 빈 소원 목록으로 계속 진행.
      }
      // [버그 수정 — 2026 세션] "제단 참배 보너스" 자동 지급 로직을 제거했다.
      // 이 화면은 (1) 앱 시작 시 IndexedStack이 5탭을 전부 미리 만들면서
      // 자동 실행되고, (2) 홈 카드에서 push로 진입할 때도 새 인스턴스가
      // 생성되며 다시 실행되어, 사용자가 아무 액션도 하지 않았는데
      // "제단 참배 보너스" 스낵바가 반복적으로 뜨는 버그가 있었다.
      // "제단 참배" 보상은 사용자가 복주머니 받기 팝업(_ReceivePanel)에서
      // 명시적으로 눌렀을 때만 지급되어야 하며, 그 흐름은
      // showBlessingBagBottomSheet(initialTab: receive)에 이미 구현되어
      // 있으므로 여기서는 화면 진입만으로 아무것도 자동 지급하지 않는다.
    });
  }

  // [라우팅 정리 — V2 8화면 전체 교체] 04 Home에서 push되는 4개 목적지를
  // 신규 V2 화면(01/03/05/06)으로 교체한다. "기록" 탭([_openMy])만은
  // dev-spec.md의 8화면 목록에 포함되지 않는 별도 화면이므로 기존
  // [WishWallMyScreen]을 그대로 유지한다(문서 §미결정 사항, 의도적 유지).
  void _openDetail(WishPost wish) {
    final provider = context.read<WishWallProvider>();
    final index = provider.myWishes.indexWhere((w) => w.id == wish.id);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WishRoomDetailScreen(
          wishId: wish.id,
          index: index >= 0 ? index + 1 : 1,
        ),
      ),
    );
  }

  void _openCompose() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const WishRoomComposeScreen()));
  }

  void _openMy() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const WishWallMyScreen()));
  }

  void _openFullBoard() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const WishRoomFeedScreen()));
  }

  /// 복주머니 허브 팝업 — "받기" 탭으로 열기(잔액 칩 탭).
  ///
  /// [복주머니 시스템 통합 — 사용자 위임] V2 디자인 원본(dev-spec 스코프
  /// 제외 항목: "결제·정기구독·인앱스토어·광고·조각 시스템")에는 잔액 UI가
  /// 없었지만, 사용자가 "요디자인에 복주머니 시스템을 니가 잘 만들어봐"라고
  /// 명시적으로 위임했다. 새 화폐를 만들지 않고 기존
  /// BlessingBagPolicyAdapter → LuckPouchProvider 경로만 사용하며, 디자인의
  /// 헤어라인/카드 톤(surfaceCard/surfaceCardBorder/glow)에 맞춰 헤더에
  /// 아주 작은 칩 하나만 얹는 방식으로 시각적 통일성을 지킨다.
  Future<void> _openBlessingBagReceive() async {
    await showBlessingBagBottomSheet(
      context,
      initialTab: BlessingBagSheetTab.receive,
    );
  }

  /// 리스트 행의 Seal(도장)을 탭하면 그 소원에 복주머니를 "보내기".
  Future<void> _openBlessingBagSend(WishPost wish) async {
    await showBlessingBagBottomSheet(
      context,
      wish: wish,
      initialTab: BlessingBagSheetTab.send,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WishWallProvider>();
    final wishes = provider.myWishes;
    final balance = provider.policy.balance;

    final wishCount = wishes.length;
    int totalDays = 0;
    if (wishes.isNotEmpty) {
      final earliest = wishes
          .map((w) => w.createdAt)
          .reduce((a, b) => a.isBefore(b) ? a : b);
      totalDays = DateTime.now().difference(earliest).inDays;
      if (totalDays < 0) totalDays = 0;
    }

    return Scaffold(
      backgroundColor: WishRoomColors.backgroundDeep,
      body: Stack(
        children: [
          // ── BgAtmosphere: radial gradient(120% 80% at 50% 20%) + 중앙
          //    고정 마법진(단일, 회전 40s) + Dust(10개). 원본 그대로 — 좌상단/
          //    우하단에 이중 링을 겹쳐 그리던 과거 실수를 여기서 제거했다.
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.6),
                  radius: 1.3,
                  colors: [
                    WishRoomColors.backgroundSoft,
                    WishRoomColors.backgroundDeep,
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: RepaintBoundary(
              child: Center(
                child: Opacity(
                  opacity: 0.9,
                  child: WishRoomSigilRing(size: 340, opacity: 0.22),
                ),
              ),
            ),
          ),
          const Positioned.fill(child: WishRoomDust(count: 10)),

          // ── screen-inner: padding 62px 0 40px, flex column ──
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 0),
              child: Column(
                children: [
                  _HomeHeader(
                    balance: balance,
                    onOpenMoon: _openFullBoard,
                    onOpenPouch: _openBlessingBagReceive,
                  ),
                  _CandleAltar(wishCount: wishCount, totalDays: totalDays),
                  const SizedBox(height: 20),
                  Expanded(
                    child: _WishListSection(
                      wishes: wishes,
                      isLoading: provider.isLoading,
                      onSeeAll: _openMy,
                      onTapWish: _openDetail,
                      onTapSeal: _openBlessingBagSend,
                    ),
                  ),
                  _WishRoomBottomNav(
                    onHome: () {},
                    onFeed: _openFullBoard,
                    onRecord: _openMy,
                  ),
                ],
              ),
            ),
          ),

          // ── FAB: bottom:100 right:20, 58x58 원, glow bg, + ──
          Positioned(
            right: 20,
            bottom: 100,
            child: _ComposeFab(onPressed: _openCompose),
          ),
        ],
      ),
    );
  }
}

/// 헤더 row: eyebrow "나의 소원방" + title "오늘도 밝게 켜있어요",
/// 우측 [복주머니 잔액 칩] + ☾ 버튼.
///
/// [복주머니 시스템 통합] 디자인 원본에는 잔액 UI가 없었으나, 사용자가
/// 명시적으로 위임한 항목이다. ☾ 버튼과 같은 40px 높이의 캡슐 칩을 그
/// 왼쪽에 붙여, 원본 헤더 레이아웃(줄바꿈 없이 한 행)을 깨지 않는
/// 범위에서만 추가한다. 새 화폐 없음 — [WishWallProvider.policy.balance]
/// (→ LuckPouchProvider → WalletProvider)를 그대로 표시할 뿐이다.
class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.balance,
    required this.onOpenMoon,
    required this.onOpenPouch,
  });
  final int balance;
  final VoidCallback onOpenMoon;
  final VoidCallback onOpenPouch;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '나의 소원방',
                  style: TextStyle(
                    fontFamily: 'IBMPlexMonoWish',
                    fontSize: 10,
                    letterSpacing: 3.0,
                    color: WishRoomColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '오늘도 밝게 켜있어요',
                  style: TextStyle(
                    fontFamily: 'NotoSerifKRWish',
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                    color: WishRoomColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          _PouchBalanceChip(balance: balance, onTap: onOpenPouch),
          const SizedBox(width: 8),
          InkWell(
            onTap: onOpenMoon,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: WishRoomColors.surfaceCard,
                border: Border.all(color: WishRoomColors.surfaceCardBorder),
              ),
              alignment: Alignment.center,
              child: const Text('☾', style: TextStyle(fontSize: 18)),
            ),
          ),
        ],
      ),
    );
  }
}

/// 복주머니 잔액 칩 — 40px 높이 캡슐, 디자인 헤어라인/카드 톤 그대로 사용.
/// 탭하면 "받기" 탭(제단참배/기도/소원함/성취 4채널)이 열린다.
class _PouchBalanceChip extends StatelessWidget {
  const _PouchBalanceChip({required this.balance, required this.onTap});
  final int balance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: WishRoomColors.surfaceCard,
          border: Border.all(color: WishRoomColors.surfaceCardBorder),
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎁', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              '$balance',
              style: const TextStyle(
                fontFamily: 'IBMPlexMonoWish',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: WishRoomColors.glow,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 제단 카드: margin 0 20, padding 32/16/16, radius20, card+line,
/// 상단 radial glow(height80,opacity0.5) + 4촛불(54/62/50/58) + meta strip.
class _CandleAltar extends StatelessWidget {
  const _CandleAltar({required this.wishCount, required this.totalDays});
  final int wishCount;
  final int totalDays;

  static const List<double> _sizes = [54, 62, 50, 58];
  static const List<double> _bottomOffsets = [0, -4, 0, 0];

  @override
  Widget build(BuildContext context) {
    final shown = wishCount.clamp(0, 4);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
      decoration: BoxDecoration(
        color: WishRoomColors.surfaceCard,
        border: Border.all(color: WishRoomColors.surfaceCardBorder),
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 상단 안쪽 radial glow.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 80,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, 1),
                  radius: 1.2,
                  colors: [
                    WishRoomColors.glowShadow.withValues(alpha: 0.5),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.7],
                ),
              ),
            ),
          ),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(
                    shown == 0 ? 0 : 4,
                    (i) => shown > 0
                        ? Transform.translate(
                            offset: Offset(0, -_bottomOffsets[i]),
                            child: (i < shown)
                                ? WishRoomCandle(
                                    size: _sizes[i],
                                    color: WishRoomColors.glow,
                                  )
                                : Opacity(
                                    opacity: 0.25,
                                    child: WishRoomCandle(
                                      size: _sizes[i],
                                      color: WishRoomColors.textTertiary,
                                      lit: false,
                                    ),
                                  ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.only(top: 12),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: WishRoomColors.surfaceCardBorder),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$wishCount 개의 소원',
                      style: TextStyle(
                        fontFamily: 'IBMPlexMonoWish',
                        fontSize: 10,
                        letterSpacing: 2.0,
                        color: WishRoomColors.textSecondary,
                      ),
                    ),
                    Text(
                      '$totalDays 일째',
                      style: TextStyle(
                        fontFamily: 'IBMPlexMonoWish',
                        fontSize: 10,
                        letterSpacing: 2.0,
                        color: WishRoomColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "최근 소원" 타이틀 + "전체 보기 →" + 리스트(촛불/텍스트/Seal 행).
class _WishListSection extends StatelessWidget {
  const _WishListSection({
    required this.wishes,
    required this.isLoading,
    required this.onSeeAll,
    required this.onTapWish,
    required this.onTapSeal,
  });

  final List<WishPost> wishes;
  final bool isLoading;
  final VoidCallback onSeeAll;
  final ValueChanged<WishPost> onTapWish;
  final ValueChanged<WishPost> onTapSeal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                const Text(
                  '최근 소원',
                  style: TextStyle(
                    fontFamily: 'GowunBatangWish',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: WishRoomColors.textPrimary,
                  ),
                ),
                InkWell(
                  onTap: onSeeAll,
                  child: Text(
                    '전체 보기 →',
                    style: TextStyle(
                      fontSize: 11,
                      color: WishRoomColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: isLoading && wishes.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(
                      color: WishRoomColors.accent,
                    ),
                  )
                : wishes.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Opacity(
                            opacity: 0.4,
                            child: WishRoomCandle(
                              size: 60,
                              color: WishRoomColors.textTertiary,
                              lit: false,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '아직 소원이 담기지 않았어요',
                            style: TextStyle(
                              fontFamily: 'NotoSerifKRWish',
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: WishRoomColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '첫 촛불을 켜보세요',
                            style: TextStyle(
                              fontSize: 13,
                              color: WishRoomColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: wishes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final wish = wishes[index];
                      return _WishListRow(
                        wish: wish,
                        onTap: () => onTapWish(wish),
                        onTapSeal: () => onTapSeal(wish),
                      );
                    },
                  ),
          ),
        ],
      ),
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

/// 리스트 행: gap14, padding14, card+line, radius14.
/// 좌측 36x50 촛불(size30) / 중앙 텍스트+"N일째 밝히는 중" / 우측 Seal(size30).
///
/// [복주머니 시스템 통합] 우측 Seal(디자인 원본에 이미 존재하는 도장
/// 요소)을 탭하면 이 소원에 복주머니를 "보내기"(응원) 팝업이 열린다.
/// 새 시각 요소를 추가하지 않고 기존 요소에 인터랙션만 얹는 방식으로
/// 디자인의 통일성을 유지한다. 행 전체 탭(onTap)은 여전히 상세 화면으로
/// 이동하며, Seal은 별도의 작은 히트영역으로 분리해 두 동작이 충돌하지
/// 않게 한다.
class _WishListRow extends StatelessWidget {
  const _WishListRow({
    required this.wish,
    required this.onTap,
    required this.onTapSeal,
  });
  final WishPost wish;
  final VoidCallback onTap;
  final VoidCallback onTapSeal;

  @override
  Widget build(BuildContext context) {
    final days = DateTime.now().difference(wish.createdAt).inDays;
    final seal = _sealForCategory(wish.categoryId);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: WishRoomColors.surfaceCard,
          border: Border.all(color: WishRoomColors.surfaceCardBorder),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 36,
              height: 50,
              child: Center(
                child: WishRoomCandle(size: 30, color: WishRoomColors.glow),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    wish.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'GowunBatangWish',
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: WishRoomColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${days < 0 ? 0 : days}일째 밝히는 중',
                    style: TextStyle(
                      fontFamily: 'IBMPlexMonoWish',
                      fontSize: 10,
                      letterSpacing: 1.5,
                      color: WishRoomColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: onTapSeal,
              borderRadius: BorderRadius.circular(15),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: WishRoomSeal(
                  text: seal.glyph,
                  color: WishRoomColors.accent,
                  size: 30,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 디자인 자체 BottomNav(3탭: 🕯나의소원/☾모두의소원/◈기록).
///
/// [하단바 원칙] 앱 전역 AppShell 5탭 바(과거 사용자가 명시적으로
/// "건드리지 말라"고 지시한 대상)와는 완전히 별개다. 이 화면은 메인화면
/// "소원방" 카드를 탭해 push되는 독립된 전체 화면이므로 AppShell 탭바는
/// 이 화면에 표시되지 않으며, 여기 그려지는 것은 디자인 원본에 포함된
/// 이 화면 "자체"의 장식/네비게이션 바다(디자인 그대로 재현).
class _WishRoomBottomNav extends StatelessWidget {
  const _WishRoomBottomNav({
    required this.onHome,
    required this.onFeed,
    required this.onRecord,
  });

  final VoidCallback onHome;
  final VoidCallback onFeed;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    final items = <(String icon, String label, VoidCallback onTap, bool active)>[
      ('🕯', '나의 소원', onHome, true),
      ('☾', '모두의 소원', onFeed, false),
      ('◈', '기록', onRecord, false),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            WishRoomColors.backgroundDeep.withValues(alpha: 0.9),
          ],
          stops: const [0.0, 0.4],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: items.map((it) {
          final color = it.$4
              ? WishRoomColors.glow
              : WishRoomColors.textSecondary;
          return InkWell(
            onTap: it.$3,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(it.$1, style: TextStyle(fontSize: 18, color: color)),
                  const SizedBox(height: 4),
                  Text(
                    it.$2,
                    style: TextStyle(
                      fontFamily: 'GowunBatangWish',
                      fontSize: 10,
                      fontWeight: it.$4 ? FontWeight.w700 : FontWeight.w400,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// FAB: 58x58 원, glow bg, '+' (Noto Serif KR 900 26px, #3a2515).
class _ComposeFab extends StatelessWidget {
  const _ComposeFab({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(29),
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: WishRoomColors.glow,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: WishRoomColors.glowShadow,
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.08),
              blurRadius: 0,
              spreadRadius: 4,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: const Text(
          '+',
          style: TextStyle(
            fontFamily: 'NotoSerifKRWish',
            fontWeight: FontWeight.w900,
            fontSize: 26,
            color: Color(0xFF3A2515),
            height: 1.0,
          ),
        ),
      ),
    );
  }
}
