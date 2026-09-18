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

  /// [6-4-B] HomePageConfigProvider.load() 배선 검증(기존 로직 그대로,
  /// 화면 렌더링에는 반영하지 않는 디버그 전용 경로).
  Future<void> _loadHomePageConfigAndVerify() async {
    final configProvider = context.read<HomePageConfigProvider>();
    await configProvider.load();
    if (!mounted) return;

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
            // C-01 브랜드 앱바
            const SintongBrandAppBar(),
            const SizedBox(height: SintongHomeSpacing.sectionGap),

            // [G-02 치명결함수정] CMS 제휴광고 배너(admin_web에서 등록/활성화한
            // 배너를 관리자가 즉시 앱에 반영할 수 있어야 하는 요건, home_top
            // position). 위젯/Provider/Repository는 모두 완성되어 있었으나
            // 어떤 화면에서도 실제로 인스턴스화되지 않아(grep 0건) 사용자가
            // 영원히 배너를 볼 수 없던 결함을 수정 — 여기서 최초로 배치한다.
            // 활성 배너가 없으면 fallback 없이 공간을 차지하지 않고 사라진다.
            const AdBannerWidget(position: 'home_top'),
            const SizedBox(height: SintongHomeSpacing.sectionGap),

            // C-02 전체보기 칩 + 그리드 스위치
            SintongModeChipRow(
              onChipTap: () =>
                  Navigator.of(context).pushNamed('/home/all-categories'),
              isGrid: _isGridView,
              onToggleGrid: (v) => setState(() => _isGridView = v),
            ),
            const SizedBox(height: SintongHomeSpacing.sectionGap),

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
                          const SizedBox(height: SintongHomeSpacing.cardGap),
                      ],
                    ],
                  ),
            const SizedBox(height: SintongHomeSpacing.sectionGap),

            // C-07 프리패스 바
            const SintongFreePassBar(),

            const SizedBox(height: 10),
            const AdmobTestBanner(),
          ],
        ),
      ),
    );
  }
}
