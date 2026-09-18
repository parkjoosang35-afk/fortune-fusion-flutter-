import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../application/intro_config_provider.dart';
import '../application/intro_state_provider.dart';
import 'intro_palette.dart';
import 'widgets/intro_cta_section.dart';

/// [인트로 전면 개편 - 2~4단계 → 온보딩 영상 도입 후 1페이지로 축소]
/// 스플래시(1단계) 다음, 그리고 [OnboardingVideoScreen](5대 기능 소개
/// 27.58초 영상) 다음에 이어지는 인트로 화면.
///
/// [2026-XX 카드인트로 축소 - 사용자 지적 반영] 기존에는 이 화면이
/// 핸드오프 4장 캐러셀 중 페이지2("오늘의 결이 무슨 빛인지" · 오늘의
/// 운세)·페이지3("내 곁의 귀인은 몇 명일까" · 귀인지도)·페이지4(CTA)
/// 3페이지 구성이었다. 그런데 온보딩 영상 도입 이후 사용자가 정확히
/// 지적한 대로, 영상이 이미 5대 핵심 기능(귀인지도 포함)을 전부
/// 소개하므로 그 뒤에 페이지2·3을 다시 보여주는 것은 콘텐츠 중복이다.
/// 따라서 이 화면은 이제 CTA(페이지4) 한 장만 남기고, 기존
/// PageView·페이지2·페이지3·페이지 인디케이터·상단 스킵버튼(더 이상
/// "다음 페이지로 건너뛸" 대상이 없으므로)을 모두 제거했다.
///
/// [기존 구조 재사용 원칙] 완료 처리(IntroStateProvider.markSeen)는 기존
/// 로직을 그대로 유지한다 — "바로 시작하기(비회원)"도 그대로 유지.
class IntroPagerScreen extends StatefulWidget {
  const IntroPagerScreen({super.key});

  @override
  State<IntroPagerScreen> createState() => _IntroPagerScreenState();
}

class _IntroPagerScreenState extends State<IntroPagerScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 관리자 설정(문구/이미지/보상수량)을 로드 — 실패 시 fallback 상수로 즉시 대체됨.
      context.read<IntroConfigProvider>().load();
    });
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: IntroCTASection(
              title: config.ctaTitle,
              subtitle: config.ctaSubtitle,
              signupRewardText: config.signupRewardText,
              showGuestHint: config.showGuestHint,
              onStartAsGuest: _startAsGuest,
              onSignup: _goSignup,
              onLogin: _goLogin,
              onDisclaimer: _goDisclaimer,
            ),
          ),
        ),
      ),
    );
  }
}
