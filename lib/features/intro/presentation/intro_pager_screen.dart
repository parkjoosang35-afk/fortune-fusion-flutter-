import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/widgets/bangtong_seonyeo.dart';
import '../application/intro_config_provider.dart';
import '../application/intro_state_provider.dart';
import '../domain/intro_config_model.dart';
import 'intro_palette.dart';
import 'intro_text_styles.dart';
import 'widgets/intro_cta_section.dart';
import 'widgets/intro_page_content.dart';
import 'widgets/intro_progress_dots.dart';
import 'widgets/intro_skip_action.dart';

/// [인트로 전면 개편 - 2~4단계] 스플래시(1단계) 다음에 이어지는 인트로 페이저.
///
/// 3페이지 구성(핸드오프 4장 캐러셀 중 페이지2·3·4에 대응, 페이지1은 별도
/// SplashScreen):
/// - 0: 페이지2 "오늘의 결이 무슨 빛인지"(오늘의 운세)
/// - 1: 페이지3 "내 곁의 귀인은 몇 명일까"(귀인지도 · 피처 3개)
/// - 2: 페이지4 CTA "이제 신통방통과 함께"
///
/// [기존 구조 재사용 원칙] 완료 처리(IntroStateProvider.markSeen/markSkipped)는
/// 기존 onboarding_screen.dart의 "onboarding_completed 저장 후 이동" 패턴을
/// 그대로 계승하되, 로그인 강제 없이 "바로 시작하기(비회원)"를 기본 동선으로
/// 추가한다.
///
/// [2026 디자인 핸드오프 콘텐츠 전면 반영] 이전 버전(색상+캐릭터 이미지만
/// 교체)은 카드형 레이아웃(IntroCardWidget)과 옛 카피를 그대로 쓰고 있었다.
/// 이번 개정에서 `screens/01_Intro.html` 페이지2/3/4의 정확한 카피·구조
/// (eyebrow 라벨, accent 그라디언트 제목, 피처리스트 3개, CTA 버튼 문구/
/// 아이콘)를 1:1로 이식했다. 스플래시 별도 화면 구조 자체는 유지한다
/// (SplashScreen이 이미 부트스트랩 로직을 담당하고 있어 페이저에 통합하면
/// 로직 중복/분리 리스크가 커, 4페이지 완전 캐러셀 통합은 이번 범위에서
/// 제외했다 — 대신 인디케이터는 [IntroProgressDots]로 "4페이지 중 몇 번째"
/// 감각을 그대로 살렸다).
class IntroPagerScreen extends StatefulWidget {
  const IntroPagerScreen({super.key});

  @override
  State<IntroPagerScreen> createState() => _IntroPagerScreenState();
}

class _IntroPagerScreenState extends State<IntroPagerScreen> {
  final PageController _controller = PageController();
  int _index = 0;
  static const int _pageCount = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 관리자 설정(문구/이미지/보상수량)을 로드 — 실패 시 fallback 상수로 즉시 대체됨.
      context.read<IntroConfigProvider>().load();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_index < _pageCount - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _skip() async {
    // [핸드오프 라우팅] onSkipTap() → /auth/signup (페이지2·3의 건너뛰기).
    await context.read<IntroStateProvider>().markSeen(asGuest: false);
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/signup');
  }

  Future<void> _startAsGuest() async {
    await context.read<IntroStateProvider>().markSeen(asGuest: true);
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/home');
  }

  Future<void> _goSignup() async {
    await context.read<IntroStateProvider>().markSeen(asGuest: false);
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/signup');
  }

  Future<void> _goLogin() async {
    await context.read<IntroStateProvider>().markSeen(asGuest: false);
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/login');
  }

  void _goDisclaimer() {
    Navigator.of(context).pushNamed('/policy/notice');
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<IntroConfigProvider>().config;
    final showSkip = config.showSkipButton && _index < _pageCount - 1;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [IntroPalette.backgroundTop, IntroPalette.backgroundBottom],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                child: PageView(
                  controller: _controller,
                  onPageChanged: (i) => setState(() => _index = i),
                  children: [
                    _buildPage2(config),
                    _buildPage3(config),
                    _buildCTA(config),
                  ],
                ),
              ),
              // 상단 우측 - 스킵 버튼(핸드오프 .skip-btn 절대위치, 페이지2·3에서만).
              if (showSkip)
                Positioned(
                  top: 8,
                  right: 8,
                  child: IntroSkipAction(onSkip: _skip),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // [5차 수정 - dots/버튼 미표시 버그 근본 해결]
  // 기존에는 Column[Expanded(콘텐츠), dots, 버튼] 구조였다. 콘텐츠
  // (IntroPageContent) 내부에서 자체적으로 오버플로우를 스크롤 처리하고
  // 있음에도, 데스크톱 목업(WebMobileFrame)이 강제하는 특정 논리 뷰포트
  // 높이(예: 1280x800 창에서 계산되는 배율)에서는 dots/버튼이 화면에
  // 전혀 나타나지 않는 문제가 있었다. 원인을 렌더러 버그로 의심해
  // Transform.scale→FittedBox 교체까지 시도했으나 재현되어, 실제로는
  // "콘텐츠 영역이 필요로 하는 공간이 가용 공간보다 커서 하단 형제
  // 위젯이 밀려나는" 통상적인 레이아웃 문제였음이 최종 확인되었다.
  //
  // 해결: dots/버튼을 Column의 순차 배치 흐름에서 완전히 분리해 Stack +
  // Positioned(bottom: 0)로 화면 하단에 고정한다. 콘텐츠는
  // Positioned.fill(bottom: 하단 예약 높이)로 남은 영역을 모두 차지하고
  // 내부에서 스스로 스크롤하므로, 위쪽 콘텐츠가 아무리 넘쳐도 dots/버튼은
  // 어떤 뷰포트/배율에서도 항상 화면에 고정되어 보인다.
  static const double _bottomBarHeight = 12 + 44 + 16 + 52; // dots+버튼 예약 높이

  Widget _buildPage2(IntroConfigModel config) {
    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          bottom: _bottomBarHeight,
          child: IntroPageContent(
            eyebrow: 'CHAPTER · N°01',
            title: config.card1Title,
            titleFontSize: 30,
            titleHighlight: '무슨 빛',
            titleHighlightColors: const [
              Color(0xFFA8E3D5),
              IntroPalette.crystal,
            ],
            subtitle: config.card1Description,
            characterAsset: BangtongSeonyeoAssets.poseLightingCandle,
            characterHeroHeight: 300,
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IntroProgressDots(activeIndex: 1),
              const SizedBox(height: 16),
              _buildNextButton(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPage3(IntroConfigModel config) {
    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          bottom: _bottomBarHeight,
          child: IntroPageContent(
            eyebrow: 'CHAPTER · N°02',
            title: config.card2Title,
            titleFontSize: 26,
            titleHighlight: '귀인',
            titleHighlightColors: const [
              IntroPalette.gold,
              IntroPalette.primary,
            ],
            subtitle: config.card2Description,
            featureItems: config.featureItems,
            alignTop: true,
            characterAsset: BangtongSeonyeoAssets.mainHalfBody,
            characterHeroHeight: 220,
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IntroProgressDots(activeIndex: 2),
              const SizedBox(height: 16),
              _buildNextButton(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNextButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _next,
        style: ElevatedButton.styleFrom(
          backgroundColor: IntroPalette.primary,
          foregroundColor: IntroPalette.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text('다음', style: IntroTextStyles.btnPrimary()),
      ),
    );
  }

  Widget _buildCTA(IntroConfigModel config) {
    return IntroCTASection(
      title: config.ctaTitle,
      subtitle: config.ctaSubtitle,
      signupRewardText: config.signupRewardText,
      showGuestHint: config.showGuestHint,
      onStartAsGuest: _startAsGuest,
      onSignup: _goSignup,
      onLogin: _goLogin,
      onDisclaimer: _goDisclaimer,
    );
  }
}
