import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_unified_style.dart';
import '../application/intro_config_provider.dart';
import '../application/intro_state_provider.dart';
import '../domain/intro_config_model.dart';
import 'widgets/intro_card_widget.dart';
import 'widgets/intro_cta_section.dart';
import 'widgets/intro_skip_action.dart';

/// [인트로 전면 개편 - 2~4단계] 스플래시(1단계) 다음에 이어지는 인트로 페이저.
///
/// 3페이지 구성:
/// - 0: 카드1 "광고 한 번으로, 1시간 동안 자유롭게"(프리패스)
/// - 1: 카드2 "복주머니는 무료로 모으고, 자유롭게 써요"(복주머니)
/// - 2: 시작화면(CTA) "이제 신통방통을 시작해보세요"
///
/// [기존 구조 재사용 원칙] 완료 처리(IntroStateProvider.markSeen/markSkipped)는
/// 기존 onboarding_screen.dart의 "onboarding_completed 저장 후 이동" 패턴을
/// 그대로 계승하되, 로그인 강제 없이 "바로 시작하기(비회원)"를 기본 동선으로
/// 추가한다.
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
    await context.read<IntroStateProvider>().markSkipped();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/home');
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

  @override
  Widget build(BuildContext context) {
    final config = context.watch<IntroConfigProvider>().config;
    final showSkip = config.showSkipButton && _index < _pageCount - 1;

    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // 상단 - 스킵 버튼(관리자 설정에 따라 마지막 페이지에서는 숨김)
            SizedBox(
              height: 44,
              child: Align(
                alignment: Alignment.centerRight,
                child: showSkip
                    ? IntroSkipAction(onSkip: _skip)
                    : const SizedBox.shrink(),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _index = i),
                children: [
                  _buildCard1(config),
                  _buildCard2(config),
                  _buildCTA(config),
                ],
              ),
            ),
            const SizedBox(height: UnifiedTokens.spaceLg),
            // 페이지 인디케이터(점) - 마지막 CTA 페이지에서는 숨김(버튼이 대신함).
            if (_index < _pageCount - 1) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pageCount,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _index == i ? 20 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _index == i
                          ? UnifiedColors.black
                          : UnifiedColors.border,
                      borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: UnifiedTokens.spaceXl),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: UnifiedTokens.screenPadding,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _next,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: UnifiedColors.black,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(UnifiedTokens.radiusPill),
                      ),
                    ),
                    child: Text(
                      '다음',
                      style: UnifiedText.bodyStrong(color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: UnifiedTokens.spaceXl),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCard1(IntroConfigModel config) {
    return IntroCardWidget(
      icon: Icons.lock_open_rounded,
      badgeText: '1시간',
      heroColor: UnifiedColors.cardMain,
      title: config.card1Title,
      description: config.card1Description,
    );
  }

  Widget _buildCard2(IntroConfigModel config) {
    return IntroCardWidget(
      icon: Icons.card_giftcard_rounded,
      heroColor: UnifiedColors.cardWish,
      showCounter: true,
      counterTarget: 12,
      title: config.card2Title,
      description: config.card2Description,
    );
  }

  Widget _buildCTA(IntroConfigModel config) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: IntroCTASection(
        title: config.ctaTitle,
        subtitle: config.ctaSubtitle,
        signupRewardText: config.signupRewardText,
        showGuestHint: config.showGuestHint,
        onStartAsGuest: _startAsGuest,
        onSignup: _goSignup,
        onLogin: _goLogin,
      ),
    );
  }
}
