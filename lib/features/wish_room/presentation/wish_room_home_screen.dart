import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../application/wish_wall_provider.dart';
import '../domain/wish_wall_models.dart';
import '../theme/wish_room_theme.dart';
import '../widgets/blessing_bag_bottom_sheet.dart';
import '../../shop/domain/shop_item_visuals.dart';
import '../widgets/wish_room_candle.dart';
import '../widgets/wish_room_dust.dart';
import '../widgets/wish_room_seal.dart';
import '../widgets/wish_room_sigil.dart';
import 'wish_room_box_opening_screen.dart';
import 'wish_room_celebration_screen.dart';
import 'wish_room_compose_screen.dart';
import 'wish_room_detail_screen.dart';
import 'wish_room_empty_screen.dart';
import 'wish_room_feed_screen.dart';
import 'wish_room_onboarding_screen.dart';
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
  const WishRoomHomeScreen({
    super.key,
    this.showEmptyScreenIfEmpty = false,
    this.checkBoxOpening = false,
  });

  /// [Phase 01 · 2단계 · orphan 화면 연결] true면 로딩 완료 후 소원이
  /// 0개일 때 이 화면 대신 전체화면 [WishRoomEmptyScreen]을 보여준다.
  /// [WishRoomEntryGate]가 "온보딩을 방금 처음 통과한 경우"에만 true를
  /// 넘긴다 — 그 외(이미 온보딩을 봤던 기존 사용자)는 지금까지처럼
  /// 아래 [_WishListSection]의 축소된 인라인 빈 상태를 그대로 사용한다.
  final bool showEmptyScreenIfEmpty;

  /// [Phase 01 · 2단계 · orphan 화면 연결] true면 [initState]에서
  /// [findPendingBoxOpeningWishId]로 100일 지난 소원이 있는지 확인하고,
  /// 있으면 07 [WishRoomBoxOpeningScreen]을 자동으로 push한다(완료 후
  /// 08 Celebration으로 체이닝).
  ///
  /// [기본값 false — 과거 버그 재발 방지] `AppShell`의 `IndexedStack`은
  /// 5탭을 앱 시작 시점에 전부 미리 생성한다. 만약 이 체크가 기본으로
  /// 켜져 있었다면, 사용자가 "소원방" 탭을 누르지도 않았는데 다른 탭을
  /// 보고 있는 상태에서 전체화면 개봉 연출이 `Navigator.push`로 갑자기
  /// 튀어나오는 — 과거에 고쳤던 "자동 복주머니 지급" 버그와 동일한 종류의
  /// 문제가 재발한다. 그래서 기본값은 false로 두고, [WishRoomEntryGate]가
  /// (사용자가 실제로 소원방 카드/라우트를 눌러 이 화면을 push로 생성한
  /// 경우에만) true로 명시적으로 켠다. `AppShell`의 탭 인스턴스는 지금까지
  /// 처럼 플래그 없이(false) 그대로 둔다.
  final bool checkBoxOpening;

  @override
  State<WishRoomHomeScreen> createState() => _WishRoomHomeScreenState();
}

class _WishRoomHomeScreenState extends State<WishRoomHomeScreen> {
  // [STEP05-B 마무리 — FAB 전용 레이아웃 공간 예약]
  // 네비게이션 바 자체 높이(상단 패딩10 + 아이콘18~/라벨10 텍스트 컬럼
  // ~40 + 하단 패딩18 ≈ 78px 실측 근사치) 아래에, FAB(58px 지름) +
  // bottom 오프셋(24px)이 완전히 들어가려면 최소 82px가 필요하다. 네비
  // 바와 FAB 오프셋 두 값 중 더 큰 쪽을 기준으로 여유를 더해 안전하게
  // 확보한다 — 네비 바 실측 높이(~78)와 FAB 필요 높이(58+24=82) 중
  // 최댓값에 8px 여유를 더한 값을 사용해, 어떤 폰트 크기/화면 밀도에서도
  // FAB가 네비 바 영역을 벗어나 스크롤 콘텐츠를 침범하지 않게 한다.
  static const double _fabZoneHeight = 90;

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

      // [Phase02-A 클라이언트 연동] checkBoxOpening이 true일 때만
      // (=WishRoomEntryGate를 통해 실제로 진입했을 때만) 서버
      // `GET /wishes/pending-openings`를 조회해 07 개봉 화면을 자동으로
      // 띄운다. 이전에는 createdAt+100일 로컬 근사치(SharedPreferences
      // 기록)로 판정했으나, Phase02-A에서 서버 unlockAt/openedBoxAt 필드가
      // 생겼으므로 서버 판정을 그대로 신뢰한다(기기를 바꿔도 유지되고,
      // 관리자가 원장을 확인할 수 있음). widget.key가 바뀌지 않는 한 이
      // initState는 이 화면 인스턴스당 1회만 실행된다.
      if (widget.checkBoxOpening) {
        final pending = await provider.fetchPendingBoxOpenings();
        if (pending.isNotEmpty && mounted) {
          // 서버가 sealedAt asc 정렬로 내려주므로 첫 항목이 가장 오래된 것.
          final wish = pending.first;
          final ageDays = DateTime.now().difference(wish.createdAt).inDays;
          // [소원방 마무리 - Phase B] 서버가 이 호출 트랜잭션 안에서
          // wish_100days(+30, 소원당 1회)까지 확정 지급하므로 그 금액을
          // 07 개봉 화면에 그대로 전달해 안내한다.
          final grantedWish100Days = await provider.markBoxOpened(wish.id);
          if (!mounted) return;
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => WishRoomBoxOpeningScreen(
                wishAgeDays: ageDays,
                wish100DaysGrantedAmount: grantedWish100Days,
              ),
            ),
          );
          if (!mounted) return;
          // 완료 후 08 Celebration으로 체이닝(문서 §2단계 표: "완료 후
          // Celebration으로 chain").
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => WishRoomCelebrationScreen(
                wishText: wish.text,
                daysToFulfill: ageDays,
              ),
            ),
          );
        }
      }
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

  /// [상점(Shop) 진입점 — Phase02-B 최소 침습 통합] bokjumeoni-plan §03
  /// 상점(인장/촛불/부적) + 보물함 신설. 디자인 원본에는 상점 진입 버튼이
  /// 없었으나, 복주머니 시스템과 마찬가지로 헤더의 ☾ 버튼과 동일한 40px
  /// 원형 아이콘 버튼 스타일로 그 왼쪽에 하나만 추가한다(레이아웃을 깨지
  /// 않는 범위). 4개 상점 화면 중 첫 화면(인장 상점)으로 진입하며, 나머지
  /// 3화면은 [ShopSubNav]로 서로 전환한다.
  void _openShop() {
    Navigator.of(context).pushNamed('/shop/seals');
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

  /// [STEP03 — 소원방 핵심 UX 재설계] "이용안내" 재진입 버튼.
  ///
  /// [wishRoomOnboardingSeenPrefsKey 불변 원칙] 이 버튼은 온보딩 화면을
  /// 단순히 다시 "보여주기"만 할 뿐, [markWishRoomOnboardingSeen]을
  /// 호출하지 않는다 — 이미 이 화면(홈)에 도달했다는 것 자체가 온보딩을
  /// 이미 통과했다는 뜻이므로 seen 상태를 다시 건드릴 이유가 없다.
  /// onEnter/onHaveAccount 콜백은 [WishRoomEntryGate]처럼 상태를 저장하지
  /// 않고 단순히 이 화면을 닫기만 한다(순수 재열람).
  void _openOnboardingReview() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WishRoomOnboardingScreen(
          onEnter: () => Navigator.of(context).pop(),
          onHaveAccount: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  /// [STEP03 — 오늘의 소원 활동 · 촛불 켜기] 새 보상정책을 만들지 않고
  /// 기존 서버 정책(daily_candle, +1, 1일 1회)만 그대로 호출한다.
  Future<void> _handleTodayCandle() async {
    final policy = context.read<WishWallProvider>().policy;
    final granted = await policy.earnDailyCandleBonus();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          granted > 0 ? '오늘의 촛불을 켰어요 (+$granted 🎁)' : '오늘은 이미 촛불을 켰어요',
        ),
      ),
    );
  }

  /// [STEP03 — 오늘의 소원 활동 · 응원하기] 기존 무료 응원
  /// ([WishWallProvider.support], 상세 화면과 동일 액션)을 그대로 재사용한다.
  Future<void> _handleTodaySupport(WishPost wish) async {
    if (wish.hasSupportedByMe) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('오늘은 이미 이 소원에 정성을 더했어요'),
        ),
      );
      return;
    }
    await context.read<WishWallProvider>().support(wish.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('소원에 응원을 보냈어요 💛'),
      ),
    );
  }

  /// [STEP03 — 오늘의 소원 활동 · 복주머니 사용] 강조된 나의 소원이 있으면
  /// 그 소원에 "보내기"를, 없으면 "받기" 팝업을 연다 — 기존
  /// [_openBlessingBagSend]/[_openBlessingBagReceive]를 그대로 재사용한다.
  Future<void> _handleTodayPouch(WishPost? wish) async {
    if (wish != null) {
      await _openBlessingBagSend(wish);
    } else {
      await _openBlessingBagReceive();
    }
  }

  /// [STEP03 — 다중 소원 시 강조 대상 선정] "가장 최근/진행 중인 소원"을
  /// 메인으로 강조한다(사용자 지시 §12) — 임의 삭제/숨김 없이 정렬 우선순위만
  /// 사용한다. 우선순위: (1) 아직 이루어지지도/보관되지도 않은 진행중(sealed)
  /// 소원 중 가장 최근 것 → (2) 그런 소원이 없으면 전체 중 가장 최근 것.
  WishPost? _selectHighlightWish(List<WishPost> wishes) {
    if (wishes.isEmpty) return null;
    final sealedOnes = wishes.where((w) => w.wishState == 'sealed').toList();
    final pool = sealedOnes.isNotEmpty ? sealedOnes : wishes;
    return pool.reduce((a, b) => a.createdAt.isAfter(b.createdAt) ? a : b);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WishWallProvider>();
    final wishes = provider.myWishes;
    final balance = provider.policy.balance;

    // [Phase 01 · 2단계 · orphan 화면 연결] 온보딩 직후 첫 진입인데(=
    // showEmptyScreenIfEmpty) 로딩이 끝났고 소원이 정말 0개라면, 축소된
    // 인라인 빈 상태 대신 02 Empty 전체화면을 강조해서 보여준다.
    if (widget.showEmptyScreenIfEmpty &&
        !provider.isLoading &&
        wishes.isEmpty) {
      return WishRoomEmptyScreen(onCompose: _openCompose);
    }

    final wishCount = wishes.length;
    int totalDays = 0;
    if (wishes.isNotEmpty) {
      final earliest = wishes
          .map((w) => w.createdAt)
          .reduce((a, b) => a.isBefore(b) ? a : b);
      totalDays = DateTime.now().difference(earliest).inDays;
      if (totalDays < 0) totalDays = 0;
    }

    final highlightWish = _selectHighlightWish(wishes);

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
                  // [STEP7 — 320px + textScale≥1.3 FAB-전역 네비게이션
                  // 겹침 버그 근본 수정] 과거에는 _HomeHeader/_CandleAltar가
                  // Column의 "고정(non-flex)" 형제였다. textScale이 커지면
                  // 이 두 위젯의 텍스트 렌더링 높이가 함께 커지는데, 고정
                  // 영역(헤더+제단+20+_fabZoneHeight)의 합이 320×568 같은
                  // 작은 뷰포트에서 화면 높이를 초과하면 Expanded가 0 아래로
                  // 줄어들 수 없어 Column 전체가 overflow된다. release
                  // 빌드는 이 overflow를 클리핑하지 않고 그대로 그리므로,
                  // Column의 마지막 자식인 FAB존이 화면 밖(앱 전역
                  // BottomNavigationBar 영역)까지 밀려나 겹쳐 보였다
                  // (실제 캡처 wr_320_ts13.png / crop_fab_320_ts13.png로
                  // 확인).
                  //
                  // [해결] 헤더와 제단도 이미 존재하는 스크롤 영역
                  // (_WishListSection의 CustomScrollView, 바로 위 주석에
                  // 적힌 것과 동일한 이유로 하이라이트 카드를 스크롤 영역에
                  // 넣었던 선례)에 슬리버로 편입시킨다. 이렇게 하면
                  // Column에는 Expanded(스크롤 영역) 하나와 고정
                  // _fabZoneHeight 하나만 남고, textScale이 얼마나 커지든
                  // 텍스트는 스크롤 영역 안에서 더 스크롤되기만 할 뿐 FAB존
                  // 높이를 침범하지 않는다(FAB존은 항상 화면 안, 항상 같은
                  // 위치).
                  Expanded(
                    child: _WishListSection(
                      balance: balance,
                      wishCount: wishCount,
                      totalDays: totalDays,
                      onOpenMoon: _openFullBoard,
                      onOpenPouch: _openBlessingBagReceive,
                      onOpenShop: _openShop,
                      onOpenGuide: _openOnboardingReview,
                      wishes: wishes,
                      isLoading: provider.isLoading,
                      onSeeAll: _openMy,
                      onTapWish: _openDetail,
                      onTapSeal: _openBlessingBagSend,
                      highlightWish: highlightWish,
                      onCandle: _handleTodayCandle,
                      onSupport: highlightWish == null
                          ? null
                          : () => _handleTodaySupport(highlightWish),
                      onPouch: () => _handleTodayPouch(highlightWish),
                    ),
                  ),
                  // [STEP05-B 마무리 — 320px FAB 겹침 버그 구조적 해결]
                  //
                  // [1차 시도(실패) 기록] FAB를 전체 화면 Stack 절대좌표
                  // (bottom:100)에서, 하단 네비게이션 바와 같은 로컬
                  // Stack(clipBehavior: Clip.none)으로 옮겼었다. 그러나
                  // 이 방식은 실패했다 — Clip.none인 Stack은 자신의 박스
                  // 높이(네비 바 자체 높이, ~90px)를 넘어서는 FAB(58px +
                  // bottom:76 오프셋 = 134px 필요)를 "레이아웃 공간
                  // 확보 없이 그림만 오버플로우"시킨다. Column은 형제를
                  // 순서대로 그리므로, 이 Stack이 바로 위 형제인
                  // Expanded(스크롤 영역)의 그려진 하단 일부 위에 겹쳐
                  // 페인팅되어 버그가 전혀 해결되지 않았다(재검증
                  // 스크린샷으로 확인).
                  //
                  // [최종 해결] 로컬 Stack을 고정 높이 SizedBox로 감싸,
                  // FAB(58px)와 그 bottom 오프셋(24px)을 모두 포함하는
                  // 충분한 높이(_fabZoneHeight)를 명시적으로 부여한다.
                  // 이렇게 하면 FAB가 이 SizedBox "내부"에 완전히
                  // 들어가고(오버플로우 없음), Column의 정식 레이아웃
                  // 계산에서 이 높이만큼이 실제로 차지되어 Expanded가
                  // 정확히 그만큼 줄어든다 — 즉 FAB 전용 공간이 진짜로
                  // "예약"되므로, 화면 크기와 무관하게 스크롤 콘텐츠와
                  // FAB가 서로 다른 레이아웃 영역에 격리된다. (텍스트
                  // 숨김/배지 삭제/FAB 축소/폭 기반 분기 없이 위치 구조
                  // 자체를 수정한 것 — 320/360/390 전 구간에서 동일하게
                  // 안전하다.)
                  SizedBox(
                    height: _fabZoneHeight,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: _WishRoomBottomNav(
                            onHome: () {},
                            onFeed: _openFullBoard,
                            onRecord: _openMy,
                          ),
                        ),
                        Positioned(
                          right: 20,
                          bottom: 24,
                          child: _ComposeFab(onPressed: _openCompose),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
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
    required this.onOpenShop,
    this.onOpenGuide,
  });
  final int balance;
  final VoidCallback onOpenMoon;
  final VoidCallback onOpenPouch;
  final VoidCallback onOpenShop;

  /// [STEP03 — 이용안내 재진입] null이면 버튼을 렌더링하지 않는다(호출부
  /// 미전달 시 헤더 레이아웃을 그대로 유지하기 위한 안전장치).
  final VoidCallback? onOpenGuide;

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
                if (onOpenGuide != null) ...[
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: onOpenGuide,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '❔ 소원방 이용안내',
                        style: TextStyle(
                          fontSize: 11,
                          color: WishRoomColors.textSecondary,
                          decoration: TextDecoration.underline,
                          decorationColor: WishRoomColors.textSecondary
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          _PouchBalanceChip(balance: balance, onTap: onOpenPouch),
          const SizedBox(width: 8),
          InkWell(
            onTap: onOpenShop,
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
              child: const Text('🎐', style: TextStyle(fontSize: 16)),
            ),
          ),
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
///
/// [STEP03 — 접근성/안정성 개선] 이 섹션은 이제 단순 리스트가 아니라,
/// 상단에 "나의 소원 강조 카드"와 "오늘의 소원 활동"까지 함께 스크롤되는
/// 하나의 [CustomScrollView]로 구성한다 — 고정 높이 영역에 몰아넣지 않고
/// 전체를 스크롤 가능하게 만들어 작은 화면/큰 글씨 설정에서도 콘텐츠가
/// 화면 밖으로 잘리지 않도록 한다(사용자 지시 §14 접근성/안정성).
class _WishListSection extends StatefulWidget {
  const _WishListSection({
    required this.balance,
    required this.wishCount,
    required this.totalDays,
    required this.onOpenMoon,
    required this.onOpenPouch,
    required this.onOpenShop,
    this.onOpenGuide,
    required this.wishes,
    required this.isLoading,
    required this.onSeeAll,
    required this.onTapWish,
    required this.onTapSeal,
    this.highlightWish,
    this.onCandle,
    this.onSupport,
    this.onPouch,
  });

  // [STEP7 — FAB 겹침 버그 수정] 헤더/제단을 이 스크롤 영역의 슬리버로
  // 편입시키기 위해 필요한 값들. 위 build() 상단의 [근본 수정] 주석 참고.
  final int balance;
  final int wishCount;
  final int totalDays;
  final VoidCallback onOpenMoon;
  final VoidCallback onOpenPouch;
  final VoidCallback onOpenShop;
  final VoidCallback? onOpenGuide;

  final List<WishPost> wishes;
  final bool isLoading;
  final VoidCallback onSeeAll;
  final ValueChanged<WishPost> onTapWish;
  final ValueChanged<WishPost> onTapSeal;

  /// [STEP03] 강조 카드에 표시할 소원(가장 최근/진행중). null이면 강조
  /// 카드와 "오늘의 소원 활동" 섹션 자체를 표시하지 않는다(소원이 0개인
  /// 경우 등).
  final WishPost? highlightWish;
  final VoidCallback? onCandle;
  final VoidCallback? onSupport;
  final VoidCallback? onPouch;

  @override
  State<_WishListSection> createState() => _WishListSectionState();
}

class _WishListSectionState extends State<_WishListSection> {
  // [STEP7 진단용 — 사용자 지시 개발자 지시서 ① 최종본] 실제 Flutter
  // Scrollable(이 CustomScrollView)의 ScrollController.offset이 사용자
  // 스크롤 동작 전/후로 실제로 변하는지 직접 확인하기 위한 임시 컨트롤러다.
  // STEP 7 PASS 확정 전까지만 유지하며, PASS 후 반드시 제거한다.
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      // ignore: avoid_print
      print(
        '[STEP7스크롤진단] offset=${_scrollController.offset.toStringAsFixed(1)} '
        'max=${_scrollController.position.maxScrollExtent.toStringAsFixed(1)}',
      );
    });
    // [STEP7 진단용] addListener는 offset이 "변경"될 때만 호출되므로,
    // 최초 마운트 시점의 초기 상태(스크롤 발생 여부와 무관하게)를
    // 강제로 한 번 출력해 컨트롤러가 실제로 attach 되었는지 확인한다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scrollController.hasClients) {
        // ignore: avoid_print
        print(
          '[STEP7스크롤진단-초기] attached=true offset='
          '${_scrollController.offset.toStringAsFixed(1)} '
          'max=${_scrollController.position.maxScrollExtent.toStringAsFixed(1)}',
        );
      } else {
        // ignore: avoid_print
        print('[STEP7스크롤진단-초기] attached=false (컨트롤러가 어떤 Scrollable에도 연결되지 않음)');
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverToBoxAdapter(
          child: _HomeHeader(
            balance: widget.balance,
            onOpenMoon: widget.onOpenMoon,
            onOpenPouch: widget.onOpenPouch,
            onOpenShop: widget.onOpenShop,
            onOpenGuide: widget.onOpenGuide,
          ),
        ),
        SliverToBoxAdapter(
          child: _CandleAltar(
            wishCount: widget.wishCount,
            totalDays: widget.totalDays,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
        if (widget.highlightWish != null) ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            sliver: SliverToBoxAdapter(
              child: _MyWishHighlightCard(
                wish: widget.highlightWish!,
                onTap: () => widget.onTapWish(widget.highlightWish!),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            sliver: SliverToBoxAdapter(
              child: _TodayWishActions(
                onCandle: widget.onCandle ?? () {},
                onSupport: widget.onSupport ?? () {},
                onPouch: widget.onPouch ?? () {},
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
          sliver: SliverToBoxAdapter(
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
                  onTap: widget.onSeeAll,
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
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        if (widget.isLoading && widget.wishes.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: CircularProgressIndicator(color: WishRoomColors.accent),
            ),
          )
        else if (widget.wishes.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
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
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            sliver: SliverList.separated(
              itemCount: widget.wishes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final wish = widget.wishes[index];
                return _WishListRow(
                  wish: wish,
                  onTap: () => widget.onTapWish(wish),
                  onTapSeal: () => widget.onTapSeal(wish),
                );
              },
            ),
          ),
      ],
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
    // [복주머니 확장 Phase03 - 인장/촛불 실사용 연결] 실제 구매해 선택한
    // 인장/촛불이 있으면 그 시각을 쓰고, 없으면 기존 카테고리 기본값을 쓴다.
    final sealGlyph = wish.sealItemCode != null
        ? sealVisualFor(wish.sealItemCode!).glyph
        : seal.glyph;
    final candleColor = wish.candleItemCode != null
        ? candleColorFor(wish.candleItemCode!)
        : WishRoomColors.glow;
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
                child: WishRoomCandle(size: 30, color: candleColor),
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
                  Row(
                    children: [
                      Text(
                        '${days < 0 ? 0 : days}일째 밝히는 중',
                        style: const TextStyle(
                          fontFamily: 'IBMPlexMonoWish',
                          fontSize: 10,
                          letterSpacing: 1.5,
                          color: WishRoomColors.textSecondary,
                        ),
                      ),
                      // [복주머니 확장 Phase03 — 지킴 부적 보호 배지,
                      // DECISION-004 합리적 판단] 자동 지급 없이 "적용 중"
                      // 표시로만 실사용 의미를 부여한다. "지킴 보호"라는
                      // 문맥 자체가 guardian 부적 전용 의미이므로, 조건은
                      // 그대로 'talisman_guardian'만 유지한다(다른 2종
                      // 부적까지 배지를 확장하는 것은 새 기능 추가에
                      // 해당하므로 이번 STEP05-B 마무리 범위에서 하지
                      // 않는다).
                      // [STEP05-B 마무리 — 하드코딩 아이콘 제거] 과거에는
                      // '🛡️' 문자를 직접 하드코딩해 CanvasKit에서 회색
                      // 실루엣 버그가 발생했다. 이제 다른 화면
                      // (_MyWishHighlightCard의 _TalismanAmbientBadge)과
                      // 완전히 동일한 talismanVisualFor() 매핑을 사용해,
                      // 화면마다 아이콘이 다르게 보이는 불일치 없이 항상
                      // 정상 렌더링되는 🧿로 표시한다.
                      if (wish.talismanItemCode == 'talisman_guardian') ...[
                        const SizedBox(width: 6),
                        Text(
                          talismanVisualFor(wish.talismanItemCode!).icon,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ],
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
                  text: sealGlyph,
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
    final items =
        <(String icon, String label, VoidCallback onTap, bool active)>[
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ...items.map((it) {
            final color = it.$4
                ? WishRoomColors.glow
                : WishRoomColors.textSecondary;
            return InkWell(
              onTap: it.$3,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
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
          }),
          // FAB(58px, right:20)가 세 번째 네비 항목('기록')과 겹치지 않도록
          // 그 폭만큼 실제 레이아웃 공간을 예약한다(자르기/숨기기 아님).
          const SizedBox(width: 58),
        ],
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

// ============================================================
// [STEP03 — 소원방 핵심 UX 재설계] 나의 소원 강조 카드 + 오늘의 소원 활동
// ============================================================
//
// [작업 범위 원칙] 이 두 위젯은 오직 "표시"만 담당한다 — DB/API/모델을
// 절대 변경하지 않고, 서버가 이미 채워준 WishPost 필드(text/wishState/
// sealedAt/unlockAt/supportCount/pouchCount/sealItemCode/candleItemCode/
// talismanItemCode)만 읽어서 UI를 구성한다. wishState 문자열 값 자체는
// 절대 바꾸지 않고, 여기서는 오직 "감성 문구로의 매핑"만 수행한다.

/// [STEP03 §7] 소원 상태별 감성 문구 매핑. DB의 wishState 원시값(sealed/
/// fulfilled/archived)은 그대로 유지하며, 이 함수는 표시용 변환만 한다.
/// "100일 임박"은 wishState와 별개의 파생 조건(unlockAt까지 7일 이내)이며,
/// 서버가 100일을 재계산하는 게 아니라 클라이언트가 "표시용으로만" 판단한다.
String wishStateEmotionalLabel(WishPost wish) {
  switch (wish.wishState) {
    case 'fulfilled':
      return '🌸 소원이 이루어졌어요';
    case 'archived':
      return '📦 소원함에 간직하고 있어요';
    case 'sealed':
    default:
      final unlock = wish.unlockAt;
      if (unlock != null) {
        final remaining = unlock.difference(DateTime.now()).inDays;
        if (remaining <= 7 && remaining >= 0) {
          return '✨ 소원함이 곧 열려요';
        }
      }
      return '🌱 소원이 잘 자라고 있어요';
  }
}

/// [STEP03 §6] 표시용 진행률(0.0~1.0) 계산 — 서버 sealedAt/unlockAt을
/// 그대로 신뢰하며 100일을 재계산하지 않는다. 둘 중 하나라도 null이면(예:
/// Mock 데이터, 구버전 소원) 앱이 죽지 않도록 null을 반환해 호출부가
/// "진행률 알 수 없음" 상태를 표시하게 한다.
({int elapsedDays, int totalDays, int remainingDays, double ratio})?
_wishProgress(WishPost wish) {
  final sealed = wish.sealedAt;
  final unlock = wish.unlockAt;
  if (sealed == null || unlock == null) return null;
  final total = unlock.difference(sealed).inDays;
  if (total <= 0) return null;
  var elapsed = DateTime.now().difference(sealed).inDays;
  if (elapsed < 0) elapsed = 0;
  if (elapsed > total) elapsed = total;
  final remaining = total - elapsed;
  final ratio = (elapsed / total).clamp(0.0, 1.0);
  return (
    elapsedDays: elapsed,
    totalDays: total,
    remainingDays: remaining,
    ratio: ratio,
  );
}

/// "나의 소원" 강조 카드 — 홈 화면에서 가장 최근/진행 중인 소원 하나를
/// 크게 보여준다(사용자 지시 §4/§6/§7/§12).
///
/// [정보 우선순위 — 사용자 지시 §13] 1.소원내용 2.소원상태 3.남은기간
/// 4.촛불 5.응원 6.받은복주머니 7.사용아이템 순으로 배치한다. 숫자만
/// 나열하지 않고 소원 내용(text)이 항상 최상단에 가장 크게 보이도록 한다.
///
/// [애니메이션 — 최소화 원칙] 카드 자체는 진입 시 미세한 fade+slide만
/// 적용한다(화려한 파티클/사운드는 이번 STEP 범위 밖).
class _MyWishHighlightCard extends StatefulWidget {
  const _MyWishHighlightCard({required this.wish, required this.onTap});

  final WishPost wish;
  final VoidCallback onTap;

  @override
  State<_MyWishHighlightCard> createState() => _MyWishHighlightCardState();
}

class _MyWishHighlightCardState extends State<_MyWishHighlightCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wish = widget.wish;
    final progress = _wishProgress(wish);
    final stateLabel = wishStateEmotionalLabel(wish);

    return AnimatedBuilder(
      animation: _entrance,
      builder: (context, child) {
        final t = Curves.easeOut.transform(_entrance.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 12),
            child: child,
          ),
        );
      },
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: WishRoomColors.surfaceCard,
            border: Border.all(
              color: WishRoomColors.glow.withValues(alpha: 0.4),
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: WishRoomColors.glowShadow.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // eyebrow: "나의 소원" 타이틀 라벨.
              Row(
                children: [
                  const Text(
                    '나의 소원',
                    style: TextStyle(
                      fontFamily: 'IBMPlexMonoWish',
                      fontSize: 10,
                      letterSpacing: 2.0,
                      color: WishRoomColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  // [STEP05-A §8] 부적 장착 시 은은한 기운 배지. 기존
                  // 'talisman_guardian' 단일 하드코딩(🛡️ 텍스트만) 대신
                  // talismanVisualFor()로 3종(수호/만월/인연) 전체를
                  // 대응시키고, 살짝 숨쉬듯 은은하게 빛나는 pulsing 효과를
                  // 얹는다(§19 "평상시는 편안하고 신비롭게" — 화려하지
                  // 않게, 늘 은은한 밝기 변화만).
                  if (wish.talismanItemCode != null)
                    _TalismanAmbientBadge(
                      visual: talismanVisualFor(wish.talismanItemCode!),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              // [STEP05-A §5/§8] 미니 제단 스트립 — 이 소원에 실제로
              // 장착된 촛불/인장을 "보이는 효과"로 표시한다. 기존
              // WishRoomCandle(flicker 애니메이션 그대로 재사용)과
              // WishRoomSeal(도장 위젯 그대로 재사용)을 조합할 뿐, 새
              // 위젯/색상 시스템을 만들지 않는다. 아래 4~6번 지표
              // 텍스트("🕯 켜짐" 등)는 그대로 유지 — 이 스트립은 그
              // 정보를 대체하지 않고 시각적으로 보강만 한다.
              _AltarStrip(wish: wish),
              const SizedBox(height: 12),
              // 1. 소원 내용 — 최우선 표시, 2줄까지 허용 후 ellipsis.
              Text(
                wish.text.isNotEmpty ? wish.text : '(소원 내용 없음)',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'GowunBatangWish',
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  height: 1.4,
                  color: WishRoomColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              // 2. 소원 상태 감성 문구.
              Text(
                stateLabel,
                style: const TextStyle(
                  fontSize: 13,
                  color: WishRoomColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              // 3. 남은기간/진행률 — sealedAt/unlockAt 둘 다 있을 때만 표시.
              // [STEP05-A §7] 숫자 퍼센트/막대만 보여주던 것을 "성장하는
              // 느낌"의 5단계 트랙(🌱→🌿→🌳→✨→🌸)으로 확장한다. 실제
              // 진행률 계산([_wishProgress], 서버 sealedAt/unlockAt 기준)은
              // 절대 변경하지 않고, 기존 LinearProgressIndicator는 그대로
              // 유지한 채 그 위에 성장 단계 라벨만 추가한다(§9 — 이 성장
              // 표현은 소원 성취 "확률"이 아니라 단순 시간 경과에 대한
              // 감성적 표현일 뿐임을 라벨 문구로도 명확히 한다).
              if (progress != null) ...[
                _GrowthStageTrack(ratio: progress.ratio),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress.ratio,
                    minHeight: 6,
                    backgroundColor: WishRoomColors.surfaceCardBorder,
                    valueColor: const AlwaysStoppedAnimation(
                      WishRoomColors.glow,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  progress.remainingDays > 0
                      ? '${progress.elapsedDays}일째 · ${progress.remainingDays}일 남았어요'
                      : '${progress.elapsedDays}일째 · 곧 열 수 있어요',
                  style: const TextStyle(
                    fontFamily: 'IBMPlexMonoWish',
                    fontSize: 10,
                    letterSpacing: 1.0,
                    color: WishRoomColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
              ] else
                const SizedBox(height: 4),
              // 4~6. 촛불/응원/받은 복주머니 — 작은 지표 3개를 한 행에.
              // [WishPost에 별도 "촛불 개수" 필드가 없으므로] 봉인된 소원은
              // 항상 촛불 하나가 켜져 있다는 상태 텍스트로 표시한다(숫자
              // 나열보다 의미 전달 우선 — 사용자 지시 §13).
              Row(
                children: [
                  const _HighlightMetric(icon: '🕯', value: '켜짐', label: '촛불'),
                  const SizedBox(width: 16),
                  _HighlightMetric(
                    icon: '💛',
                    value: '${wish.supportCount}',
                    label: '응원',
                  ),
                  const SizedBox(width: 16),
                  _HighlightMetric(
                    icon: '🎁',
                    value: '${wish.pouchCount}',
                    label: '복주머니',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 강조 카드 내부 작은 지표(아이콘+숫자+라벨) — 게임화(랭킹/경쟁) 느낌을
/// 주지 않도록 담담한 회색조 텍스트로만 표시한다(사용자 지시 §9 게임화 금지).
class _HighlightMetric extends StatelessWidget {
  const _HighlightMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  final String icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: const TextStyle(fontSize: 13)),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'IBMPlexMonoWish',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: WishRoomColors.textPrimary,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: WishRoomColors.textTertiary,
          ),
        ),
      ],
    );
  }
}

/// "오늘의 소원 활동" 섹션 — 촛불켜기/응원하기/복주머니사용 3개 액션.
///
/// [절대 원칙 — 사용자 지시 §7] 새 보상정책/화폐를 생성하지 않는다. 각
/// 버튼은 기존 서버 정책(daily_candle)과 기존 화면 액션(support,
/// blessing bag bottom sheet)에만 연결된다. 강제 미션처럼 보이지 않도록
/// 버튼 3개만 담담하게 배치하고 진행률/보상 확률 등은 표시하지 않는다.
class _TodayWishActions extends StatelessWidget {
  const _TodayWishActions({
    required this.onCandle,
    required this.onSupport,
    required this.onPouch,
  });

  final VoidCallback onCandle;
  final VoidCallback onSupport;
  final VoidCallback onPouch;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '오늘의 소원 활동',
          style: TextStyle(
            fontFamily: 'GowunBatangWish',
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: WishRoomColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _TodayActionButton(
                icon: '🕯',
                label: '촛불 켜기',
                onTap: onCandle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TodayActionButton(
                icon: '💛',
                label: '응원하기',
                onTap: onSupport,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TodayActionButton(
                icon: '🎁',
                label: '복주머니',
                onTap: onPouch,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TodayActionButton extends StatelessWidget {
  const _TodayActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: WishRoomColors.surfaceCard,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: WishRoomColors.surfaceCardBorder),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'GowunBatangWish',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: WishRoomColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// [STEP05-A — 소원방 홈 제단 비주얼 개선] 미니 제단 스트립 / 부적 은은한
// 기운 배지 / 소원 성장 단계 트랙.
// ============================================================
//
// [작업 범위 원칙 — STEP05 지시서 §1/§9/§24 준수] 이 3개 위젯은 오직
// "표시"만 담당한다. wishState/sealedAt/unlockAt/sealItemCode/
// candleItemCode/talismanItemCode 등 서버 필드는 절대 변경하지 않고
// 읽기만 하며, 새 DB/API/화폐/보상정책을 만들지 않는다. 소원 성취
// "확률"을 의미하는 표현은 사용하지 않는다(§9) — 아래 성장 단계는 순수
// 시간 경과에 대한 감성적 표현일 뿐이다.

/// [STEP05-A §5/§8] 강조 카드 상단의 미니 제단 스트립.
///
/// 이 소원에 실제로 장착된 촛불([WishPost.candleItemCode])과 인장
/// ([WishPost.sealItemCode])을 "제단에 놓인 실물"처럼 나란히 보여준다.
/// 기존 [WishRoomCandle](flicker 애니메이션 포함)과 [WishRoomSeal](도장
/// 위젯)을 그대로 재사용하며, 새 색상/도형 시스템을 만들지 않는다 —
/// 색상/글리프 매핑은 기존 [candleColorFor]/[sealVisualFor]를 그대로
/// 사용한다(홈 리스트 행 `_WishListRow`에서 이미 쓰던 것과 동일 매핑).
///
/// 인장에는 미세한 breathing glow(은은한 밝기 변화)를 얹어 "살짝
/// 빛나는 효과"(지시서 §8 "인장" 섹션)를 표현한다 — 화려한 파티클이
/// 아니라 숨쉬듯 잔잔한 opacity 변화 정도로 제한한다(§19 "평상시는
/// 편안하고 신비롭게").
class _AltarStrip extends StatefulWidget {
  const _AltarStrip({required this.wish});
  final WishPost wish;

  @override
  State<_AltarStrip> createState() => _AltarStripState();
}

class _AltarStripState extends State<_AltarStrip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathe;

  @override
  void initState() {
    super.initState();
    // 은은한 breathing 주기 — 촛불 flicker(1.8s)보다 훨씬 느리게 돌려
    // "잔잔함"을 유지한다.
    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breathe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wish = widget.wish;
    final hasSeal = wish.sealItemCode != null;
    final hasCandle = wish.candleItemCode != null;
    // 촛불/인장이 모두 미장착이면(기본 상태) 스트립 자체를 생략해 화면을
    // 복잡하게 만들지 않는다 — §19 "일반 화면은 편안하게".
    if (!hasSeal && !hasCandle) return const SizedBox.shrink();

    final candleColor = hasCandle
        ? candleColorFor(wish.candleItemCode!)
        : WishRoomColors.glow;
    final sealGlyph = hasSeal ? sealVisualFor(wish.sealItemCode!).glyph : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: WishRoomColors.backgroundDeep.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: WishRoomColors.surfaceCardBorder.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasCandle) ...[
            SizedBox(
              width: 28,
              height: 46,
              child: Center(
                child: WishRoomCandle(size: 26, color: candleColor),
              ),
            ),
            const SizedBox(width: 10),
          ],
          if (hasSeal)
            AnimatedBuilder(
              animation: _breathe,
              builder: (context, child) {
                final glow = 0.5 + 0.5 * _breathe.value; // 0.5~1.0 은은한 변화
                return Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: WishRoomColors.accent.withValues(
                          alpha: 0.35 * glow,
                        ),
                        blurRadius: 14 * glow,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: child,
                );
              },
              child: WishRoomSeal(
                text: sealGlyph!,
                color: WishRoomColors.accent,
                size: 26,
              ),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hasCandle && hasSeal
                  ? '촛불과 인장이 소원을 지키고 있어요'
                  : hasCandle
                  ? '촛불이 소원을 밝히고 있어요'
                  : '인장이 소원을 지키고 있어요',
              style: const TextStyle(
                fontSize: 11,
                color: WishRoomColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// [STEP05-A §8 "부적"] 부적 장착 시 표시하는 은은한 배지.
///
/// 기존 하드코딩된 '🛡️' 단일 텍스트(talisman_guardian만 대응)를
/// [talismanVisualFor]로 교체해 상점에 있는 부적 3종(수호/만월/인연)
/// 전부를 대응시킨다. "제단 주변에 은은한 기운이 보이도록"(지시서 §8)을
/// 배지 주변의 부드러운 pulsing glow로 표현한다 — 등장/확대/원위치 같은
/// 1회성 연출은 "장착 순간" 피드백(STEP05-B 범위)이며, 이 배지는 항상
/// 표시되는 "장착 중" 상태이므로 반복되는 은은한 숨쉬기 효과만 사용한다.
class _TalismanAmbientBadge extends StatefulWidget {
  const _TalismanAmbientBadge({required this.visual});
  final ShopTalismanVisual visual;

  @override
  State<_TalismanAmbientBadge> createState() => _TalismanAmbientBadgeState();
}

class _TalismanAmbientBadgeState extends State<_TalismanAmbientBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final glow = 0.4 + 0.6 * _pulse.value;
        return Container(
          padding: const EdgeInsets.only(left: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.visual.color.withValues(alpha: 0.4 * glow),
                blurRadius: 10 * glow,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Text(widget.visual.icon, style: const TextStyle(fontSize: 13)),
    );
  }
}

/// [STEP05-A §7] 소원 진행률을 5단계 성장 트랙으로 표현.
///
/// 🌱(시작) → 🌿(자라는 중) → 🌳(무르익는 중) → ✨(100일 임박) →
/// 🌸(성취 가능) 5단계는 지시서 §7 예시를 그대로 사용한다. [ratio]는
/// 기존 [_wishProgress]가 계산한 sealedAt~unlockAt 기준 진행률(0.0~1.0)을
/// 그대로 받아 5구간으로 양자화할 뿐 — 별도의 진행률 계산 로직을
/// 새로 만들지 않는다. 현재 단계는 살짝 확대+glow로 강조하고 나머지는
/// 흐리게 표시해 "지금 어디쯤인지"를 한눈에 보여준다.
class _GrowthStageTrack extends StatelessWidget {
  const _GrowthStageTrack({required this.ratio});
  final double ratio;

  static const _stages = ['🌱', '🌿', '🌳', '✨', '🌸'];

  int _currentStageIndex() {
    final idx = (ratio * (_stages.length - 1)).round();
    return idx.clamp(0, _stages.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentStageIndex();
    return Row(
      children: List.generate(_stages.length, (i) {
        final isCurrent = i == current;
        final isPassed = i < current;
        final opacity = isCurrent ? 1.0 : (isPassed ? 0.7 : 0.28);
        return Expanded(
          child: Column(
            children: [
              AnimatedScale(
                scale: isCurrent ? 1.25 : 1.0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                child: AnimatedOpacity(
                  opacity: opacity,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    decoration: isCurrent
                        ? BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: WishRoomColors.glow.withValues(
                                  alpha: 0.5,
                                ),
                                blurRadius: 10,
                              ),
                            ],
                          )
                        : null,
                    child: Text(
                      _stages[i],
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                ),
              ),
              if (i < _stages.length - 1)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Container(
                    height: 1.5,
                    color: isPassed
                        ? WishRoomColors.glow.withValues(alpha: 0.4)
                        : WishRoomColors.surfaceCardBorder,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}
