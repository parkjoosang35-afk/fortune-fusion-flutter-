import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/premium_circle_button.dart';
import '../../healing_quote/application/healing_quote_provider.dart';
import '../../wallet/application/wallet_provider.dart';
import '../../attendance/application/attendance_provider.dart';
import '../../notification/notification_provider.dart';
import '../../pass/application/pass_provider.dart';
import '../../pass/presentation/pass_time_format.dart';
import '../../../core/domain/access/access_checker.dart';
import '../../auth/application/auth_provider.dart';
import '../../../core/widgets/app_toast.dart';
import '../../wish_room/presentation/wish_room_entry_gate.dart';
import '../../../core/widgets/face_palm_select_sheet.dart';
import 'home_style_tokens.dart';
import 'home_banner_carousel.dart';
import '../domain/jeontong_eighty_matrix.dart';
import '../../../core/router/app_router.dart' show AppRouter;
import '../application/home_page_config_provider.dart';
import '../application/section_visibility_evaluator.dart';
import '../../../core/widgets/premium_graphics.dart' show FadeSlideIn;
import '../data/welcome_reward_flag_store.dart';
import 'widgets/welcome_reward_modal.dart';

// 2026-08-13 -- 톤 일관화 토큰. 신 클래스/신 색상 정의 0.
class _Tone {
  _Tone._();
  // spacing grid
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  // shape
  static const double radius = 16;
  static const double elevation = 2;
  // icon
  static const double iconSm = 20;
  static const double iconMd = 28;
  // type scale (Theme 의 textTheme 그대로 사용 -- 신규 정의 0)
  // colors: 0 정의. 항상 Theme.of(context).colorScheme 참조.
}

/// [Fortune Fusion 서브 디자인 통일 마스터 프롬프트] 홈 화면 - 기준 시안 그대로 구현
///
/// 사용자가 제공한 홈 화면 목업(화이트 배경, 상단 로고+아이콘, 블랙 pill
/// "오늘의 운세보기" 버튼, "타로이야기가기" 섹션, 전체보기/사주/궁합/손금 칩,
/// 인디고 그라디언트 히어로카드, 소원게시판 라벤더 카드, 전체보기
/// 3카드 로우, 하단 블랙 "열림패스" 바)를 기준 디자인으로 그대로 재구현한다.
///
/// [UI 정리 세그먼트] 상단 CTA는 "+" 아이콘 없이 텍스트만 정중앙 정렬하고,
/// 전체보기는 처음부터 3개 카드용으로 설계된 균등분배 레이아웃을 사용하며,
/// AI 상담 배너 아래에는 일반상담을 재사용하는 보조 카드("고민상담")를 둔다.
///
/// [홈 화면 최종 마감 정돈 프롬프트] 화면 구조/카드 배치/섹션 순서는 절대
/// 바꾸지 않고, 색상·폰트·카드 크기·간격·정렬·아이콘 크기만 사용자가 제시한
/// 정밀 스펙(390px 기준)으로 전면 재조정한다. 색/폰트는 `home_style_tokens.dart`
/// (HomeColors/HomeText/HomeTokens, 이 화면 전용)를 단일 소스로 사용하고,
/// 기존 하드코딩 값(그라디언트/장식 원/그림자 등)은 "그림자·외곽선·그라데이션
/// 추가 금지" 원칙에 따라 제거한다. 다른 화면이 공유하는 `AppColors`/
/// `AppTypography`/`PremiumChip`·`PremiumCircleButton`의 기존 기본값은 그대로
/// 유지하고(회귀 방지), override 파라미터로만 이 화면에 스펙 색상을 주입한다.
///
/// [주의] Application/Data/Domain 레이어(Provider/Repository/Model)는 기존
/// 것을 그대로 재사용하며, 이 화면은 Presentation 레이어만 재작성한다.
class _Dims {
  _Dims._();

  // 좌우 기준 페이지 패딩(모든 섹션 공통 시작선, x=16 좌우 기준선과 동일)
  static const double pagePadding = 16;

  // 헤더 아래 gap(헤더 로우 → "전체보기" 섹션). 스펙 "SafeArea→헤더 14~18" 범위와
  // "세로 간격은 12/14/16/20만 사용" 원칙을 함께 만족시키는 값으로 확정.
  // [사용자 요청] "오늘의 운세보기" 검은색 CTA 버튼을 삭제하면서, 헤더 바로
  // 아래에 "전체보기" 섹션이 오도록 gap을 그대로 유지한다(버튼이 있던 자리의
  // 간격 값을 재사용해 레이아웃 흔들림 없이 자연스럽게 붙인다).
  static const double headerBottomGap = 20;

  // "타로이야기가기" 헤더 아래 gap(칩 로우까지) = 스펙 "섹션 제목 → 칩 라인: 12"
  static const double tarotHeaderBottomGap = 12;
  // 섹션 우상단 원형 아이콘 배경 28 / 내부 아이콘 14(28*0.5=14, override 불필요)
  static const double tarotCircleSize = 28;

  // [메인 UI 리디자인 - design_handoff_home_redesign, README.md Todo①]
  // 카테고리 칩 행이 삭제되어 chipHeight/chipGap/chipsBottomGap 상수는
  // 더 이상 쓰이지 않아 제거했다.

  // 헤더 row(아이콘 간격) - 스펙에 명시되지 않은 아이콘 내부 미세 간격이라 유지.
  static const double headerIconGap = 10;

  // [메인 UI 리디자인 - README.md Todo②] 힐링 카드가 큰 카드에서 슬림
  // 텍스트 바(_HealingQuoteCard)로 축소되면서 heroCardHeight/heroCardRadius/
  // heroCardPadding/healingCardHeight(큰 카드 전용 치수) 상수는 더 이상 쓰이지
  // 않아 제거했다. 슬림 바 자체의 margin/padding은 README.md "A. 힐링 슬림 바"
  // 스펙값(margin 0 4px 12px, padding 10px 12px)을 위젯 내부에 직접 반영했다.
  //
  // 힐링 슬림 바 → 캐러셀 → 운세/타로 카드 사이 gap. 슬림 바 자체가 이미
  // CSS 스펙대로 하단 margin 12px을 내부에 포함하고 있어([_HealingQuoteCard]
  // 참조), 이 상수는 캐러셀 → 운세/타로 카드, 그리고 오늘의 운세 섹션 →
  // 소원게시판 카드 사이 gap(스펙 12)에만 사용한다.
  static const double heroCardBottomGap = 12;

  // 소원게시판 카드 - 스펙: gap8/height96~104/radius16/padding14
  static const double wishCardGap = 8;
  static const double wishCardHeight = 100;
  static const double wishCardRadius = 16;
  static const double wishCardPadding = 14;
  // 카드 우상단 원형 CTA 배경 26~28 → 27(중앙값), 내부 아이콘 14로 override
  static const double wishCircleSize = 27;

  // 하단 고정 열림패스 바 - 스펙: width358(자동)/height48/radius24/좌우padding16
  static const double bottomBarHeight = 48;
  static const double bottomBarRadius = 24;
  // 소원게시판 카드 → 열림패스 바 gap = 스펙 "카드→열림패스바 14" 적용
  static const double bottomBarTopGap = 14;
  // 열림패스 바 → 탭바 gap = 스펙 14
  static const double bottomBarBottomGap = 14;
  static const double bottomBarCircleSize = 32;

  // ListView 하단 예약 공간(= 바 위 여백 + 바 높이 + 바 아래 여백).
  static const double bottomBarReservedSpace =
      bottomBarTopGap + bottomBarHeight + bottomBarBottomGap;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // [사용자 요청 - 상단 메뉴 이동(탭) 기능] "전체보기" 타이틀과 "오늘의 운세"
  // 칩을 누르면 홈 화면에 실제로 존재하는 "오늘의 운세" 섹션(힐링 문구 카드 +
  // 운세/타로 카드)으로 자동 스크롤 이동한다. Scrollable.ensureVisible로 이
  // 키가 달린 위젯이 화면에 보이도록 스크롤한다(같은 ListView 안이라 별도
  // ScrollController offset 계산 없이 안전하게 동작). 사주/관상/손금/정통사주는
  // 기존처럼 각자의 입력 화면으로 바로 이동하고, 신년운세는 아직 홈에 전용
  // 섹션/상세화면이 없어 안내 토스트로 대체한다(key=null → _scrollToSection이
  // 자동으로 토스트 처리).
  final _todayFortuneSectionKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletProvider>().load();
      context.read<AttendanceProvider>().load();
      // 2026-08-13 결정: 일간 운세는 정통사주 80항목으로 통합되었다.
      // 원 호출: context.read<DailyFortuneProvider>().loadToday();
      context.read<PassProvider>().load();
      context.read<NotificationProvider>().load();
      // [사용자 요청] "오늘의 운세 이야기"를 완전히 삭제하고 데이터베이스 기반 힐링
      // 문구로 대체 — admin_web `/api/public/healing-quotes`에서 활성 문구 목록을
      // 불러와 1분마다 자동 순환한다.
      // [6-2-A 광고 배너 재연결] home_middle 슬롯 광고 로드는
      // `_HomeMiddleAdSlot` 내부의 `AdBannerWidget`이 자체 initState에서
      // 담당하므로(AdBannerProvider.load 기존 로직 그대로), 여기서 별도로
      // 다시 호출하지 않는다(중복 네트워크 요청 방지).
      context.read<HealingQuoteProvider>().load();

      // [6-4-B CMS 홈 안전 연결 - 선행 배선] admin_web `/cms/page-configs/home`
      // 발행 데이터를 실제로 로드해두되(HomePageConfigProvider.load()), 그
      // 결과는 이번 단계에서 어떤 위젯 렌더링에도 사용하지 않는다(§4 "Renderer
      // → 실제 HomeScreen 연결은 다음 단계로 분리" 원칙). 여기서는 오직
      // "API → Provider → Evaluator" 흐름이 실제로 끊김 없이 동작하는지만
      // 검증하고, 결과는 디버그 로그로만 남긴다. 로드 시점은 다른 홈 전용
      // Provider들(Wallet/Attendance/Pass/Notification/HealingQuote)과 동일하게
      // HomeScreen의 첫 프레임 이후로 맞춰, 앱 시작 시점(app.dart)에 무조건
      // 실행하는 방식보다 "홈 화면에 실제로 진입했을 때만" 불필요한 네트워크
      // 요청이 발생하도록 최소화했다(다른 탭만 쓰는 사용자는 이 호출이 아예
      // 발생하지 않음).
      _loadHomePageConfigAndVerify();

      // [Phase C - 03_Welcome_Reward.html Flow notes 반영] "회원가입 완료 →
      // 홈 자동 진입 → 0.4s 딜레이 → 신통도령 팝업" 시퀀스. 기존
      // Wallet/Attendance/Pass/Notification/HealingQuote 로드 로직은 전혀
      // 건드리지 않고, 이 postFrameCallback 안에 새 호출 1개만 추가한다.
      _maybeShowWelcomeRewardModal();
    });
  }

  /// [Phase C] `AuthProvider.lastSignupReward`가 존재하고(=이번 세션에서
  /// 방금 회원가입이 성공해 홈에 처음 도달) 아직 로컬 플래그로 수령
  /// 처리되지 않았을 때만 웰컴 리워드 팝업을 1회 노출한다.
  ///
  /// `lastSignupReward`는 프로세스 메모리에만 존재하는 값이라(앱 재시작/
  /// 재로그인 시 자연스럽게 null) 별도의 서버 플래그 없이도 "같은 세션 내
  /// 최초 1회"라는 제약이 자동으로 성립한다. 로컬
  /// [WelcomeRewardFlagStore]는 같은 세션 안에서 HomeScreen이 여러 번
  /// 재빌드/재진입되는 경우(예: 뒤로가기 후 재진입)에 대한 추가 방어선이다.
  Future<void> _maybeShowWelcomeRewardModal() async {
    final auth = context.read<AuthProvider>();
    final reward = auth.lastSignupReward;
    final userId = auth.currentUser?.id;
    if (reward == null || userId == null) return;

    final amount = (reward['amount'] as num?)?.toInt() ?? 0;
    if (amount <= 0) return;

    final alreadyClaimed = await WelcomeRewardFlagStore.isClaimed(userId);
    if (alreadyClaimed || !mounted) return;

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    await WelcomeRewardModal.show(
      context,
      amount: amount,
      onClaim: () {
        WelcomeRewardFlagStore.markClaimed(userId);
      },
    );
  }

  /// [6-4-B] HomePageConfigProvider.load() 완료 후, 실제 AuthProvider/
  /// AccessChecker/WalletProvider 값으로 [HomeVisibilityContext]를 구성해
  /// [SectionVisibilityEvaluator.filterVisible]까지 정상 동작하는지만 검증한다.
  /// 이 메서드의 결과(visible 섹션 목록)는 화면에 전혀 반영되지 않는다 —
  /// 순수하게 "배선이 끊기지 않았는지" 확인하는 디버그 전용 경로다.
  Future<void> _loadHomePageConfigAndVerify() async {
    final configProvider = context.read<HomePageConfigProvider>();
    await configProvider.load();
    if (!mounted) return;

    // isLoggedIn은 절대 고정값(true/false)을 넣지 않고 실제 AuthProvider
    // 상태를 그대로 읽는다([사용자 지시] §3 "임의로 고정하지 마세요").
    final auth = context.read<AuthProvider>();
    final access = context.read<AccessChecker>();
    final wallet = context.read<WalletProvider>();

    final ctx = HomeVisibilityContext(
      isLoggedIn: auth.isLoggedIn,
      now: DateTime.now(),
      openPassActive: access.openPassState.isActive,
      luckPouchBalance: wallet.balance,
      platform: HomeVisibilityContext.currentPlatformKey(),
    );

    final visible = configProvider.visibleSections(ctx);
    debugPrint(
      '[6-4-B 검증] HomePageConfig load 상태=${configProvider.state.isSuccess}, '
      'usingCache=${configProvider.usingCache}, '
      '전체 섹션=${configProvider.rawSections.length}, '
      'visible 섹션=${visible.length} (아직 화면에는 미반영)',
    );
  }

  /// [상단 메뉴 이동(탭) 기능] 지정한 [key]가 달린 섹션이 화면에 보이도록
  /// 부드럽게 스크롤한다. 신년운세처럼 아직 홈 화면에 전용 콘텐츠 섹션이 없는
  /// 카테고리는 key가 null이라 대신 안내 토스트를 띄운다(전체 카테고리 화면
  /// 이동 없이 홈에 머무르는 사용자 경험 유지).
  void _scrollToSection(GlobalKey? key, String label) {
    if (key?.currentContext == null) {
      AppToast.show(context, '$label 섹션은 곧 홈에서 만나볼 수 있어요 🙏');
      return;
    }
    Scrollable.ensureVisible(
      key!.currentContext!,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
      alignment: 0.08,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomeColors.bg,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(
                _Dims.pagePadding,
                _Dims.pagePadding,
                _Dims.pagePadding,
                _Dims
                    .bottomBarReservedSpace, // 하단 열림패스 고정바(상단거리+높이+하단거리)만큼 여백 확보
              ),
              children: [
                // ① 상단 헤더 - 로고 + 클로버/벨 아이콘(배경 없는 bare 아이콘)
                const _TopHeader(),
                const SizedBox(height: _Dims.headerBottomGap),

                // ② [사용자 요청] "전체보기" 타이틀(탭 시 "오늘의 운세" 섹션으로
                // 스크롤 이동) + 우측 블랙 원형 그리드 버튼(운세 전체보기
                // 카테고리 허브 화면으로 이동, 기존 동작 유지).
                FadeSlideIn(
                  delay: const Duration(milliseconds: 40),
                  child: _AllCategoriesHeader(
                    onTitleTap: () =>
                        _scrollToSection(_todayFortuneSectionKey, '오늘의 운세'),
                  ),
                ),
                const SizedBox(height: _Dims.tarotHeaderBottomGap),

                // [메인 UI 리디자인 - design_handoff_home_redesign] 카테고리
                // 칩 행(오늘의 운세/AI 사주/관상/손금/정통사주)을 완전히
                // 삭제했다(README.md Todo①). "오늘의 운세" 칩이 담당하던
                // 스크롤 이동 기능은 위 "전체보기" 타이틀 탭에 이미 동일하게
                // 연결되어 있어 기능 손실이 없다.

                // ④ [메인 UI 리디자인] "오늘의 운세" 섹션 - 힐링 슬림 바 +
                // 귀인지도/오늘의 운세/인연·궁합 3장 롤링 캐러셀 + 운세/타로
                // 2분할 카드를 하나의 섹션으로 감싸 GlobalKey를 부여한다(상단
                // "전체보기" 타이틀 탭에서 이 섹션으로 스크롤 이동할 수 있게
                // 하기 위함).
                // - 힐링 문구: db 기반 자동 순환 데이터/API/인터랙션은 완전히
                //   동일하게 유지하고 스타일(큰 카드 → 슬림 텍스트 블록)만
                //   변경했다(README.md Todo②).
                // - 광고 배너(home_middle 슬롯)는 3장 롤링 캐러셀
                //   ([HomeBannerCarousel] · 귀인지도/오늘의 운세/인연·궁합)로
                //   교체했다(README.md Todo③ + BANNER_CAROUSEL.md 확장 스펙).
                // - 운세/타로 카드 이동 동작은 기존과 완전히 동일하게 유지한다.
                KeyedSubtree(
                  key: _todayFortuneSectionKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 120),
                        child: const _HealingQuoteCard(),
                      ),
                      const FadeSlideIn(
                        delay: Duration(milliseconds: 130),
                        child: HomeBannerCarousel(),
                      ),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 140),
                        child: const _FortuneTarotRow(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: _Dims.heroCardBottomGap),

                // ⑤-1 [중복 진입점 정리] "내 생년월일시로 정통사주 보기" 배너
                // (_JeontongProfileBanner)는 위 "운세" 카드(_FortuneTarotRow,
                // `/jeontong/eighty` 아코디언 화면 진입)와 기능이 완전히
                // 중복되어 사용자 요청에 따라 제거했다. 정통사주 진입점은
                // "운세" 카드 하나로 통일한다.

                // ⑥ 소원게시판 카드(#F5F3FB)
                // [첨부 디자인 반영] 목업에는 이 2단 카드까지만 존재하고 그
                // 아래(전체보기 3버튼/AI상담 배너/고민상담 카드)는 없으므로,
                // 여기서 화면을 마무리한다("나머지는 안보여도 됨").
                const FadeSlideIn(
                  delay: Duration(milliseconds: 160),
                  child: _WishBoardRoomRow(),
                ),
              ],
            ),

            // ⑧ 하단 고정 블랙 pill 바 - "열림패스" + 네온라임 원형 화살표
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _OpenPassBottomBar(),
            ),
          ],
        ),
      ),
    );
  }
}

/// ① 상단 헤더 - 좌측 로고 텍스트 + 우측 클로버🍀/벨 bare 아이콘
class _TopHeader extends StatelessWidget {
  const _TopHeader();

  @override
  Widget build(BuildContext context) {
    final notif = context.watch<NotificationProvider>();
    final auth = context.watch<AuthProvider>();

    return Row(
      children: [
        // [사용자 요청] 상단 '신통방통' 로고 크기를 '전체보기' 제목 정도의
        // 크기로 줄인다. 기존 22px(Type Scale 최대치인 titleLarge 17px보다도
        // 큰 예외값)에서 18px로 축소해, 아래에서 함께 줄인 '전체보기' 제목
        // (16px)과 비슷한 크기대에서 로고 쪽이 아주 살짝만 더 커 보이도록
        // 균형을 맞춘다(완전히 동일하면 워드마크로서의 존재감이 사라지므로
        // 최소한의 위계는 남긴다).
        Text(
          '신통방통',
          style: TextStyle(
            fontFamily: HomeText.family,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
            height: 1.3,
            color: HomeColors.textPrimary,
          ),
        ),
        const Spacer(),
        // [인트로 전면 개편 - 인트로↔홈 연결] 인트로 2단계(복주머니)에서 소개한
        // "복주머니는 무료로 모으고, 자유롭게 써요"가 실제로 홈에서 잔액으로
        // 바로 확인 가능해야 한다는 요구사항 대응. 탭하면 복주머니 상세(적립
        // 내역/받기)로 이동한다. 마이페이지의 _WalletSummaryCard와는 별개로,
        // 여기서는 헤더에 붙는 작은 배지 형태로 최소한만 노출한다.
        GestureDetector(
          onTap: () => Navigator.of(context).pushNamed('/reward/wallet'),
          child: Consumer<WalletProvider>(
            builder: (context, wallet, _) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: HomeColors.cardAllMenu,
                borderRadius: BorderRadius.circular(HomeTokens.radiusPill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.card_giftcard_rounded,
                    size: 14,
                    color: HomeColors.textPrimary,
                  ),
                  const SizedBox(width: 4),
                  Text('${wallet.balance}', style: HomeText.chipLabel()),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: _Dims.headerIconGap),
        // 벨 아이콘 - 스펙 "상단 우측 알림/클로버 아이콘: 20~22" 범위 상단값(22),
        // 컬러는 기본 텍스트 아이콘 규칙(#111111) 적용.
        GestureDetector(
          onTap: () => Navigator.of(context).pushNamed('/my/notifications'),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                notif.unreadCount > 0
                    ? Icons.notifications_rounded
                    : Icons.notifications_none_rounded,
                size: HomeTokens.iconXl,
                color: HomeColors.textPrimary,
              ),
              if (notif.unreadCount > 0)
                Positioned(
                  right: -1,
                  top: -1,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.premiumCoralAccent,
                      shape: BoxShape.circle,
                      border: Border.all(color: HomeColors.bg, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: _Dims.headerIconGap),
        GestureDetector(
          onTap: () => Navigator.of(context).pushNamed('/history/readonly'),
          child: const Icon(
            Icons.history_rounded,
            size: HomeTokens.iconXl,
            color: HomeColors.textPrimary,
          ),
        ),
        // [첨부 디자인 반영] 우측 끝 원형 프로필 아바타 - 로그인 상태면
        // 마이페이지(설정)로, 비로그인 상태면 로그인 화면으로 이동한다.
        GestureDetector(
          onTap: () => Navigator.of(
            context,
          ).pushNamed(auth.isLoggedIn ? '/my/settings' : '/login'),
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: HomeColors.cardAllMenu,
              border: Border.all(color: HomeColors.border, width: 1),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.person_rounded,
              size: 18,
              color: HomeColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// ③ [사용자 요청] "전체보기" 섹션 헤더 + 우측 블랙 원형 그리드 아이콘 버튼.
///
/// - "전체보기" 텍스트를 누르면 페이지 이동 없이 "오늘의 운세" 섹션으로
///   스크롤 이동한다([onTitleTap]).
/// - 우측 원형 그리드 버튼은 기존 그대로 운세 전체보기(카테고리 허브,
///   `/home/all-categories`)로 이동한다(탭 동작만 텍스트와 분리해서 유지).
/// - [사용자 요청] "'전체보기' 제목도 현재보다 약간 작게 조정" — 기존
///   titleLarge(17px)에서 title(15px)로 축소해, 위에서 줄인 로고(18px)와
///   비슷한 크기대에서 자연스러운 균형을 이루도록 한다.
class _AllCategoriesHeader extends StatelessWidget {
  const _AllCategoriesHeader({required this.onTitleTap});

  final VoidCallback onTitleTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTitleTap,
            child: Row(
              children: [
                // [범위 외] 이 20x20 블랙 배지는 스펙의 아이콘 크기표(헤더/섹션원형/
                // 카드CTA/AI배너CTA/열림패스 등)에 명시되지 않은 장식 마커라 크기는
                // 유지했다. 컬러만 블랙 포인트(#111111)로 통일한다.
                Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: HomeColors.black,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Icon(
                    Icons.style_rounded,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Text('전체보기', style: HomeText.title()),
              ],
            ),
          ),
        ),
        // 섹션 우상단 원형 아이콘 배경 28 / 내부 아이콘 14(28*0.5=14).
        // 블랙 CTA 색상을 스펙 정확값(#111111)으로 override.
        PremiumCircleButton(
          icon: Icons.grid_view_rounded,
          style: PremiumCircleButtonStyle.black,
          size: _Dims.tarotCircleSize,
          bgColor: HomeColors.black,
          fgColor: Colors.white,
          // [첨부 디자인 반영] 운세 전체보기(카테고리 허브) 화면으로 이동하는
          // 기존 동작을 그대로 유지한다(텍스트 탭 동작과는 별개).
          onTap: () => Navigator.of(context).pushNamed('/home/all-categories'),
        ),
      ],
    );
  }
}

// [메인 UI 리디자인 - design_handoff_home_redesign, README.md Todo①]
// 운세 카테고리 칩 행(_FortuneCategoryChips, "오늘의 운세/AI 사주/관상/손금/
// 정통사주" 5개)은 완전히 삭제되었다. "오늘의 운세" 스크롤 이동 기능은
// 위 "전체보기" 타이틀 탭(_AllCategoriesHeader.onTitleTap)이 계속 동일하게
// 담당하고, "AI 사주"/"관상"/"손금"/"정통사주" 진입점은 `/home/all-categories`
// (전체보기 그리드 버튼)에서 계속 접근 가능하므로 기능 손실이 없다.

// [메인 UI 리디자인 - README.md Todo③] 힐링 문구 카드와 운세/타로 카드
// 사이의 `home_middle` 슬롯 광고(_HomeMiddleAdSlot, AdBannerWidget)는
// 3장 롤링 캐러셀([HomeBannerCarousel] · 귀인지도/오늘의 운세/인연·궁합)로
// 교체되어 완전히 삭제되었다.

// DailyFortune home card is hidden by 2026-08-13 decision
/// ⑤ [메인 UI 리디자인 - design_handoff_home_redesign, README.md "A. 힐링
/// 슬림 바(Healing Slim Bar)"] 큰 카드형 힐링 문구 카드를 배경/테두리/그림자
/// 없는 순수 텍스트 블록(슬림 바)으로 축소했다.
///
/// - **기능·데이터는 완전히 동일하게 유지**한다 — admin_web DB에서 불러온
///   힐링 문구를 [HealingQuoteProvider]가 1분마다 자동으로 순환시키는 로직,
///   로그인 시 닉네임 개인화 라벨("{닉네임}님, 오늘의 힐링 한마디")은 모두
///   기존 그대로다. 변경된 것은 오직 시각 스타일(큰 카드 → 슬림 텍스트 바)
///   뿐이다(README.md "2. 힐링 한마디 섹션 위치·스타일 변경 — 기능은 그대로").
/// - 배경색 30분 랜덤 순환, 8초 색상 애니메이션, SoftGradientBlob/FloatingMoon/
///   SparkleDot 장식 레이어는 큰 카드 전용 효과였으므로 슬림 바에는 제거했다
///   (README.md 스펙: "배경·테두리·그림자 모두 제거").
/// - 레이아웃/타이포는 `Sintong Home.html`의 `.healing-bar`/`.healing-bar-head`/
///   `.healing-bar-text` CSS 스펙을 그대로 이식했다: margin 0/0/12/4(좌우4,
///   상0, 하12), padding 10/12, flex column gap4, 아이콘🌿+라벨(11px #8b8b94),
///   본문(500 12.5px #1f1f24, 한 줄 말줄임).
class _HealingQuoteCard extends StatelessWidget {
  const _HealingQuoteCard();

  @override
  Widget build(BuildContext context) {
    final healing = context.watch<HealingQuoteProvider>();
    final quote = healing.current;

    // [사용자 요청] "오늘에 힐링한마디 섹션 로그인시 이름이 나오게해주고
    // 이성우님 이런식으로" — 로그인 상태면 라벨에 "{닉네임}님, "을 붙여
    // 개인화된 인사말을 보여준다. 비로그인/닉네임 없음이면 기존 그대로.
    final auth = context.watch<AuthProvider>();
    final nickname = auth.isLoggedIn ? auth.currentUser?.nickname : null;
    final hasNickname = nickname != null && nickname.trim().isNotEmpty;
    final labelText = hasNickname ? '$nickname님, 오늘의 힐링 한마디' : '오늘의 힐링 한마디';
    final quoteText = quote?.content ?? '잠시 마음을 쉬어가도 괜찮아요. 당신은 충분히 잘하고 있습니다.';

    // README.md 스펙: 좌우 마진 4px, 상단 마진 0, 하단 마진 12px(배너와의 간격).
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
      child: Padding(
        // 컨테이너 패딩: 10px 12px, 배경/테두리/그림자 없음.
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 타이틀(헤드): 🌿 아이콘 + 라벨, gap 4px.
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🌿', style: TextStyle(fontSize: 11)),
                const SizedBox(width: 4),
                Text(
                  labelText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1,
                    letterSpacing: -0.11,
                    color: Color(0xFF8B8B94),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // 본문: 500 12.5px #1f1f24, 한 줄 말줄임(nowrap+ellipsis).
            Text(
              quoteText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                height: 1.5,
                letterSpacing: -0.25,
                color: Color(0xFF1F1F24),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ⑤-1 [첨부 디자인 반영] "운세"/"타로" 2분할 카드
///
/// 좌측 "운세" 카드는 연보라(#F0EEFB 계열) 배경 + 네온라임 원형(위쪽 화살표)
/// 버튼으로, [정통사주 80종 개편] 탭하면 정통사주 80종을 대카테고리(A~H)·
/// 소카테고리(각 10개)로 나눠 진열하는 전용 화면(`/jeontong/eighty`,
/// jeontong_eighty_screen.dart)으로 이동한다. 과거 8종 고정 바텀시트
/// (jeontong_saju_section.dart)는 더 이상 이 카드에서 호출하지 않지만
/// 파일/라우팅 자체는 보존한다(갈아엎지 않는다 원칙).
/// 우측 "타로" 카드는 더 밝은 파스텔 블루-라벤더 배경 + 블랙 원형(아래쪽
/// 화살표) 버튼으로 타로 메인 홈으로 이동한다(원상복구, 변경 없음 — AI
/// 타로는 이번 작업 범위에서 전혀 건드리지 않는다). 각 카드 하단에는 작은
/// 부제(운세이야기/타로이야기)를 배치해 첨부 목업의 레이아웃을 그대로 재현한다.
class _FortuneTarotRow extends StatelessWidget {
  const _FortuneTarotRow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _Dims.wishCardHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _FortuneTarotMiniCard(
              title: '정통사주',
              bottomLabel: '정통사주이야기',
              backgroundColor: HomeColors.cardMain,
              circleIcon: Icons.arrow_drop_up_rounded,
              circleStyle: PremiumCircleButtonStyle.neon,
              // [부적게이트 재배치] "운세" 카드를 누르면 곧장 목록 화면으로
              // 가지 않고, 먼저 부적게이트(인트로)를 보여준 뒤 게이트가
              // 끝나면 게이트 화면이 자체적으로 정통사주 80종 목록
              // (browseRoute)으로 이동한다. 소카테고리 선택 시의 게이트
              // 체크는 그대로 그 화면 안에서 개별 수행된다(변경 없음).
              onTap: () => Navigator.of(
                context,
              ).pushNamed(JeontongEightyMatrix.gateRoute),
            ),
          ),
          const SizedBox(width: _Dims.wishCardGap),
          Expanded(
            child: _FortuneTarotMiniCard(
              title: '타로',
              bottomLabel: '타로이야기',
              backgroundColor: HomeColors.cardWish,
              circleIcon: Icons.arrow_drop_down_rounded,
              circleStyle: PremiumCircleButtonStyle.black,
              // [둘러보기 우선 원칙 - 타로도 정통사주와 동일하게] 다른 모든
              // 기능(정통사주 등)은 메인 진입 시 게이트 없이 먼저 "둘러보기"가
              // 가능하고, 실제로 결과를 만들어내는 "다음 액션"(카테고리+
              // 스프레드 선택 후 "시작하기")에서만 프리패스가 발동한다. 타로만
              // 유독 메인 진입 즉시 프리패스가 떠서 둘러볼 수조차 없던 버그를
              // 수정한다 — 게이트 없이 인트로 스플래시(tarotIntroRoute)로 직행
              // 시키고, 실제 게이트는 tarot_category_detail_screen.dart의
              // "시작하기" 버튼(다음 액션)에서 수행한다.
              onTap: () =>
                  Navigator.of(context).pushNamed(AppRouter.tarotIntroRoute),
            ),
          ),
        ],
      ),
    );
  }
}

class _FortuneTarotMiniCard extends StatelessWidget {
  const _FortuneTarotMiniCard({
    required this.title,
    required this.bottomLabel,
    required this.backgroundColor,
    required this.circleIcon,
    required this.circleStyle,
    required this.onTap,
  });

  final String title;
  final String bottomLabel;
  final Color backgroundColor;
  final IconData circleIcon;
  final PremiumCircleButtonStyle circleStyle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final overrideBg = circleStyle == PremiumCircleButtonStyle.neon
        ? HomeColors.neon
        : HomeColors.black;
    final overrideFg = circleStyle == PremiumCircleButtonStyle.neon
        ? HomeColors.textPrimary
        : Colors.white;

    return PremiumCard(
      backgroundColor: backgroundColor,
      borderColor: Colors.transparent,
      borderRadius: BorderRadius.circular(_Dims.wishCardRadius),
      showShadow: false,
      onTap: onTap,
      padding: const EdgeInsets.all(_Dims.wishCardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(title, style: HomeText.title())),
              PremiumCircleButton(
                icon: circleIcon,
                style: circleStyle,
                size: _Dims.wishCircleSize,
                iconSize: 14,
                bgColor: overrideBg,
                fgColor: overrideFg,
                onTap: onTap,
              ),
            ],
          ),
          Text(bottomLabel, style: HomeText.caption()),
        ],
      ),
    );
  }
}

/// ⑥ 소원방 · 관상/손금 카드 - #F5F3FB
///
/// [소원방 리스킨] 복주머니와 별개인 자체 화폐("조각") 경제를 쓰던 구
/// "신통방통 소원방"(wish_room) 모듈은 완전히 삭제되었고, 그 대체품인
/// "소원벽"(wish_wall_board)이 복주머니 정책으로 통합되어 있었다. 이번
/// 리스킨에서는 `design_handoff_wish_room.zip`(V2 "마법진이 소환되는
/// 신전" 팔레트)을 적용한 [WishRoomHomeScreen](제단 홈)으로 다시 교체한다.
/// 이 화면은 하단 탭바의 "소원방" 탭과 완전히 동일한 화면이다(단일 진입점).
/// [상담 기능 완전 삭제] "상담"(wish_counsel 클라이언트 챗봇 시뮬레이션 +
/// consultation 실LLM 상담) 두 시스템 모두 사용자 지시로 완전히 삭제되었다.
/// 그 자리는 이미 구현되어 있었지만 "전체보기"에만 있던 관상/손금 두 기능을
/// 하나로 합친 카드로 교체한다. 탭하면 [showFacePalmSelectSheet]가 관상/손금
/// 선택 바텀시트를 띄우고, 각 선택은 기존 `/ai-fortune/face/capture`,
/// `/ai-fortune/palm/capture` 라우트로 [navigateWithPassGate]를 거쳐 이동한다
/// (새 라우트/화면 생성 없음, 기존 화면 재사용).
class _WishBoardRoomRow extends StatelessWidget {
  const _WishBoardRoomRow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _Dims.wishCardHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _LavenderMiniCard(
              title: '소원방',
              bottomLabel: '소원을 밝혀보세요',
              circleIcon: Icons.arrow_drop_up_rounded,
              circleStyle: PremiumCircleButtonStyle.neon,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WishRoomEntryGate()),
              ),
            ),
          ),
          const SizedBox(width: _Dims.wishCardGap),
          Expanded(
            child: _LavenderMiniCard(
              title: '관상 · 손금',
              bottomLabel: '얼굴과 손을 읽어보세요',
              circleIcon: Icons.arrow_drop_up_rounded,
              circleStyle: PremiumCircleButtonStyle.black,
              onTap: () => showFacePalmSelectSheet(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _LavenderMiniCard extends StatelessWidget {
  const _LavenderMiniCard({
    required this.title,
    required this.bottomLabel,
    required this.circleIcon,
    required this.circleStyle,
    required this.onTap,
  });

  final String title;
  final String bottomLabel;
  final IconData circleIcon;
  final PremiumCircleButtonStyle circleStyle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 네온 스타일 CTA만 정확한 스펙 hex(#C6F24E/#111111)로 override. 블랙
    // 블랙 스타일은 기존 premiumBlackCta(#121212)를 유지해도 스펙 #111111과
    // 시각적으로 동일하지만, 완전한 hex 일치를 위해 이 화면에서는 두 카드 모두
    // override로 정확히 맞춘다(두 카드 완전 대칭 유지가 최우선이기 때문).
    final overrideBg = circleStyle == PremiumCircleButtonStyle.neon
        ? HomeColors.neon
        : HomeColors.black;
    final overrideFg = circleStyle == PremiumCircleButtonStyle.neon
        ? HomeColors.textPrimary
        : Colors.white;

    return PremiumCard(
      backgroundColor: HomeColors.cardWish,
      borderColor: Colors.transparent,
      borderRadius: BorderRadius.circular(_Dims.wishCardRadius),
      showShadow: false,
      onTap: onTap,
      padding: const EdgeInsets.all(_Dims.wishCardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(title, style: HomeText.title())),
              // 카드 우상단 원형 CTA 배경 26~28→27, 내부 아이콘 14로 override.
              PremiumCircleButton(
                icon: circleIcon,
                style: circleStyle,
                size: _Dims.wishCircleSize,
                iconSize: 14,
                bgColor: overrideBg,
                fgColor: overrideFg,
                onTap: onTap,
              ),
            ],
          ),
          Text(bottomLabel, style: HomeText.caption()),
        ],
      ),
    );
  }
}

/// ⑦ 하단 고정 블랙 pill 바 - "열림패스" + 남은시간 + 네온라임 원형 화살표
///
/// [색상/아이콘 통일] 배경을 정확히 #111111로, 자물쇠 이모지를 라인 아이콘
/// (lock_outline_rounded/lock_open_rounded, 두께감 있는 rounded 세트)으로
/// 교체해 "라인 아이콘 기본" 원칙에 맞췄다. "그림자 사용 금지" 원칙에 따라
/// 기존 BoxShadow도 제거했다.
///
/// [열림패스/복주머니/복주머니 통합정책 §3] "홈 화면은 운세 진입과 열림패스
/// 중심으로 설계한다. ... 열림패스 남은 시간 노출이 우선"에 대응해, 활성 시
/// 남은 시간을 라벨로 함께 노출한다(구매 유도 문구는 추가하지 않음).
class _OpenPassBottomBar extends StatefulWidget {
  const _OpenPassBottomBar();

  @override
  State<_OpenPassBottomBar> createState() => _OpenPassBottomBarState();
}

class _OpenPassBottomBarState extends State<_OpenPassBottomBar> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // [프리패스 테스트 인프라] §6/§7/§13 — 남은 시간은 [OpenPassState.fromModel]이
    // expiresAt 기준으로 매번 실시간 재계산하므로, 여기서는 1초마다 단순
    // rebuild만 트리거해주면 만료 순간 자동으로 잠금 아이콘/문구로 전환된다
    // (서버 재호출 없이 "자동 재잠금"이 화면에 실시간 반영됨).
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final access = context.watch<AccessChecker>();
    final isActive = access.canAccessFortuneScope();
    // [프리패스 단순화 - 쿠팡파트너스 전용] §6 — HH:MM:SS 형식으로 통일.
    final remainingLabel = isActive
        ? formatPassHms(access.openPassState.remaining)
        : null;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          _Dims.pagePadding,
          _Dims.bottomBarTopGap,
          _Dims.pagePadding,
          _Dims.bottomBarBottomGap,
        ),
        child: GestureDetector(
          onTap: () => Navigator.of(context).pushNamed('/reward/wallet'),
          child: Container(
            height: _Dims.bottomBarHeight,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            decoration: BoxDecoration(
              color: HomeColors.passBar,
              borderRadius: BorderRadius.circular(_Dims.bottomBarRadius),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 열림패스 좌측 자물쇠 아이콘 16(스펙 고정값).
                Icon(
                  isActive
                      ? Icons.lock_open_rounded
                      : Icons.lock_outline_rounded,
                  size: HomeTokens.iconMd,
                  color: Colors.white,
                ),
                // 자물쇠-텍스트 gap 10(스펙 고정값).
                const SizedBox(width: 10),
                Text('프리패스', style: HomeText.bodyStrong(color: Colors.white)),
                if (isActive && remainingLabel != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    '· $remainingLabel',
                    style: HomeText.bodyStrong(color: HomeColors.neon),
                  ),
                ],
                const Spacer(),
                // 열림패스 우측 원형 버튼 32 / 내부 아이콘 16(32*0.5=16).
                PremiumCircleButton(
                  icon: Icons.chevron_right_rounded,
                  style: PremiumCircleButtonStyle.neon,
                  size: _Dims.bottomBarCircleSize,
                  bgColor: HomeColors.neon,
                  fgColor: HomeColors.textPrimary,
                  onTap: () =>
                      Navigator.of(context).pushNamed('/reward/wallet'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget _toneWrap({
  required Widget child,
  required VoidCallback onTap,
  EdgeInsets padding = const EdgeInsets.all(16),
}) {
  return Card(
    elevation: _Tone.elevation,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_Tone.radius),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(_Tone.radius),
      onTap: onTap,
      child: Padding(padding: padding, child: child),
    ),
  );
}
