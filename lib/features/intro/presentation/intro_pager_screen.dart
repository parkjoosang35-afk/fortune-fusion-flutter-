import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
/// - 0: 페이지2 "오늘의 결이 무슨 빛인지"(오늘의 운세 · crystal.png)
/// - 1: 페이지3 "내 곁의 귀인은 몇 명일까"(귀인지도 · scroll.png + 피처 3개)
/// - 2: 페이지4 CTA "이제 신통방통과 함께"(celebrating.png)
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

  Widget _buildPage2(IntroConfigModel config) {
    return Column(
      children: [
        Expanded(
          child: IntroPageContent(
            eyebrow: 'CHAPTER · N°01',
            characterAsset: 'assets/images/home/doryeong/crystal.png',
            characterSize: 200,
            title: config.card1Title,
            titleFontSize: 30,
            titleHighlight: '무슨 빛',
            titleHighlightColors: const [
              Color(0xFFA8E3D5),
              IntroPalette.crystal,
            ],
            subtitle: config.card1Description,
          ),
        ),
        const SizedBox(height: 12),
        IntroProgressDots(activeIndex: 1),
        const SizedBox(height: 16),
        _buildNextButton(),
      ],
    );
  }

  Widget _buildPage3(IntroConfigModel config) {
    return Column(
      children: [
        Expanded(
          child: IntroPageContent(
            eyebrow: 'CHAPTER · N°02',
            characterAsset: 'assets/images/home/doryeong/scroll.png',
            characterSize: 150,
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
          ),
        ),
        const SizedBox(height: 12),
        IntroProgressDots(activeIndex: 2),
        const SizedBox(height: 16),
        _buildNextButton(),
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
