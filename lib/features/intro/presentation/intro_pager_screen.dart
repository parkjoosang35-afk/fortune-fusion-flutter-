import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../application/intro_config_provider.dart';
import '../application/intro_state_provider.dart';
import 'intro_palette.dart';
import 'intro_text_styles.dart';
import 'widgets/onboarding_action_buttons.dart';
import 'widgets/onboarding_hero_frame.dart';
import 'widgets/onboarding_notice_sheet.dart';
import 'widgets/onboarding_star_petal_field.dart';

/// [온보딩 v2 리디자인 2026-10-18 — `design_handoff_onboarding_redesign
/// (2).zip` 전면 반영] 스플래시(1단계) 다음, 그리고 [OnboardingVideoScreen]
/// (5대 기능 소개 영상) 다음에 이어지는 비로그인 첫 진입 화면.
///
/// [v1→v2 교체 배경] 이 화면은 2026-10-11에 이전 핸드오프
/// (`design_handoff_onboarding_redesign.zip`, 버전 접미사 없음)를 전면
/// 반영해 한 차례 교체된 바 있다. 이번 작업은 그 디자인의 **개정판(v2)**을
/// 반영하는 것으로, README("기존 온보딩 화면... 리디자인한 버전")가 명시한
/// 대로 신규 화면이 아니라 **동일 화면의 레이아웃 재구성**이다. 교체 범위는
/// README "교체 범위: 온보딩 1화면(ENTRY·01). 다른 화면은 영향 없음"을
/// 그대로 따르며, 기능/라우팅(4개 콜백의 목적지)은 바꾸지 않는다.
///
/// [배경 변경 금지] README "배경 그라데이션은 기존 그대로 유지" 지시에 따라
/// [_AmbientRadials]를 포함한 배경 레이어는 전혀 건드리지 않는다.
///
/// [v1→v2 주요 레이아웃 차이]
/// - Hero: v1의 단일 아치 카드(halo+sigil 1겹) → **2겹 Sigil(A 200s
///   시계방향/B 140s 반시계방향) + 고정비율 Arch outer(문살눈금·keystone·
///   moonwash·緣 인장)**로 전면 교체([OnboardingHeroFrame] 재작성).
/// - 緣 인장: 글로우 그라디언트 배지 → 인주색(seal red) 세로형 "緣/INYEON" 배지.
/// - Actions: Primary(그라디언트+pulse 애니메이션) 1개 + Ghost 1개 + 텍스트
///   링크 2개 → Primary(단색+정적 shadow+trailing `→`) 1개 + **Ghost 2열
///   그리드**(로그인/둘러보기) + 안내 링크 1개로 축소.
/// - 별/꽃잎: 개수·분포·타이밍 전면 변경([OnboardingStarPetalField] 재작성).
/// - 등장 시퀀스 총 길이 3.1s → **3.0s**(README §등장 모션 표 기준).
///
/// [진입 시퀀스 1회 재생] 세션(=앱 프로세스) 단위가 아니라 "최초 1회"로
/// 구현한 기존 정책([_kIntroPlayedKey])을 그대로 유지한다.
class IntroPagerScreen extends StatefulWidget {
  const IntroPagerScreen({super.key});

  @override
  State<IntroPagerScreen> createState() => _IntroPagerScreenState();
}

/// README §등장 모션 타임라인 상수 — 값 자체를 바꾸지 않아야 "픽셀/타이밍
/// 단위까지 온보딩 v2.html과 동일하게" 재현할 수 있다.
class _OnboardingTiming {
  _OnboardingTiming._();

  /// "Meta, Sigil 2겹 | fade 0→1 | 2.4s ease-out, 0s".
  static const double metaFadeDuration = 2.4;

  static const double eyebrowStart = 0.9;
  static const double titleStart = 1.1;
  static const double subStart = 1.3;
  static const double riseDuration = 1.4;

  /// "緣 인장, Actions | 〃 | 1.4s, 1.6s" — Hero 내부의 緣 인장과 동일
  /// 시점(1.6s)에 Actions도 함께 떠오른다.
  static const double actionsStart = 1.6;

  /// 전체 등장 시퀀스 길이 — 마지막 rise(1.6s 지연 + 1.4s 길이) 완료 지점.
  static const double totalDuration = actionsStart + riseDuration;
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
      // README "접근성 — prefers-reduced-motion이면 회전/꽃잎/등장 모션을
      // 끄고 바로 최종 상태".
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
    final config = context.watch<IntroConfigProvider>().config;
    final showReduced = _reduceMotion || _skipEntryAnimation;

    return Scaffold(
      body: DecoratedBox(
        // [배경 변경 금지] README "배경 그라데이션은 기존 그대로 유지" —
        // v1부터 쓰던 3단 그라디언트를 그대로 재사용한다.
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
            // 라디얼 그라디언트 2겹(좌상단 크리스탈 / 우하단 glow) — 배경
            // 레이어의 일부이므로 v1 그대로 유지(변경 금지 범위).
            const Positioned.fill(child: _AmbientRadials()),
            Positioned.fill(
              child: OnboardingStarPetalField(reduceMotion: showReduced),
            ),
            SafeArea(
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
                    showGuestOption: config.showGuestHint,
                    onSignup: _goSignup,
                    onLogin: _goLogin,
                    onDisclaimer: _openNoticeSheet,
                    onStartAsGuest: _startAsGuest,
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

/// 배경 라디얼 그라디언트 2겹(`.screen` background 2~3번째 레이어, 변경 금지).
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

/// Meta row + Hero + Copy + Actions 전체 컬럼. README "상단 영역은 top
/// 기준, 하단 액션은 bottom 기준으로 고정하고, 히어로 높이는 남는 공간에
/// 맞춰 줄이는 방식을 권장"을 Column + Expanded 조합으로 구현한다(390×844
/// 레퍼런스의 절대좌표를 그대로 쓰는 대신, 실제 기기 높이에 맞춰 Hero
/// 영역만 유연하게 줄어드는 방식).
///
/// [실제 OS 크롬과의 분리] README 레이아웃 표의 "Status bar"(top 0 h54)와
/// "Home indicator"(bottom 9)는 HTML 프로토타입이 iPhone 디바이스 베젤을
/// 보여주기 위해 그린 가짜 UI이며, 실제 Flutter 앱은 진짜 OS 상태표시줄/
/// 홈 인디케이터를 이미 가지고 있어 중복 렌더링하지 않는다(v1부터 이어온
/// 동일 결정 — SafeArea로 실제 시스템 UI 영역만 피한다).
class _OnboardingContent extends StatelessWidget {
  const _OnboardingContent({
    required this.elapsedSeconds,
    required this.reduceMotion,
    required this.showGuestOption,
    required this.onSignup,
    required this.onLogin,
    required this.onDisclaimer,
    required this.onStartAsGuest,
  });

  final double elapsedSeconds;
  final bool reduceMotion;
  final bool showGuestOption;
  final VoidCallback onSignup;
  final VoidCallback onLogin;
  final VoidCallback onDisclaimer;
  final VoidCallback onStartAsGuest;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final isCompact = height <= 720; // v1과 동일한 반응형 기준 유지.
    final titleFontSize = isCompact ? 24.0 : 28.0;
    final heroMaxHeight = isCompact ? 360.0 : 430.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        children: [
          // Meta row — "神通萬通 · SINTONG" / "ENTRY · 01", fade 0→1 2.4s.
          _MetaFade(elapsedSeconds: elapsedSeconds, reduceMotion: reduceMotion),
          const SizedBox(height: 16),
          // Hero — 2겹 Sigil + Arch 프레임. 남는 공간에 맞춰 축소.
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: heroMaxHeight),
              child: OnboardingHeroFrame(
                heroAsset: 'assets/images/intro/hero-fullbody.png',
                elapsedSeconds: elapsedSeconds,
                reduceMotion: reduceMotion,
              ),
            ),
          ),
          SizedBox(height: isCompact ? 14 : 20),
          // Copy — Eyebrow / Title / Sub.
          _MetaRiseIn(
            elapsedSeconds: elapsedSeconds,
            startSeconds: _OnboardingTiming.eyebrowStart,
            child: const _EyebrowRow(),
          ),
          const SizedBox(height: 12),
          _MetaRiseIn(
            elapsedSeconds: elapsedSeconds,
            startSeconds: _OnboardingTiming.titleStart,
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                // 온보딩 v2.html h1: 900 28px/1.3, tracking -.025em,
                // text-shadow 0 2px 24px rgba(20,14,40,.8).
                style: IntroTextStyles.title(fontSize: titleFontSize).copyWith(
                  height: 1.3,
                  shadows: const [
                    Shadow(
                      color: Color(0xCC140E28),
                      offset: Offset(0, 2),
                      blurRadius: 24,
                    ),
                  ],
                ),
                children: [
                  const TextSpan(text: '이제, '),
                  const TextSpan(
                    text: '당신의 이야기',
                    style: TextStyle(
                      color: IntroPalette.primary,
                      shadows: [
                        Shadow(color: IntroPalette.glowShadow, blurRadius: 22),
                      ],
                    ),
                  ),
                  const TextSpan(text: '를\n펼쳐볼까요'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          _MetaRiseIn(
            elapsedSeconds: elapsedSeconds,
            startSeconds: _OnboardingTiming.subStart,
            child: Text(
              '달빛 아래 조용히 기다리고 있었어요',
              textAlign: TextAlign.center,
              // 온보딩 v2.html .sub: 400 14px/1.6, rgba(220,210,245,.62).
              style: IntroTextStyles.sub(
                color: const Color(0x9EDCD2F5),
              ).copyWith(height: 1.6),
            ),
          ),
          const Spacer(),
          // Actions — Primary + Ghost 2열(or 단독) + 안내 링크.
          _MetaRiseIn(
            elapsedSeconds: elapsedSeconds,
            startSeconds: _OnboardingTiming.actionsStart,
            child: _ActionsBlock(
              reduceMotion: reduceMotion,
              elapsedSeconds: elapsedSeconds,
              showGuestOption: showGuestOption,
              onSignup: onSignup,
              onLogin: onLogin,
              onDisclaimer: onDisclaimer,
              onStartAsGuest: onStartAsGuest,
            ),
          ),
        ],
      ),
    );
  }
}

/// `.fade` — 순수 opacity 0→1 애니메이션(translateY/blur 없음). Meta row와
/// Sigil 2겹이 공유하는 등장 효과(README 등장 모션 표 1행).
class _MetaFade extends StatelessWidget {
  const _MetaFade({required this.elapsedSeconds, required this.reduceMotion});

  final double elapsedSeconds;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final p = reduceMotion
        ? 1.0
        : (elapsedSeconds / _OnboardingTiming.metaFadeDuration).clamp(0.0, 1.0);
    final eased = Curves.easeOut.transform(p);
    return Opacity(opacity: eased, child: const _MetaRow());
  }
}

/// `.rise`(v2 버전) — `@keyframes rise{from{opacity:0;translateY(14px)}
/// to{opacity:1;transform:none}}`(v1과 달리 blur 단계가 없다).
class _MetaRiseIn extends StatelessWidget {
  const _MetaRiseIn({
    required this.elapsedSeconds,
    required this.startSeconds,
    required this.child,
  });

  final double elapsedSeconds;
  final double startSeconds;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = ((elapsedSeconds - startSeconds) / _OnboardingTiming.riseDuration)
        .clamp(0.0, 1.0);
    final eased = Curves.easeOutCubic.transform(p);
    return Opacity(
      opacity: eased,
      child: Transform.translate(
        offset: Offset(0, 14 * (1 - eased)),
        child: child,
      ),
    );
  }
}

/// Meta row — 좌: `神通萬通 · SINTONG`(가운데 점만 glow 색), 우: `ENTRY · 01`.
class _MetaRow extends StatelessWidget {
  const _MetaRow();

  static TextStyle get _style => const TextStyle(
    fontFamily: 'IBM Plex Mono',
    fontSize: 9.5,
    fontWeight: FontWeight.w500,
    letterSpacing: 9.5 * 0.26,
    color: Color(0x9EDCD2F5), // rgba(220,210,245,.62).
  );

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        RichText(
          text: TextSpan(
            style: _style,
            children: const [
              TextSpan(text: '神通萬通 '),
              TextSpan(
                text: '·',
                style: TextStyle(color: IntroPalette.primary),
              ),
              TextSpan(text: ' SINTONG'),
            ],
          ),
        ),
        Text('ENTRY · 01', style: _style),
      ],
    );
  }
}

/// Eyebrow — 양옆 22×1px 실선 + "READY · TO · BEGIN"(v2: 그라디언트
/// 대신 단색 `var(--line)` 라인으로 단순화).
class _EyebrowRow extends StatelessWidget {
  const _EyebrowRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _eyebrowLine(),
        const SizedBox(width: 10),
        Text(
          'READY · TO · BEGIN',
          style: IntroTextStyles.eyebrow().copyWith(
            fontSize: 9.5,
            letterSpacing: 9.5 * 0.4,
          ),
        ),
        const SizedBox(width: 10),
        _eyebrowLine(),
      ],
    );
  }

  Widget _eyebrowLine() {
    return Container(width: 22, height: 1, color: IntroPalette.cardBorder);
  }
}

/// Actions 블록 — Primary + (Ghost 2열 또는 단독) + 안내 링크.
class _ActionsBlock extends StatelessWidget {
  const _ActionsBlock({
    required this.reduceMotion,
    required this.elapsedSeconds,
    required this.showGuestOption,
    required this.onSignup,
    required this.onLogin,
    required this.onDisclaimer,
    required this.onStartAsGuest,
  });

  final bool reduceMotion;
  final double elapsedSeconds;
  final bool showGuestOption;
  final VoidCallback onSignup;
  final VoidCallback onLogin;
  final VoidCallback onDisclaimer;
  final VoidCallback onStartAsGuest;

  @override
  Widget build(BuildContext context) {
    // README "버튼은 1.6s부터 탭할 수 있어야 해요" — rise가 시작되는
    // 시점부터 탭 가능하게 묶는다(그 이전엔 opacity 0이라 사실상 탭 불가).
    final enabled = elapsedSeconds >= _OnboardingTiming.actionsStart;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        OnboardingPrimaryButton(
          label: '시작하기',
          icon: '✧',
          trailingIcon: '→',
          reduceMotion: reduceMotion,
          enabled: enabled,
          onTap: onSignup,
        ),
        const SizedBox(height: 10),
        if (showGuestOption)
          Row(
            children: [
              Expanded(
                child: OnboardingGhostButton(
                  label: '이미 계정이 있어요',
                  onTap: onLogin,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OnboardingGhostButton(
                  label: '둘러보기',
                  icon: '☾',
                  onTap: onStartAsGuest,
                ),
              ),
            ],
          )
        else
          OnboardingGhostButton(
            label: '이미 계정이 있어요',
            icon: '☾',
            height: 46,
            onTap: onLogin,
          ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: onDisclaimer,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: Color(0x73DCD2F5), // rgba(220,210,245,.45).
              ),
              children: [
                const TextSpan(text: 'ⓘ 이 앱은 '),
                TextSpan(
                  text: '재미·참고용 콘텐츠',
                  style: TextStyle(
                    decoration: TextDecoration.underline,
                    decorationStyle: TextDecorationStyle.dashed,
                    decorationColor: const Color(0x59DCD2F5),
                  ),
                ),
                const TextSpan(text: '예요'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
