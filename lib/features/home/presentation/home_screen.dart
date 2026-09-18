// ═══════════════════════════════════════════════════════════════
// FILE: home_screen.dart
// [신통방통 메인 매핑 - design_handoff_sintongbangtong_home.zip 전면 교체]
//
// 사용자가 업로드한 디자인 핸드오프(`Handoff.html`/`index.html`, "신통방통
// 홈 화면 리메이크")를 기준으로 홈 화면을 pixel-level로 재구현했다.
//
// [원칙] "비주얼 레이어만 새 디자인 스펙으로 재구현하고, 기존 Provider
// 연동 로직(지갑/알림/힐링문구/프리패스 타이머/라우팅)은 전혀 건드리지
// 않는다" — 사용자 확인 사항 그대로 적용:
// - WalletProvider.load() / AttendanceProvider.load() / PassProvider.load()
//   / NotificationProvider.load() / HealingQuoteProvider.load() /
//   HomePageConfigProvider 검증 / 웰컴리워드 팝업 시퀀스는 기존과 완전히
//   동일한 initState 로직을 그대로 유지한다.
// - 각 섹션(브랜드헤더/힐링바/프리패스바 등)의 실제 라우팅 목적지도 기존과
//   동일하게 유지한다(정통사주→JeontongEightyMatrix.gateRoute, 타로→
//   tarotIntroRoute, 소원방→WishRoomEntryGate, 손금·관상→
//   showFacePalmSelectSheet, 전체보기→/home/all-categories 등).
//
// [신규 추가] 30초 스토리 슬라이드 히어로(SintongStoryHero, "귀인지도"
// 소개)는 기존 화면에 없던 완전 신규 기능이라 새로 추가했다. 탭 시
// 목적지는 기존 "귀인지도 만들기" CTA와 동일하게 GuinjiLandingScreen
// (`/guinji`)으로 연결한다.
//
// [4번째 서비스카드] index.html 실제 목업 기준(사용자 확인 완료)으로
// "손금/관상" 통합 카드를 사용하며, 기존 `showFacePalmSelectSheet` 바텀
// 시트를 그대로 재사용한다(새 라우트 없음).
//
// [폰트] Fraunces Italic은 google_fonts 패키지(6.2.1, 기존 프로젝트에
// 이미 포함되어 있던 패키지)의 `GoogleFonts.fraunces()`를 그대로 사용한다
// (별도 폰트파일 번들/의존성 추가 없음, 사용자 확인 완료).
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../healing_quote/application/healing_quote_provider.dart';
import '../../wallet/application/wallet_provider.dart';
import '../../attendance/application/attendance_provider.dart';
import '../../notification/notification_provider.dart';
import '../../pass/application/pass_provider.dart';
import '../../../core/domain/access/access_checker.dart';
import '../../auth/application/auth_provider.dart';
import '../../wish_room/presentation/wish_room_entry_gate.dart';
import '../../../core/widgets/face_palm_select_sheet.dart';
import '../../guinji/presentation/guinji_landing_screen.dart';
import '../domain/jeontong_eighty_matrix.dart';
import '../../../core/router/app_router.dart' show AppRouter;
import '../application/home_page_config_provider.dart';
import '../application/section_visibility_evaluator.dart';
import '../domain/page_config_model.dart';
import 'widgets/welcome_reward_modal.dart';
import '../../ads_test/presentation/admob_test_banner.dart';
import '../../ad_banner/presentation/ad_banner_widget.dart';
import 'sintong_home/sintong_home_tokens.dart';
import 'sintong_home/widgets/sintong_brand_app_bar.dart';
import 'sintong_home/widgets/sintong_mode_chip_row.dart';
import 'sintong_home/widgets/sintong_healing_bar.dart';
import 'sintong_home/widgets/sintong_story_hero.dart';
import 'sintong_home/widgets/sintong_guiin_cta.dart';
import 'sintong_home/widgets/sintong_service_tile.dart';
import 'sintong_home/widgets/sintong_free_pass_bar.dart';
import 'sintong_home/widgets/sintong_dynamic_section_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _todayFortuneSectionKey = GlobalKey();
  bool _isGridView = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletProvider>().load();
      context.read<AttendanceProvider>().load();
      context.read<PassProvider>().load();
      context.read<NotificationProvider>().load();
      context.read<HealingQuoteProvider>().load();
      _loadHomePageConfigAndVerify();
      _maybeShowWelcomeRewardModal();
    });
  }

  /// [Phase C] `AuthProvider.lastSignupReward`가 존재하고(=이번 세션에서
  /// 방금 회원가입이 성공해 홈에 처음 도달) 아직 서버 필드로 수령
  /// 처리되지 않았을 때만 웰컴 리워드 팝업을 1회 노출한다(기존 로직 그대로).
  Future<void> _maybeShowWelcomeRewardModal() async {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    final reward = auth.lastSignupReward;
    if (user == null || reward == null || user.welcomeGiftClaimed) return;

    final amount = (reward['amount'] as num?)?.toInt() ?? 0;
    if (amount <= 0 || !mounted) return;

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    await WelcomeRewardModal.show(
      context,
      amount: amount,
      onClaim: () {
        auth.claimWelcomeGift();
      },
    );
  }

  /// [Stage2 결함수정 — 결함-E05-01] HomePageConfigProvider.load() 결과를
  /// 실제로 화면 렌더링에 반영하기 위한 최초 로드 트리거.
  ///
  /// [수정 이력] 과거에는 이 함수가 `configProvider.load()` 후 결과를
  /// `debugPrint`로만 출력하고 끝나, 관리자가 admin_web에서 홈 섹션의
  /// 순서/노출 여부를 바꿔도 앱 화면이 전혀 반영하지 않는 결함(E-05,
  /// "미구현" 판정)이 있었다. `configProvider`는 `ChangeNotifier`이고
  /// `build()`에서 `context.watch<HomePageConfigProvider>()`로 구독하고
  /// 있으므로, 여기서는 `load()` 호출만으로 충분하다 — 로드가 끝나면
  /// `notifyListeners()`가 `build()`를 재실행시켜 `visibleSections(ctx)`
  /// 결과가 실제 섹션 순서/노출로 그대로 반영된다(아래 `build()` 참고).
  Future<void> _loadHomePageConfigAndVerify() async {
    final configProvider = context.read<HomePageConfigProvider>();
    await configProvider.load();
    if (!mounted) return;
    debugPrint(
      '[E05-01] HomePageConfig load 완료 상태=${configProvider.state.isSuccess}, '
      'usingCache=${configProvider.usingCache}, '
      '전체 섹션=${configProvider.rawSections.length}',
    );
  }

  /// [Stage2 결함수정 — 결함-E05-01] 관리자 CMS 섹션 키를 기존 전용 위젯에
  /// 매핑한다. 매핑되는 전용 위젯이 없는 섹션(lucky_number,
  /// wish_community_preview, happy_money_earn/use, subscription_promo 등)은
  /// `SintongDynamicSectionCard`로 관리자가 입력한 title/subtitle/buttonText/
  /// badgeText 값을 그대로 렌더링한다.
  Widget _buildSectionWidget(
    PageSectionModel section,
    List<SintongServiceSpec> services,
  ) {
    switch (section.sectionKey) {
      case 'pass_status_bar':
      case 'pass_promo':
        // 둘 다 "열림패스 상태/유도"를 다루므로 기존 C-07 위젯(실시간
        // 남은시간 표시)을 그대로 재사용한다. displayRules(open_pass_inactive
        // 등)는 이미 evaluator가 필터링했으므로 여기서는 항상 렌더링한다.
        return const SintongFreePassBar();
      case 'hero_fortune_summary':
        // 기존 C-03(힐링바)+C-04(스토리히어로)+C-05(귀인지도 CTA) 블록이
        // "오늘의 대표 운세" 개념과 가장 가까우므로 그대로 매핑한다.
        return KeyedSubtree(
          key: _todayFortuneSectionKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SintongHealingBar(),
              const SizedBox(height: SintongHomeSpacing.sectionGap),
              SintongStoryHero(onTap: _openGuiinMap),
              const SizedBox(height: 14),
              SintongGuiinCta(onTap: _openGuiinMap),
            ],
          ),
        );
      case 'fortune_category_grid':
        // 기존 C-06 서비스 리스트/그리드(4개: 정통사주/타로/소원방/손금관상)
        return _isGridView
            ? GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: SintongHomeSpacing.cardGap,
                crossAxisSpacing: SintongHomeSpacing.cardGap,
                childAspectRatio: 0.98,
                children: services
                    .map((s) => SintongServiceGridTile(spec: s))
                    .toList(),
              )
            : Column(
                children: [
                  for (int i = 0; i < services.length; i++) ...[
                    SintongServiceTile(spec: services[i]),
                    if (i != services.length - 1)
                      const SizedBox(height: SintongHomeSpacing.cardGap),
                  ],
                ],
              );
      default:
        // lucky_number / wish_community_preview / happy_money_earn /
        // happy_money_use / subscription_promo 등 전용 위젯이 없는 섹션.
        return SintongDynamicSectionCard(section: section);
    }
  }

  void _openGuiinMap() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const GuinjiLandingScreen()));
  }

  List<SintongServiceSpec> _buildServiceSpecs() {
    return [
      SintongServiceSpec(
        thumbAsset: 'assets/images/sintong_home/svc-saju.jpg',
        name: '정통사주',
        description: '정통사주 풀이하기',
        actionStyle: SintongActionStyle.primary,
        onTap: () =>
            Navigator.of(context).pushNamed(JeontongEightyMatrix.gateRoute),
      ),
      SintongServiceSpec(
        thumbAsset: 'assets/images/sintong_home/svc-tarot.jpg',
        name: '타로',
        description: '타로 뽑아보기',
        actionStyle: SintongActionStyle.dark,
        onTap: () => Navigator.of(context).pushNamed(AppRouter.tarotIntroRoute),
      ),
      SintongServiceSpec(
        thumbAsset: 'assets/images/sintong_home/svc-wish.jpg',
        name: '소원방',
        description: '소원을 촛불에 봉인하세요',
        actionStyle: SintongActionStyle.primary,
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const WishRoomEntryGate())),
      ),
      SintongServiceSpec(
        thumbAsset: 'assets/images/sintong_home/svc-palm.jpg',
        name: '손금/관상',
        description: '손을 읽어보세요',
        actionStyle: SintongActionStyle.rose,
        cardWarm: true,
        onTap: () => showFacePalmSelectSheet(context),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final services = _buildServiceSpecs();

    // [Stage2 결함수정 — 결함-E05-01] admin_web이 발행한 홈 섹션 구성을
    // 실제 렌더링 순서/노출에 반영한다. `context.watch`로 구독하므로
    // `HomePageConfigProvider.load()` 완료 시 자동으로 이 build()가 재실행된다.
    final configProvider = context.watch<HomePageConfigProvider>();
    final auth = context.watch<AuthProvider>();
    final access = context.watch<AccessChecker>();
    final wallet = context.watch<WalletProvider>();

    final visCtx = HomeVisibilityContext(
      isLoggedIn: auth.isLoggedIn,
      now: DateTime.now(),
      openPassActive: access.openPassState.isActive,
      luckPouchBalance: wallet.balance,
      platform: HomeVisibilityContext.currentPlatformKey(),
    );

    // 서버 구성이 아직 로드되지 않았거나(초기 프레임) 로드에 실패해 캐시도
    // 없는 경우(`shouldFallbackToStatic`)에는 기존 하드코딩 고정 순서로
    // 폴백한다 — 관리자 설정이 전혀 없던 과거 동작과 동일하게 화면이
    // 비어버리는 회귀를 방지한다.
    final rawSections = configProvider.rawSections;
    final useDynamicSections =
        rawSections.isNotEmpty && !configProvider.shouldFallbackToStatic;
    final visibleSections = useDynamicSections
        ? configProvider.visibleSections(visCtx)
        : <PageSectionModel>[];

    return Scaffold(
      backgroundColor: SintongHomeColors.scaffoldBackground,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            SintongHomeSpacing.screenHPad,
            8,
            SintongHomeSpacing.screenHPad,
            24,
          ),
          children: [
            // C-01 브랜드 앱바 (항상 최상단 고정 — CMS 섹션 목록에 없는
            // 구조적 헤더이므로 동적 배선 대상에서 제외)
            const SintongBrandAppBar(),
            const SizedBox(height: SintongHomeSpacing.sectionGap),

            // [G-02 치명결함수정] CMS 제휴광고 배너(admin_web에서 등록/활성화한
            // 배너를 관리자가 즉시 앱에 반영할 수 있어야 하는 요건, home_top
            // position). 활성 배너가 없으면 공간을 차지하지 않고 사라진다.
            const AdBannerWidget(position: 'home_top'),
            const SizedBox(height: SintongHomeSpacing.sectionGap),

            // C-02 전체보기 칩 + 그리드 스위치 (CMS 섹션 목록에 없는 UI
            // 컨트롤이므로 동적 배선 대상에서 제외, 항상 고정 위치)
            SintongModeChipRow(
              onChipTap: () =>
                  Navigator.of(context).pushNamed('/home/all-categories'),
              isGrid: _isGridView,
              onToggleGrid: (v) => setState(() => _isGridView = v),
            ),
            const SizedBox(height: SintongHomeSpacing.sectionGap),

            // [E05-01 핵심 수정] 이하 관리자(admin_web)가 발행한 섹션들을
            // sortOrder 순서 그대로, isVisible/status/displayRules를 모두
            // 통과한 것만 렌더링한다. 서버 구성 로드 실패 시(useDynamicSections
            // ==false)에는 과거와 동일한 고정 순서(힐링바+스토리히어로+
            // 귀인지도 → 서비스그리드 → 프리패스바)로 폴백한다.
            if (useDynamicSections)
              for (int i = 0; i < visibleSections.length; i++) ...[
                _buildSectionWidget(visibleSections[i], services),
                if (i != visibleSections.length - 1)
                  const SizedBox(height: SintongHomeSpacing.sectionGap),
              ]
            else ...[
              // C-03 힐링바 + C-04 스토리히어로 + C-05 귀인지도 CTA
              KeyedSubtree(
                key: _todayFortuneSectionKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SintongHealingBar(),
                    const SizedBox(height: SintongHomeSpacing.sectionGap),
                    SintongStoryHero(onTap: _openGuiinMap),
                    const SizedBox(height: 14),
                    SintongGuiinCta(onTap: _openGuiinMap),
                  ],
                ),
              ),
              const SizedBox(height: SintongHomeSpacing.sectionGap),

              // C-06 서비스 리스트/그리드(4개: 정통사주/타로/소원방/손금·관상)
              _isGridView
                  ? GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: SintongHomeSpacing.cardGap,
                      crossAxisSpacing: SintongHomeSpacing.cardGap,
                      childAspectRatio: 0.98,
                      children: services
                          .map((s) => SintongServiceGridTile(spec: s))
                          .toList(),
                    )
                  : Column(
                      children: [
                        for (int i = 0; i < services.length; i++) ...[
                          SintongServiceTile(spec: services[i]),
                          if (i != services.length - 1)
                            const SizedBox(
                              height: SintongHomeSpacing.cardGap,
                            ),
                        ],
                      ],
                    ),
              const SizedBox(height: SintongHomeSpacing.sectionGap),

              // C-07 프리패스 바
              const SintongFreePassBar(),
            ],

            const SizedBox(height: 10),
            const AdmobTestBanner(),
          ],
        ),
      ),
    );
  }
}
