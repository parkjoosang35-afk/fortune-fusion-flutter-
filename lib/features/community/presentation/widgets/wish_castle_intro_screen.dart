import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';

const _introDoneKey = 'wish_castle_intro_completed';

/// [소원성(Wish Castle) 확장] 소원성 인트로 + 최초 1회 온보딩.
///
/// [설계] 마스터 기획의 "소원성 인트로"(밤하늘·별·성·촛불 + 타이핑 텍스트 연출)와
/// "최초 1회 온보딩"(5단계 안내)을 화면 하나로 통합해 구현한다. 두 기능을 별도
/// Navigator 라우트로 나누면 뒤로가기/생명주기 관리가 불필요하게 늘어나므로
/// (03§9.2 과설계 방지 원칙), 하나의 풀스크린 오버레이 안에서 "인트로 단계"→
/// "온보딩 단계"로 내부 상태만 전환한다.
///
/// AI 나레이션은 이번 구현 범위에서 BGM 없이 텍스트 연출(페이드인 타이핑)만
/// 제공한다(사용자 승인된 결정사항 - AI 응원 메시지와 동일 정책). 앱 전역
/// `onboarding_completed`(로그인 전 앱 소개)와는 별개의 독립 플래그로 관리해
/// 기존 로그인 플로우에 영향을 주지 않는다.
Future<void> showWishCastleIntroIfNeeded(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  final done = prefs.getBool(_introDoneKey) ?? false;
  if (done || !context.mounted) return;
  await Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (_, __, ___) => const WishCastleIntroScreen(),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class WishCastleIntroScreen extends StatefulWidget {
  const WishCastleIntroScreen({super.key});

  @override
  State<WishCastleIntroScreen> createState() => _WishCastleIntroScreenState();
}

enum _Stage { intro, onboarding }

class _WishCastleIntroScreenState extends State<WishCastleIntroScreen>
    with SingleTickerProviderStateMixin {
  _Stage _stage = _Stage.intro;
  late final AnimationController _starController;
  late final List<_Star> _stars;
  String _typed = '';
  static const _fullText = '많은 사람의 마음이 모여\n소원의 촛불이 자라나는 곳';
  Timer? _typeTimer;
  final _pageController = PageController();
  int _pageIndex = 0;

  static const _onboardingPages = [
    _OnboardPage('🏰', '소원성에 오신 것을 환영해요', '이곳은 여러분의 소원을 함께\n응원하고 지켜보는 공간이에요.'),
    _OnboardPage('🕯️', '촛불이 자라나요', '많은 분들의 응원을 받을수록\n작은 촛불이 5단계로 성장해요.'),
    _OnboardPage('🧧', '행복머니로 응원해요', '실제 행복머니가 차감되지 않는\n상징적인 응원 마음이에요.'),
    _OnboardPage('🕐', '여정을 돌아볼 수 있어요', '소원이 남긴 발걸음을\n타임라인으로 살펴보세요.'),
    _OnboardPage('🌟', '이야기를 나눠요', '가장 밝은 불꽃에 닿으면\n성취 후기를 남길 수 있어요.'),
  ];

  @override
  void initState() {
    super.initState();
    _starController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    final rand = Random(7);
    _stars = List.generate(
      40,
      (i) => _Star(
        dx: rand.nextDouble(),
        dy: rand.nextDouble() * 0.6,
        size: 1.0 + rand.nextDouble() * 2.2,
        phase: rand.nextDouble(),
      ),
    );
    _startTyping();
  }

  void _startTyping() {
    var i = 0;
    _typeTimer = Timer.periodic(const Duration(milliseconds: 60), (timer) {
      if (i >= _fullText.length) {
        timer.cancel();
        Timer(const Duration(milliseconds: 900), () {
          if (mounted) setState(() => _stage = _Stage.onboarding);
        });
        return;
      }
      i++;
      if (mounted) setState(() => _typed = _fullText.substring(0, i));
    });
  }

  @override
  void dispose() {
    _typeTimer?.cancel();
    _starController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_introDoneKey, true);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepSpace,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _starController,
                builder: (context, _) {
                  return CustomPaint(
                    size: Size.infinite,
                    painter: _StarFieldPainter(_stars, _starController.value),
                  );
                },
              ),
            ),
            _stage == _Stage.intro
                ? _buildIntro(context)
                : _buildOnboarding(context),
          ],
        ),
      ),
    );
  }

  Widget _buildIntro(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🏰', style: TextStyle(fontSize: 72)),
            const SizedBox(height: AppSpacing.lg),
            const Text('🕯️', style: TextStyle(fontSize: 36)),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              height: 60,
              child: Text(
                _typed,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  height: 1.7,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOnboarding(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _onboardingPages.length,
            onPageChanged: (i) => setState(() => _pageIndex = i),
            itemBuilder: (context, i) {
              final page = _onboardingPages[i];
              return Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(page.emoji, style: const TextStyle(fontSize: 56)),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      page.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      page.desc,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13.5,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _onboardingPages.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _pageIndex == i ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: _pageIndex == i ? AppColors.secondary : Colors.white24,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: AppButton(
            label: _pageIndex == _onboardingPages.length - 1 ? '시작하기' : '다음',
            onPressed: () {
              if (_pageIndex == _onboardingPages.length - 1) {
                _finish();
              } else {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                );
              }
            },
          ),
        ),
      ],
    );
  }
}

class _OnboardPage {
  final String emoji;
  final String title;
  final String desc;
  const _OnboardPage(this.emoji, this.title, this.desc);
}

class _Star {
  final double dx;
  final double dy;
  final double size;
  final double phase;
  const _Star({
    required this.dx,
    required this.dy,
    required this.size,
    required this.phase,
  });
}

class _StarFieldPainter extends CustomPainter {
  final List<_Star> stars;
  final double t;
  _StarFieldPainter(this.stars, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    for (final s in stars) {
      final twinkle = (sin((t + s.phase) * 2 * pi) * 0.5 + 0.5).clamp(0.0, 1.0);
      paint.color = Colors.white.withValues(alpha: 0.2 + twinkle * 0.6);
      canvas.drawCircle(
        Offset(s.dx * size.width, s.dy * size.height),
        s.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StarFieldPainter oldDelegate) => true;
}
