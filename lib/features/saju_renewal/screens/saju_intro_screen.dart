import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/saju_dark_tokens.dart';
import '../widgets/saju_base_widgets.dart';
import '../widgets/saju_visual_widgets.dart';
import 'saju_renewal_home_screen.dart';

/// [신통방통 정통사주 리뉴얼 — 다크 핸드오프 v4 신규] 화면 00-I ·
/// 정통사주 인트로(섹션 진입 의식).
///
/// `docs/03_화면명세.md` §"00-I · 정통사주 인트로" · `docs/04_모션.md`의
/// 타임라인(총 4.3s) · `docs/06_카피덱.md` C-00I-1~5를 그대로 재현한다.
/// 문구는 한 글자도 바꾸지 않는다(지시서 원칙).
///
/// 노출 조건: "정통사주 섹션 최초 진입 1회"(영구 플래그 `saju_intro_seen`).
/// 이 화면 자체는 플래그를 읽지 않는다 — 호출부(app_router.dart의
/// `_SajuEntryGate`)가 이미 "아직 안 봤다"고 판단한 뒤에만 이 위젯을
/// 빌드한다. 이 화면은 자신의 재생이 끝나는 시점(건너뛰기 포함)에
/// [markIntroSeen]을 호출해 플래그를 영구 기록하기만 한다.
class SajuIntroScreen extends StatefulWidget {
  const SajuIntroScreen({super.key});

  static const String _kSeenKey = 'saju_intro_seen';

  /// 이미 00-I를 본 적이 있는지(영구 플래그).
  static Future<bool> hasSeenIntro() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kSeenKey) ?? false;
  }

  /// 재생 완료(또는 건너뛰기) 시점에 영구 기록한다.
  static Future<void> markIntroSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSeenKey, true);
  }

  @override
  State<SajuIntroScreen> createState() => _SajuIntroScreenState();
}

class _SajuIntroScreenState extends State<SajuIntroScreen> {
  // 0=점 맥동 · 1=팔괘 열림(scale .75) · 2=팔괘 완성(scale 1, 8괘 점등) ·
  // 3=타이틀 블록 노출 · 4=페이드아웃(→01 전환 대기).
  int _phase = 0;
  int _lit = 0; // 8괘 순차 점등(0~8).
  bool _finished = false; // 건너뛰기/재생완료 — 중복 네비게이션 방지.
  bool _reduceMotion = false;
  bool _reduceMotionChecked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_reduceMotionChecked) {
      _reduceMotionChecked = true;
      // docs/04_모션.md §Reduce Motion: "점·확대·점등 없이 타이틀 화면
      // 1.2s 크로스페이드 후 01." — MediaQuery의 접근성 플래그를 그대로
      // 신뢰한다(OS 설정 "동작 줄이기"/"애니메이션 줄이기").
      _reduceMotion = MediaQuery.of(context).disableAnimations;
      if (_reduceMotion) {
        _runReducedMotionSequence();
      } else {
        _runFullSequence();
      }
    }
  }

  /// 일반(모션 허용) 타임라인 — docs/04_모션.md §00-I 표 그대로.
  Future<void> _runFullSequence() async {
    // 0.0s: 점 표시(이미 _phase=0 — initState 시점부터 맥동 시작).
    await Future.delayed(const Duration(milliseconds: 500));
    if (_finished || !mounted) return;
    // 0.5s: 점 사라짐 → 팔괘 열림(scale .75) · 자수정 배경 fade-in ·
    // 건너뛰기 표시.
    setState(() => _phase = 1);

    await Future.delayed(const Duration(milliseconds: 800));
    if (_finished || !mounted) return;
    // 1.3s: 팔괘 scale 1 · 별 필드 44개 fade-in · 8괘 순차 점등 시작.
    setState(() => _phase = 2);
    _runBaguaLit();

    await Future.delayed(const Duration(milliseconds: 1200));
    if (_finished || !mounted) return;
    // 2.5s: 타이틀 블록 rise 900ms + 금가루 Dust.
    setState(() => _phase = 3);

    await Future.delayed(const Duration(milliseconds: 1400));
    if (_finished || !mounted) return;
    // 3.9s: 팔괘·타이틀 fade-out(scale .82).
    setState(() => _phase = 4);

    await Future.delayed(const Duration(milliseconds: 400));
    if (_finished || !mounted) return;
    // 4.3s: 01로 300ms 전환.
    await _finishAndGoMain();
  }

  /// 8괘 순차 점등 — 110ms 간격(03 진행 인디케이터와 동일한 lit 동작,
  /// docs/04_모션.md "8괘 순차 점등 110ms 간격"을 그대로 재사용).
  Future<void> _runBaguaLit() async {
    for (var i = 1; i <= 8; i++) {
      if (_finished || !mounted) return;
      await Future.delayed(const Duration(milliseconds: 110));
      if (_finished || !mounted) return;
      setState(() => _lit = i);
    }
  }

  /// Reduce Motion — "점·확대·점등 없이 타이틀 화면 1.2s 크로스페이드
  /// 후 01."
  Future<void> _runReducedMotionSequence() async {
    // 팔괘·타이틀을 동시에 최종 상태로 보여주고(점등 완료 상태),
    // 전체를 크로스페이드로만 노출한다.
    setState(() {
      _phase = 3;
      _lit = 8;
    });
    await Future.delayed(const Duration(milliseconds: 1200));
    if (_finished || !mounted) return;
    await _finishAndGoMain();
  }

  /// 건너뛰기(화면 아무 곳 탭 또는 "건너뛰기" 버튼) — 즉시 01.
  Future<void> _skip() async {
    if (_finished) return;
    await _finishAndGoMain();
  }

  Future<void> _finishAndGoMain() async {
    if (_finished) return;
    _finished = true;
    await SajuIntroScreen.markIntroSeen();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: SajuMotion.screen,
        reverseTransitionDuration: SajuMotion.screen,
        pageBuilder: (_, __, ___) => const SajuRenewalHomeScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showSkip = _phase >= 1 && _phase < 4;
    final baguaVisible = _phase >= 1;
    final titleVisible = _phase >= 3;
    final fadingOut = _phase >= 4;

    // 팔괘 scale 타겟·전환시간: 0.5s→.05~.75(800ms) · 1.3s→1(1400ms,ease.sj).
    final double baguaScaleTarget = _phase <= 0
        ? 0.05
        : (_phase == 1 ? 0.75 : 1.0);
    final Duration baguaScaleDuration = _phase <= 1
        ? const Duration(milliseconds: 800)
        : const Duration(milliseconds: 1400);
    // blur 3px(열림 직후) → 0(1.3s~2.7s, 1.4s ease.sj).
    final double baguaBlurTarget = _phase == 1 ? 3.0 : 0.0;
    final Duration baguaBlurDuration = _phase == 1
        ? const Duration(milliseconds: 1)
        : const Duration(milliseconds: 1400);

    return PopScope(
      // 00-I 재생 중 시스템 백 = 건너뛰기와 동일하게 처리(먹통 상태 방지).
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _skip();
      },
      child: Scaffold(
        backgroundColor: SajuInk.i900,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _skip,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 먹 배경(항상).
              const ColoredBox(color: SajuInk.i900),

              // 자수정 래디얼 배경 — 0.5s부터 1.6s에 걸쳐 fade-in.
              ExcludeSemantics(
                child: AnimatedOpacity(
                  opacity: baguaVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 1600),
                  curve: Curves.easeOut,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(0, -0.3),
                        radius: 0.9,
                        colors: [Color(0xBF2A2640), Colors.transparent],
                        stops: [0.0, 0.7],
                      ),
                    ),
                  ),
                ),
              ),

              // 별 필드 44개 — 1.3s부터 2s에 걸쳐 fade-in.
              ExcludeSemantics(
                child: AnimatedOpacity(
                  opacity: _phase >= 2 ? 1 : 0,
                  duration: const Duration(milliseconds: 2000),
                  curve: Curves.easeOut,
                  child: const SajuStarField(count: 44, seed: 11, opacity: 0.8),
                ),
              ),

              // 중앙 콘텐츠(점 / 팔괘+타이틀).
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final centerY = constraints.maxHeight * 0.46;
                    return Stack(
                      children: [
                        // 0.0s~0.5s: 금빛 점 6pt 맥동.
                        if (_phase == 0)
                          Positioned(
                            left: 0,
                            right: 0,
                            top: centerY - 3,
                            child: const ExcludeSemantics(
                              child: Center(child: _PulsingGoldDot()),
                            ),
                          ),

                        // 팔괘 + 타이틀 블록(함께 fade-out, scale .82).
                        Positioned.fill(
                          child: AnimatedOpacity(
                            opacity: fadingOut ? 0 : (baguaVisible ? 1 : 0),
                            duration: const Duration(milliseconds: 400),
                            curve: SajuMotion.easeSj,
                            child: AnimatedScale(
                              scale: fadingOut ? 0.82 : 1.0,
                              duration: const Duration(milliseconds: 400),
                              curve: SajuMotion.easeSj,
                              child: Column(
                                children: [
                                  SizedBox(height: centerY - 150),
                                  // 팔괘 오브제(300 — scale .05→.75→1).
                                  ExcludeSemantics(
                                    child: TweenAnimationBuilder<double>(
                                      tween: Tween<double>(
                                        begin: baguaScaleTarget,
                                        end: baguaScaleTarget,
                                      ),
                                      duration: baguaScaleDuration,
                                      curve: SajuMotion.easeSj,
                                      builder: (context, scale, child) {
                                        return Transform.scale(
                                          scale: scale,
                                          child: child,
                                        );
                                      },
                                      child: TweenAnimationBuilder<double>(
                                        tween: Tween<double>(
                                          begin: baguaBlurTarget,
                                          end: baguaBlurTarget,
                                        ),
                                        duration: baguaBlurDuration,
                                        builder: (context, blur, child) {
                                          return _BlurWrap(
                                            sigma: blur,
                                            child: child!,
                                          );
                                        },
                                        child: SajuBagua(
                                          size: 300,
                                          speedSeconds: 140,
                                          lit: _reduceMotion
                                              ? -1
                                              : (_phase >= 2 ? _lit : 0),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 36),
                                  // 타이틀 블록 — 2.5s rise 900ms.
                                  AnimatedSlide(
                                    offset: titleVisible
                                        ? Offset.zero
                                        : const Offset(0, 0.08),
                                    duration: const Duration(milliseconds: 900),
                                    curve: SajuMotion.easeSj,
                                    child: AnimatedOpacity(
                                      opacity: titleVisible ? 1 : 0,
                                      duration: const Duration(
                                        milliseconds: 900,
                                      ),
                                      curve: SajuMotion.easeSj,
                                      child: const _IntroTitleBlock(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // 금가루 Dust 12개 — 타이틀 노출 구간에만.
                        if (titleVisible && !fadingOut)
                          const Positioned.fill(
                            child: ExcludeSemantics(child: _GoldDust()),
                          ),
                      ],
                    );
                  },
                ),
              ),

              // 우상단 "건너뛰기"(C-00I-5).
              Positioned(
                top: 18,
                right: 18,
                child: AnimatedOpacity(
                  opacity: showSkip ? 1 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: SafeArea(
                    child: Semantics(
                      button: true,
                      label: '건너뛰기, 바로 정통사주 메인으로 이동합니다',
                      child: GestureDetector(
                        onTap: _skip,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          // 터치영역 44pt 보장(QA E 섹션 "터치영역 44pt").
                          constraints: const BoxConstraints(
                            minWidth: 44,
                            minHeight: 44,
                          ),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          child: const Text(
                            '건너뛰기',
                            style: TextStyle(
                              fontFamily: SajuType.ui,
                              fontSize: 13,
                              color: SajuText.muted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 0.0s 금빛 점 6pt + 글로우, 1.2s 맥동.
class _PulsingGoldDot extends StatefulWidget {
  const _PulsingGoldDot();

  @override
  State<_PulsingGoldDot> createState() => _PulsingGoldDotState();
}

class _PulsingGoldDotState extends State<_PulsingGoldDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value; // 0..1..0 (reverse).
        final scale = 1.0 + t * 0.35;
        final alpha = 0.7 + t * 0.3;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: SajuGold.g300,
              boxShadow: [
                BoxShadow(
                  color: SajuGold.g300.withValues(alpha: alpha.clamp(0.0, 1.0)),
                  blurRadius: 18,
                  spreadRadius: 6,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// `dart:ui`의 ImageFilter.blur를 간단히 감싸는 헬퍼(sigma=0이면 필터
/// 자체를 생성하지 않아 불필요한 레이어 비용을 피한다).
class _BlurWrap extends StatelessWidget {
  const _BlurWrap({required this.sigma, required this.child});
  final double sigma;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (sigma <= 0.01) return child;
    return ImageFiltered(
      imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      child: child,
    );
  }
}

/// [app_router.dart `/saju-renewal` 전용 게이트]
/// docs/03 §00-I "노출: 정통사주 섹션 최초 진입 1회(영구 플래그
/// `saju_intro_seen`). 이후 셸 카드 → 01 직행." — 00 셸의 M-01 원형
/// 확산 전환은 매번 동일하게 재생되고(기존 [sajuDimensionEnterRoute]가
/// 이미 처리), 그 전환이 드러내는 "내용"만 최초 1회에는 00-I, 이후에는
/// 01로 갈린다. 이 위젯이 바로 그 "내용" 역할을 한다.
///
/// [깜빡임 방지] SharedPreferences 조회는 비동기이지만 로컬 I/O라
/// 수 ms 내에 끝난다. 판단 전에는 먹 배경만 보여줘 원형 확산 전환과
/// 자연스럽게 이어지도록 한다(흰 화면/로딩 스피너 노출 금지).
class SajuEntryGate extends StatelessWidget {
  const SajuEntryGate({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: SajuIntroScreen.hasSeenIntro(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          // 판단 전 — 먹 배경만(SajuRenewalHomeScreen/SajuIntroScreen
          // 모두 SajuInk.i900 배경으로 시작하므로 전환 중 깜빡임 없음).
          return const ColoredBox(color: SajuInk.i900);
        }
        final alreadySeen = snapshot.data!;
        return alreadySeen
            ? const SajuRenewalHomeScreen()
            : const SajuIntroScreen();
      },
    );
  }
}

/// C-00I-1~4 — 문구를 한 글자도 바꾸지 않고 그대로 사용.
class _IntroTitleBlock extends StatelessWidget {
  const _IntroTitleBlock();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      // 장식적 팔괘/별은 숨기되, 타이틀 텍스트는 VoiceOver/TalkBack에
      // 하나의 의미 단위로 전달한다(QA E "장식은 접근성 트리에서 숨김").
      label: '정통사주. 태어난 순간에 새겨진 여덟 글자를 펼칩니다.',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // C-00I-1.
          const Text(
            '正 統 四 柱',
            style: TextStyle(
              fontFamily: SajuType.mono,
              fontFamilyFallback: [SajuType.serif],
              fontWeight: FontWeight.w500,
              fontSize: 14,
              letterSpacing: 0.3 * 14,
              color: SajuGold.g500,
            ),
          ),
          const SizedBox(height: 14),
          // C-00I-2.
          const Text(
            '정통사주',
            style: SajuType.hero,
          ),
          const SizedBox(height: 14),
          // C-00I-3.
          const Text(
            '태어난 순간에 새겨진\n여덟 글자를 펼칩니다',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: SajuType.body,
              fontSize: 15.5,
              height: 1.7,
              color: SajuText.fg2,
            ),
          ),
          const SizedBox(height: 52),
          // C-00I-4.
          const Text(
            '만세력 · 진태양시 기준 정통 계산',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: SajuType.ui,
              fontSize: 11,
              color: SajuText.faint,
            ),
          ),
        ],
      ),
    );
  }
}

/// 2.5s 타이틀 노출과 함께 상승하는 금가루 12개(장식 — 접근성 트리에서
/// 제외는 호출부(ExcludeSemantics)가 담당).
class _GoldDust extends StatefulWidget {
  const _GoldDust();

  @override
  State<_GoldDust> createState() => _GoldDustState();
}

class _GoldDustState extends State<_GoldDust>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_DustSpec> _dust;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
    _dust = List.generate(12, (i) {
      double r(int n) {
        final v = math.sin((i + 1) * 12.9898 * (n + 5)) * 43758.5453;
        return (v - v.floorToDouble());
      }

      return _DustSpec(x: r(1), delay: r(2), size: 1.2 + r(3) * 1.6);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            size: Size.infinite,
            painter: _GoldDustPainter(_dust, _controller.value),
          );
        },
      ),
    );
  }
}

class _DustSpec {
  _DustSpec({required this.x, required this.delay, required this.size});
  final double x;
  final double delay;
  final double size;
}

class _GoldDustPainter extends CustomPainter {
  _GoldDustPainter(this.dust, this.t);
  final List<_DustSpec> dust;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = SajuGold.g100;
    final baseY = size.height * 0.82;
    for (final d in dust) {
      final progress = ((t + d.delay) % 1.0);
      final y = baseY - progress * (size.height * 0.5);
      final alpha = (1 - progress) * 0.8;
      if (alpha <= 0) continue;
      paint.color = SajuGold.g100.withValues(alpha: alpha.clamp(0.0, 1.0));
      canvas.drawCircle(Offset(d.x * size.width, y), d.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GoldDustPainter oldDelegate) => true;
}
