import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../application/intro_config_provider.dart';
import '../application/intro_state_provider.dart';
import 'intro_palette.dart';
import 'intro_text_styles.dart';
import 'widgets/intro_eyebrow_label.dart';
import 'widgets/onboarding_action_buttons.dart';
import 'widgets/onboarding_hero_frame.dart';
import 'widgets/onboarding_notice_sheet.dart';
import 'widgets/onboarding_rise_in.dart';
import 'widgets/onboarding_star_petal_field.dart';

/// [온보딩 화면 교체 2026-10-11 — `design_handoff_onboarding_redesign.zip`
/// 전면 반영] 스플래시(1단계) 다음, 그리고 [OnboardingVideoScreen](5대
/// 기능 소개 영상) 다음에 이어지는 비로그인 첫 진입 화면.
///
/// [디자인 교체 범위] README "기능과 라우팅은 바꾸지 않아요. 버튼 4개는
/// 지금과 같은 곳으로 이동해요"를 그대로 따른다 — 아래 4개 콜백
/// (`_goSignup`/`_goLogin`/바텀시트/`_startAsGuest`)은 기존
/// [IntroCTASection] 시절과 동일한 목적지를 유지한 채, 시각 레이어
/// (배경·히어로·카피·버튼·애니메이션)만 `Onboarding.html` 기준으로
/// 전면 재구성했다.
///
/// [신규] "재미·참고용" 콘텐츠 안내는 더 이상 별도 페이지
/// (`/policy/notice`)로 이동하지 않고 바텀시트([showOnboardingNoticeSheet])로
/// 바로 연다(README §1-4/개발지시서 §06). 기존 [PolicyNoticeScreen]과
/// 라우트 자체는 다른 참조 가능성에 대비해 보존한다.
///
/// [진입 시퀀스 1회 재생] README "진입 시퀀스는 세션당 1회만 재생해
/// 주세요. 다시 들어오면 A1–A4는 바로 최종 상태로 보여요"를
/// SharedPreferences 키로 추적한다([_kIntroPlayedKey]) — 세션(=앱
/// 프로세스) 단위가 아니라 "최초 1회"로 구현했다. 스플래시 이후 이
/// 화면은 사실상 비로그인 사용자가 반복적으로 재방문할 수 있는
/// 화면이 아니라, 최초 온보딩 완료 시 introSeen=true가 되어 이후
/// 다시 보이지 않기 때문에 "앱 설치 후 최초 1회"와 "세션당 1회"가
/// 실질적으로 거의 같은 의미를 가진다.
class IntroPagerScreen extends StatefulWidget {
  const IntroPagerScreen({super.key});

  @override
  State<IntroPagerScreen> createState() => _IntroPagerScreenState();
}

/// README §1-4 타임라인 상수 — 값 자체를 바꾸지 않아야 "픽셀/타이밍
/// 단위까지 Onboarding.html과 동일하게" 재현할 수 있다.
class _OnboardingTiming {
  _OnboardingTiming._();

  static const double eyebrowStart = 0.9;
  static const double h1Start = 1.1;
  static const double subStart = 1.3;
  static const double riseDuration = 1.2;

  static const double primaryBtnStart = 1.55;
  static const double loginBtnStart = 1.7;
  static const double footerStart = 1.9;

  /// 전체 등장 시퀀스 길이 — 마지막 rise(1.9s 지연 + 1.2s 길이) 완료 지점.
  static const double totalDuration = footerStart + riseDuration;
}

class _IntroPagerScreenState extends State<IntroPagerScreen>
    with TickerProviderStateMixin {
  static const String _kIntroPlayedKey = 'onboarding_redesign_intro_played_v1';

  late final AnimationController _introController;
  bool _reduceMotion = false;
  bool _skipEntryAnimation = false; // true면 즉시 최종 상태(재방문).
  bool _didCheckPlayed = false;

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: (_OnboardingTiming.totalDuration * 1000).round(),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 관리자 설정(문구/이미지/보상수량)을 로드 — 실패 시 fallback 상수로 즉시 대체됨.
      context.read<IntroConfigProvider>().load();
      _resolveIntroPlayed();
    });
  }

  Future<void> _resolveIntroPlayed() async {
    bool alreadyPlayed = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      alreadyPlayed = prefs.getBool(_kIntroPlayedKey) ?? false;
      if (!alreadyPlayed) {
        await prefs.setBool(_kIntroPlayedKey, true);
      }
    } catch (_) {
      // 조회 실패 시 안전하게 애니메이션을 1회 재생한다(최악의 경우
      // 재방문해도 다시 재생되는 정도이며 화면 진행을 막지는 않음).
    }
    if (!mounted) return;
    setState(() {
      _skipEntryAnimation = alreadyPlayed;
      _didCheckPlayed = true;
    });
    if (alreadyPlayed || _reduceMotion) {
      _introController.value = 1.0;
    } else {
      _introController.forward();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.of(context).disableAnimations;
    if (reduce != _reduceMotion) {
      _reduceMotion = reduce;
      // README "구현 규칙 — prefers-reduced-motion이면 최종 상태 즉시".
      if (reduce && _didCheckPlayed) {
        _introController.value = 1.0;
      }
    }
  }

  @override
  void dispose() {
    _introController.dispose();
    super.dispose();
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

  void _openNoticeSheet() {
    showOnboardingNoticeSheet(context);
  }

  @override
  Widget build(BuildContext context) {
    // [온보딩 화면 교체 2026-10-11] config.ctaTitle/ctaSubtitle(admin 설정 카피)은
    // 이 화면에서 더 이상 사용하지 않는다. 핸드오프 요구사항이 "H1/부제 문구와
    // 강조색(당신의 이야기)까지 Onboarding.html 원문과 정확히 일치"를 요구하며,
    // 관리자 입력값으로는 강조 스팬 위치나 줄바꿈 지점을 재현할 방법이 없기
    // 때문이다. featureItems(페이지3)가 이미 같은 이유로 fallback 고정값만 쓰는
    // 전례를 그대로 따른다 — admin_web의 ctaTitle/ctaSubtitle 필드 자체는 하위
    // 호환을 위해 스키마에 유지하되, 실제로는 이 화면이 참조하지 않는다.
    final config = context.watch<IntroConfigProvider>().config;
    final showReduced = _reduceMotion || _skipEntryAnimation;

    return Scaffold(
      body: DecoratedBox(
        // Onboarding.html 배경 3단 그라디언트 + 라디얼 2겹.
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              IntroPalette.backgroundTop,
              IntroPalette.backgroundMid,
              IntroPalette.backgroundBottom,
            ],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // 라디얼 그라디언트 2겹(좌상단 크리스탈 / 우하단 glow).
            const Positioned.fill(child: _AmbientRadials()),
            Positioned.fill(
              child: OnboardingStarPetalField(reduceMotion: showReduced),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: AnimatedBuilder(
                  animation: _introController,
                  builder: (context, _) {
                    final elapsed = showReduced
                        ? _OnboardingTiming.totalDuration
                        : _introController.value *
                              _OnboardingTiming.totalDuration;
                    return _OnboardingContent(
                      elapsedSeconds: elapsed,
                      reduceMotion: showReduced,
                      showGuestHint: config.showGuestHint,
                      onSignup: _goSignup,
                      onLogin: _goLogin,
                      onDisclaimer: _openNoticeSheet,
                      onStartAsGuest: _startAsGuest,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 배경 라디얼 그라디언트 2겹(`.screen` background 2~3번째 레이어).
class _AmbientRadials extends StatelessWidget {
  const _AmbientRadials();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.7, -1.0), // 15% 0%
          radius: 1.1,
          colors: [
            IntroPalette.crystal.withValues(alpha: 0.10),
            Colors.transparent,
          ],
          stops: const [0.0, 0.6],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.8, 0.7), // 90% 85%
            radius: 1.0,
            colors: [
              IntroPalette.primary.withValues(alpha: 0.12),
              Colors.transparent,
            ],
            stops: const [0.0, 0.6],
          ),
        ),
      ),
    );
  }
}

/// Hero + Copy + Actions 전체 컬럼. 화면 높이에 따라 Hero 크기를
/// 조정하는 반응형 규칙(README §반응형 — `max-height:720px`)도 이
/// 레벨에서 처리한다.
class _OnboardingContent extends StatelessWidget {
  const _OnboardingContent({
    required this.elapsedSeconds,
    required this.reduceMotion,
    required this.showGuestHint,
    required this.onSignup,
    required this.onLogin,
    required this.onDisclaimer,
    required this.onStartAsGuest,
  });

  final double elapsedSeconds;
  final bool reduceMotion;
  final bool showGuestHint;
  final VoidCallback onSignup;
  final VoidCallback onLogin;
  final VoidCallback onDisclaimer;
  final VoidCallback onStartAsGuest;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    final isCompact = height <= 720; // README §반응형.
    final heroWidthFactor = isCompact ? 0.64 : 0.78;
    final heroMaxWidth = isCompact ? 250.0 : 300.0;
    final titleFontSize = isCompact ? 26.0 : 30.0;
    final copyTopGap = isCompact ? 18.0 : 26.0;
    // README §반응형 — `.hero{width:min(64vw,250px)}` 그대로 min()으로 계산.
    final heroWidth = math.min(heroMaxWidth, screenWidth * heroWidthFactor);

    return Column(
      children: [
        SizedBox(
          width: heroWidth,
          child: OnboardingHeroFrame(
            heroAsset: 'assets/images/intro/hero-fullbody.png',
            elapsedSeconds: elapsedSeconds,
            reduceMotion: reduceMotion,
          ),
        ),
        SizedBox(height: copyTopGap),
        OnboardingRiseIn(
          elapsedSeconds: elapsedSeconds,
          startSeconds: _OnboardingTiming.eyebrowStart,
          durationSeconds: _OnboardingTiming.riseDuration,
          child: const _EyebrowRow(),
        ),
        const SizedBox(height: 14),
        OnboardingRiseIn(
          elapsedSeconds: elapsedSeconds,
          startSeconds: _OnboardingTiming.h1Start,
          durationSeconds: _OnboardingTiming.riseDuration,
          // Onboarding.html: `이제, <span class="g">당신의 이야기</span>를<br>펼쳐볼까요`.
          // `.g{color:var(--glow);text-shadow:0 0 22px var(--glow-shadow)}` —
          // 그라디언트가 아니라 단색 강조 + glow shadow이므로 RichText/TextSpan으로
          // 재현한다(기본 h1 자체에는 text-shadow가 없어 base 스타일에서 title()의
          // 기본 shadows를 제거한다).
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: IntroTextStyles.title(
                fontSize: titleFontSize,
              ).copyWith(shadows: const []),
              children: [
                const TextSpan(text: '이제, '),
                TextSpan(
                  text: '당신의 이야기',
                  style: TextStyle(
                    color: IntroPalette.primary,
                    shadows: const [
                      Shadow(
                        color: IntroPalette.glowShadow,
                        blurRadius: 22,
                      ),
                    ],
                  ),
                ),
                const TextSpan(text: '를\n펼쳐볼까요'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        OnboardingRiseIn(
          elapsedSeconds: elapsedSeconds,
          startSeconds: _OnboardingTiming.subStart,
          durationSeconds: _OnboardingTiming.riseDuration,
          child: Text(
            '달빛 아래 조용히 기다리고 있었어요',
            textAlign: TextAlign.center,
            style: IntroTextStyles.sub(),
          ),
        ),
        const Spacer(),
        OnboardingRiseIn(
          elapsedSeconds: elapsedSeconds,
          startSeconds: _OnboardingTiming.primaryBtnStart,
          durationSeconds: _OnboardingTiming.riseDuration,
          child: OnboardingPrimaryButton(
            label: '시작하기',
            icon: '✧',
            reduceMotion: reduceMotion,
            // README "버튼은 1.55s부터 탭할 수 있어야 해요" — rise가 그
            // 시점부터 시작하므로, 탭 가능 여부를 그대로 그 시점 이후로
            // 묶는다(이전에는 opacity 0이라 사실상 탭이 불가능함).
            enabled: elapsedSeconds >= _OnboardingTiming.primaryBtnStart,
            onTap: onSignup,
          ),
        ),
        const SizedBox(height: 12),
        OnboardingRiseIn(
          elapsedSeconds: elapsedSeconds,
          startSeconds: _OnboardingTiming.loginBtnStart,
          durationSeconds: _OnboardingTiming.riseDuration,
          child: OnboardingGhostButton(
            label: '이미 계정이 있어요',
            icon: '☾',
            onTap: onLogin,
          ),
        ),
        OnboardingRiseIn(
          elapsedSeconds: elapsedSeconds,
          startSeconds: _OnboardingTiming.footerStart,
          durationSeconds: _OnboardingTiming.riseDuration,
          child: Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Column(
              children: [
                TextButton(
                  onPressed: onDisclaimer,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 15,
                        height: 15,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: IntroPalette.cardBorder),
                        ),
                        child: Text(
                          'i',
                          style: IntroTextStyles.eyebrow(
                            color: IntroPalette.primary,
                          ).copyWith(fontSize: 9, letterSpacing: 0),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '"재미·참고용" 콘텐츠 안내',
                        style: IntroTextStyles.linkButton().copyWith(
                          fontSize: 12,
                          color: IntroPalette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // [기존 결정사항 유지] 게스트 모드 — 핸드오프에는
                // "회원가입 없이 둘러보기" 링크로 이미 존재하는 4번째
                // 버튼이다(README 인터랙션 표). showGuestHint로
                // on/off(기존 관리자 설정 재사용).
                if (showGuestHint)
                  TextButton(
                    onPressed: onStartAsGuest,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '회원가입 없이 둘러보기',
                          style: IntroTextStyles.linkButton().copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: IntroPalette.textPrimary.withValues(
                              alpha: 0.8,
                            ),
                            decoration: TextDecoration.underline,
                            decorationColor: IntroPalette.cardBorder,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '→',
                          style: TextStyle(
                            color: IntroPalette.primary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Eyebrow — 양옆 장식선 + "READY · TO · BEGIN".
class _EyebrowRow extends StatelessWidget {
  const _EyebrowRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _eyebrowLine(),
        const SizedBox(width: 10),
        const IntroEyebrowLabel('READY · TO · BEGIN'),
        const SizedBox(width: 10),
        Transform.flip(flipX: true, child: _eyebrowLine()),
      ],
    );
  }

  Widget _eyebrowLine() {
    return Container(
      width: 22,
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            IntroPalette.cardBorder,
            IntroPalette.primary,
          ],
        ),
      ),
    );
  }
}
