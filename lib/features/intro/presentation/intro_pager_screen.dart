import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../application/intro_config_provider.dart';
import '../application/intro_state_provider.dart';
import 'intro_palette.dart';
import 'widgets/onboarding_copy_carousel.dart';
import 'widgets/onboarding_entry_buttons.dart';
import 'widgets/onboarding_notice_sheet.dart';
import 'widgets/onboarding_orb.dart';
import 'widgets/onboarding_star_dust_field.dart';

/// [온보딩 전면 교체 2026-11 — `design_handoff_onboarding_v2.zip` 전면
/// 반영] 스플래시(1단계) 다음, 그리고 [OnboardingVideoScreen](5대 기능
/// 소개 영상) 다음에 이어지는 비로그인 첫 진입 화면.
///
/// [교체 배경] 이전 "아치형 히어로(한복 일러스트)" 디자인을 전면
/// 교체한다. README("기존 온보딩 화면... 전체 교체") 명시대로 배경
/// 그라데이션(3단 보라 그라디언트)만 기존 그대로 유지하고, 레이아웃·
/// 비주얼·카피·모션은 완전히 새로 만든다. 기능/라우팅(버튼 3개가
/// 이동하는 곳 — 회원가입/로그인/게스트 홈)은 바뀌지 않는다.
///
/// [신규 TO-BE 구조] "빛나는 달 + 마법진 2겹 + 한자 글리프" 중심
/// 그래픽(Orb) + 소개 3장 자동 캐러셀(命/願/福, 5.2초 간격) + CTA 3개
/// (시작하기/로그인/먼저 둘러보기) + 재미·참고용 안내 바텀시트. 일러스트
/// 이미지 에셋은 전혀 쓰지 않고 모두 CSS/SVG(Flutter에서는 CustomPainter/
/// 그라디언트)로 그린다.
///
/// [구 코드 보존 원칙] 이전 디자인이 쓰던 위젯들(`onboarding_hero_frame.
/// dart`, `onboarding_sigil.dart`, `onboarding_action_buttons.dart`,
/// `onboarding_star_petal_field.dart`, `onboarding_rise_in.dart`)은 더
/// 이상 이 화면에서 참조되지 않지만, 프로젝트 관례에 따라 삭제하지 않고
/// 그대로 둔다. 새 디자인 전용 위젯은 `onboarding_orb.dart`,
/// `onboarding_copy_carousel.dart`, `onboarding_entry_buttons.dart`,
/// `onboarding_star_dust_field.dart`에 신설했다.
///
/// [진입 시퀀스 1회 재생] 세션 단위가 아니라 "최초 1회"로 구현한 기존
/// 정책([_kIntroPlayedKey], 키 이름도 그대로 유지 — SharedPreferences에
/// 이미 쌓인 값과 호환)을 그대로 유지한다.
class IntroPagerScreen extends StatefulWidget {
  const IntroPagerScreen({super.key});

  @override
  State<IntroPagerScreen> createState() => _IntroPagerScreenState();
}

/// README §진입 시퀀스(1회) 타임라인 상수.
class _EntryTiming {
  _EntryTiming._();

  static const double topBarStart = 0.2;
  static const double topBarDuration = 1.2;

  static const double orbStart = 0.3;
  static const double orbDuration = 1.8;

  static const double copyStart = 1.0;
  static const double copyDuration = 1.2;

  static const double actionsStart = 1.4;
  static const double actionsDuration = 1.2;

  static const double total = actionsStart + actionsDuration; // 2.6s.
}

/// 캐러셀 자동 전환 주기(README "5.2초마다 다음 장으로").
const Duration _kCarouselDuration = Duration(milliseconds: 5200);

class _IntroPagerScreenState extends State<IntroPagerScreen>
    with TickerProviderStateMixin {
  static const String _kIntroPlayedKey = 'onboarding_redesign_intro_played_v1';

  late final AnimationController _entryController;
  late final AnimationController _carouselTimer;
  bool _reduceMotion = false;
  bool _skipEntryAnimation = false;
  bool _didCheckPlayed = false;
  int _slideIndex = 0;
  bool _isNoticeOpen = false;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (_EntryTiming.total * 1000).round()),
    );
    _carouselTimer = AnimationController(
      vsync: this,
      duration: _kCarouselDuration,
    )..addStatusListener(_onCarouselTick);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<IntroConfigProvider>().load();
      _resolveIntroPlayed();
    });
  }

  void _onCarouselTick(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _goToSlide(_slideIndex + 1, resetTimer: true);
    }
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
      // 조회 실패 시 안전하게 애니메이션을 1회 재생한다.
    }
    if (!mounted) return;
    setState(() {
      _skipEntryAnimation = alreadyPlayed;
      _didCheckPlayed = true;
    });
    if (alreadyPlayed || _reduceMotion) {
      _entryController.value = 1.0;
    } else {
      _entryController.forward();
    }
    // README "진입 후 1.0s에 1장부터 시작".
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      if (!_reduceMotion) {
        _carouselTimer.forward(from: 0);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.of(context).disableAnimations;
    if (reduce != _reduceMotion) {
      _reduceMotion = reduce;
      if (reduce && _didCheckPlayed) {
        _entryController.value = 1.0;
        _carouselTimer.stop();
      }
    }
  }

  @override
  void dispose() {
    _entryController.dispose();
    _carouselTimer.dispose();
    super.dispose();
  }

  void _goToSlide(int index, {required bool resetTimer}) {
    final next = index % kOnboardingSlides.length;
    setState(() => _slideIndex = next < 0 ? next + kOnboardingSlides.length : next);
    if (resetTimer && !_reduceMotion && !_isNoticeOpen) {
      _carouselTimer.forward(from: 0);
    }
  }

  void _onSkip() {
    _goToSlide(kOnboardingSlides.length - 1, resetTimer: true);
  }

  double _dragDx = 0;

  void _onDragStart(DragStartDetails details) {
    _dragDx = 0;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _dragDx += details.delta.dx;
  }

  void _onDragEnd(DragEndDetails details) {
    // README "Stage 좌우 스와이프(40px 이상) — 왼쪽 → 다음 장, 오른쪽 →
    // 이전 장".
    if (_dragDx.abs() < 40) return;
    if (_dragDx < 0) {
      _goToSlide(_slideIndex + 1, resetTimer: true);
    } else {
      _goToSlide(_slideIndex - 1, resetTimer: true);
    }
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
    setState(() => _isNoticeOpen = true);
    // README "바텀시트가 열린 동안에는 자동 전환을 멈추는 것을 권장".
    _carouselTimer.stop();
    showOnboardingNoticeSheet(context).whenComplete(() {
      if (!mounted) return;
      setState(() => _isNoticeOpen = false);
      if (!_reduceMotion) {
        _carouselTimer.forward(from: 0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<IntroConfigProvider>().config;
    final showReduced = _reduceMotion || _skipEntryAnimation;

    return Scaffold(
      body: DecoratedBox(
        // [배경 변경 금지] README "배경색은 지금과 똑같이 유지" — 기존
        // 3단 그라디언트를 그대로 재사용한다.
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
            const Positioned.fill(child: _AmbientRadials()),
            Positioned.fill(
              child: OnboardingStarDustField(reduceMotion: showReduced),
            ),
            SafeArea(
              child: AnimatedBuilder(
                animation: Listenable.merge([_entryController, _carouselTimer]),
                builder: (context, _) {
                  final elapsed = showReduced
                      ? _EntryTiming.total
                      : _entryController.value * _EntryTiming.total;
                  return _OnboardingContent(
                    elapsedSeconds: elapsed,
                    reduceMotion: showReduced,
                    slideIndex: _slideIndex,
                    carouselProgress: _carouselTimer.value,
                    showGuestOption: config.showGuestHint,
                    onSkip: _onSkip,
                    onDragStart: _onDragStart,
                    onDragUpdate: _onDragUpdate,
                    onDragEnd: _onDragEnd,
                    onDotTap: (i) => _goToSlide(i, resetTimer: true),
                    onSignup: _goSignup,
                    onLogin: _goLogin,
                    onStartAsGuest: _startAsGuest,
                    onDisclaimer: _openNoticeSheet,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 배경 라디얼 그라디언트 2겹(변경 금지 범위, 기존 그대로 유지).
class _AmbientRadials extends StatelessWidget {
  const _AmbientRadials();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.7, -1.0),
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
            center: const Alignment(0.8, 0.7),
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

/// TopBar + Stage(Orb+캐러셀) + Actions 전체 컬럼. README 레이아웃: "세로
/// flex: TopBar(28px) → Stage(flex:1, 가운데 정렬) → Actions(하단)".
class _OnboardingContent extends StatelessWidget {
  const _OnboardingContent({
    required this.elapsedSeconds,
    required this.reduceMotion,
    required this.slideIndex,
    required this.carouselProgress,
    required this.showGuestOption,
    required this.onSkip,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onDotTap,
    required this.onSignup,
    required this.onLogin,
    required this.onStartAsGuest,
    required this.onDisclaimer,
  });

  final double elapsedSeconds;
  final bool reduceMotion;
  final int slideIndex;
  final double carouselProgress;
  final bool showGuestOption;
  final VoidCallback onSkip;
  final GestureDragStartCallback onDragStart;
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;
  final ValueChanged<int> onDotTap;
  final VoidCallback onSignup;
  final VoidCallback onLogin;
  final VoidCallback onStartAsGuest;
  final VoidCallback onDisclaimer;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final isCompact = height <= 700; // README "@media (max-height:700px)".

    // README "width: min(72vw, 290px, 40dvh)"(700px 이하 56vw/210px/32dvh).
    final width = MediaQuery.of(context).size.width;
    final orbSizeCandidates = isCompact
        ? [width * 0.56, 210.0, height * 0.32]
        : [width * 0.72, 290.0, height * 0.40];
    final orbSize = orbSizeCandidates.reduce((a, b) => a < b ? a : b);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        children: [
          SizedBox(
            height: 28,
            child: _FadeIn(
              elapsedSeconds: elapsedSeconds,
              startSeconds: _EntryTiming.topBarStart,
              durationSeconds: _EntryTiming.topBarDuration,
              child: _TopBar(onSkip: onSkip),
            ),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragStart: onDragStart,
              onHorizontalDragUpdate: onDragUpdate,
              onHorizontalDragEnd: onDragEnd,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _FadeIn(
                    elapsedSeconds: elapsedSeconds,
                    startSeconds: _EntryTiming.orbStart,
                    durationSeconds: _EntryTiming.orbDuration,
                    useScaleBlur: true,
                    child: OnboardingOrb(
                      size: orbSize,
                      glyphIndex: slideIndex,
                      reduceMotion: reduceMotion,
                    ),
                  ),
                  SizedBox(height: isCompact ? 14 : 28),
                  _RiseFadeIn(
                    elapsedSeconds: elapsedSeconds,
                    startSeconds: _EntryTiming.copyStart,
                    durationSeconds: _EntryTiming.copyDuration,
                    child: OnboardingCopyCarousel(
                      index: slideIndex,
                      isCompact: isCompact,
                    ),
                  ),
                  SizedBox(height: isCompact ? 14 : 22),
                  OnboardingDots(
                    count: kOnboardingSlides.length,
                    activeIndex: slideIndex,
                    activeProgress: carouselProgress,
                    onTapDot: onDotTap,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: isCompact ? 12 : 18),
            child: _RiseFadeIn(
              elapsedSeconds: elapsedSeconds,
              startSeconds: _EntryTiming.actionsStart,
              durationSeconds: _EntryTiming.actionsDuration,
              child: _ActionsBlock(
                isCompact: isCompact,
                reduceMotion: reduceMotion,
                showGuestOption: showGuestOption,
                onSignup: onSignup,
                onLogin: onLogin,
                onStartAsGuest: onStartAsGuest,
                onDisclaimer: onDisclaimer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// `.fade` — 순수 opacity 전환(진입 시퀀스 1~2행: TopBar/Orb).
class _FadeIn extends StatelessWidget {
  const _FadeIn({
    required this.elapsedSeconds,
    required this.startSeconds,
    required this.durationSeconds,
    required this.child,
    this.useScaleBlur = false,
  });

  final double elapsedSeconds;
  final double startSeconds;
  final double durationSeconds;
  final Widget child;

  /// true면 Orb 등장처럼 scale .9→1 + blur 8→0도 함께 적용한다.
  final bool useScaleBlur;

  @override
  Widget build(BuildContext context) {
    final p = ((elapsedSeconds - startSeconds) / durationSeconds).clamp(
      0.0,
      1.0,
    );
    final eased = const Cubic(0.2, 0.7, 0.2, 1).transform(p);
    Widget result = Opacity(opacity: eased, child: child);
    if (useScaleBlur) {
      result = Transform.scale(scale: 0.9 + 0.1 * eased, child: result);
    }
    return result;
  }
}

/// `.copy-wrap`/`.slide` 등장 — opacity + translateY(README "카피 + 점 |
/// opacity 0→1, translateY 12→0").
class _RiseFadeIn extends StatelessWidget {
  const _RiseFadeIn({
    required this.elapsedSeconds,
    required this.startSeconds,
    required this.durationSeconds,
    required this.child,
  });

  final double elapsedSeconds;
  final double startSeconds;
  final double durationSeconds;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = ((elapsedSeconds - startSeconds) / durationSeconds).clamp(
      0.0,
      1.0,
    );
    final eased = const Cubic(0.2, 0.7, 0.2, 1).transform(p);
    return Opacity(
      opacity: eased,
      child: Transform.translate(
        offset: Offset(0, 12 * (1 - eased)),
        child: child,
      ),
    );
  }
}

/// TopBar — 좌: 브랜드 마크+「신통방통」+「SINTONG」, 우: 「건너뛰기」.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.onSkip});

  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                gradient: const LinearGradient(
                  begin: Alignment(-0.6, -1),
                  end: Alignment(0.6, 1),
                  colors: [Color(0xFFF3DCFB), IntroPalette.primary],
                ),
                boxShadow: [
                  BoxShadow(
                    color: IntroPalette.primary.withValues(alpha: 0.35),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Text(
                '神',
                style: GoogleFonts.notoSerifKr(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: IntroPalette.introInk,
                  height: 1.0,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '신통방통',
              style: GoogleFonts.notoSerifKr(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 13 * 0.02,
                color: IntroPalette.textPrimary,
                height: 1.0,
              ),
            ),
            const SizedBox(width: 2),
            Text(
              'SINTONG',
              style: GoogleFonts.ibmPlexMono(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                letterSpacing: 9 * 0.3,
                color: IntroPalette.introFaint,
                height: 1.0,
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: onSkip,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 0, 8),
            child: Text(
              '건너뛰기',
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: IntroPalette.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Actions — Primary + Ghost 2열 + 안내 링크.
class _ActionsBlock extends StatelessWidget {
  const _ActionsBlock({
    required this.isCompact,
    required this.reduceMotion,
    required this.showGuestOption,
    required this.onSignup,
    required this.onLogin,
    required this.onStartAsGuest,
    required this.onDisclaimer,
  });

  final bool isCompact;
  final bool reduceMotion;
  final bool showGuestOption;
  final VoidCallback onSignup;
  final VoidCallback onLogin;
  final VoidCallback onStartAsGuest;
  final VoidCallback onDisclaimer;

  @override
  Widget build(BuildContext context) {
    final primaryHeight = isCompact ? 50.0 : 56.0;
    final ghostHeight = isCompact ? 44.0 : 50.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        OnboardingMoonPrimaryButton(
          label: '내 이야기 시작하기',
          icon: '✧',
          height: primaryHeight,
          reduceMotion: reduceMotion,
          onTap: onSignup,
        ),
        const SizedBox(height: 10),
        if (showGuestOption)
          Row(
            children: [
              Expanded(
                child: OnboardingMoonGhostButton(
                  label: '로그인',
                  leadingIcon: '☾',
                  height: ghostHeight,
                  onTap: onLogin,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OnboardingMoonGhostButton(
                  label: '먼저 둘러보기',
                  trailingIcon: '→',
                  height: ghostHeight,
                  onTap: onStartAsGuest,
                ),
              ),
            ],
          )
        else
          OnboardingMoonGhostButton(
            label: '로그인',
            leadingIcon: '☾',
            height: ghostHeight,
            onTap: onLogin,
          ),
        const SizedBox(height: 4),
        OnboardingNoticeLink(onTap: onDisclaimer),
      ],
    );
  }
}
