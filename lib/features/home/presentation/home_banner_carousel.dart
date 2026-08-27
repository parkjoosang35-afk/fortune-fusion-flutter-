import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/widgets/app_toast.dart';

/// [메인 UI 리디자인 - 귀인지도 배너 3장 롤링 캐러셀]
///
/// `design_handoff_home_redesign.zip`의 `BANNER_CAROUSEL.md` 스펙을 그대로
/// Flutter로 재구현한다(참고용 HTML/CSS는 `Sintong Home.html`).
///
/// - Slide1 귀인지도(라벤더·골드) / Slide2 오늘의 운세(아쿠아·미드나이트블루) /
///   Slide3 인연·궁합(플럼·핑크)
/// - 자동슬라이드 4.2초, 스와이프 시 정지 후 재개, 도트 인디케이터,
///   reduced-motion 대응(자동재생 스킵)
/// - 각 슬라이드: 별 반짝임 22개, 회전 마법진(sigil), 후광 pulse, 신통도령
///   캐릭터(float+tilt), 스파클 4개(pop), NEW/TODAY/HOT 배지(pulse), CTA(breath)
///
/// 백엔드 라우팅(`/guinji`, `/fortune/today`, `/fortune/compatibility`)은 아직
/// 앱에 구현되어 있지 않아, 기존 앱의 관례(§`_FortuneCategoryChips`)를 따라
/// 준비 중 안내 토스트로 대체한다.
class HomeBannerCarousel extends StatefulWidget {
  const HomeBannerCarousel({super.key});

  @override
  State<HomeBannerCarousel> createState() => _HomeBannerCarouselState();
}

class _HomeBannerCarouselState extends State<HomeBannerCarousel> {
  static const Duration _interval = Duration(milliseconds: 4200);

  late final PageController _controller;
  int _index = 0;
  Timer? _timer;
  bool _paused = false;

  final List<_BannerSlideData> _slides = const [
    _BannerSlideData(
      key: 'guinji',
      route: '/guinji',
      eyebrow: 'SINTONG · N°01',
      titleLines: ['내 주변에', '{accent}귀인{/}은 몇 명일까'],
      sub: '생일만 있으면 돼요.\n지도를 채워보세요.',
      ctaLabel: '지도 만들기',
      ctaIcon: '✧',
      badgeLabel: 'NEW',
      imageAsset: 'assets/images/home/doryeong/scroll.png',
      accentGradient: [Color(0xFFF5D97A), Color(0xFFE8C8F5)],
      eyebrowColor: Color(0xFFE8C8F5),
      badgeBg: Color(0xFFE8C8F5),
      badgeFg: Color(0xFF1A0D2E),
      ctaBg: Color(0xFFE8C8F5),
      ctaFg: Color(0xFF1A0D2E),
      sigilColor: Color(0xFFE8C8F5),
      haloColor: Color(0xFFE8C8F5),
      gradientTop: Color(0xFF454575),
      gradientMid: Color(0xFF1E1A3A),
      gradientBottom: Color(0xFF14102A),
      radial1: Color(0xFFE8C8F5),
      radial2: Color(0xFF7FB8D4),
      sigilShape: _SigilShape.hexagon,
      sigilDurationSeconds: 60,
      sparkleShape: _SparkleShape.star,
      sparkleColors: [Color(0xFFF5D97A), Color(0xFFE8C8F5)],
      doryeongOffsetBottom: -10,
      doryeongOffsetRight: 0,
    ),
    _BannerSlideData(
      key: 'fortune',
      route: '/fortune/today',
      eyebrow: 'SINTONG · N°02',
      titleLines: ['오늘의 내', '{accent}별자리{/}는 무슨 색'],
      sub: '신통도령이 봐드릴게요.\n3분이면 충분해요.',
      ctaLabel: '운세 보기',
      ctaIcon: '☾',
      badgeLabel: 'TODAY',
      imageAsset: 'assets/images/home/doryeong/crystal.png',
      accentGradient: [Color(0xFFA8E3D5), Color(0xFFA8D5E3)],
      eyebrowColor: Color(0xFFA8D5E3),
      badgeBg: Color(0xFFA8D5E3),
      badgeFg: Color(0xFF0A1A30),
      ctaBg: Color(0xFFA8D5E3),
      ctaFg: Color(0xFF0A1A30),
      sigilColor: Color(0xFFA8D5E3),
      haloColor: Color(0xFFA8D5E3),
      gradientTop: Color(0xFF234A6B),
      gradientMid: Color(0xFF142A4A),
      gradientBottom: Color(0xFF0A1A30),
      radial1: Color(0xFFA8D5E3),
      radial2: Color(0xFF7FB8D4),
      sigilShape: _SigilShape.diamond,
      sigilDurationSeconds: 100,
      sparkleShape: _SparkleShape.star,
      sparkleColors: [Color(0xFFA8D5E3), Color(0xFFE8F2F8)],
      doryeongOffsetBottom: -6,
      doryeongOffsetRight: 4,
    ),
    _BannerSlideData(
      key: 'fate',
      route: '/fortune/compatibility',
      eyebrow: 'SINTONG · N°03',
      titleLines: ['그 사람과 나', '{accent}붉은 실{/}이 있을까'],
      sub: '두 사람의 생일만 있으면\n궁합이 풀려요.',
      ctaLabel: '궁합 보기',
      ctaIcon: '❤',
      badgeLabel: 'HOT',
      imageAsset: 'assets/images/home/doryeong/thread.png',
      accentGradient: [Color(0xFFF5D97A), Color(0xFFF5A8BD)],
      eyebrowColor: Color(0xFFF5C8D5),
      badgeBg: Color(0xFFF5C8D5),
      badgeFg: Color(0xFF1A0D1E),
      ctaBg: Color(0xFFF5C8D5),
      ctaFg: Color(0xFF1A0D1E),
      sigilColor: Color(0xFFF5C8D5),
      haloColor: Color(0xFFF5A8BD),
      gradientTop: Color(0xFF5C2A4A),
      gradientMid: Color(0xFF331A30),
      gradientBottom: Color(0xFF1A0D1E),
      radial1: Color(0xFFF5C8D5),
      radial2: Color(0xFFF5A8BD),
      sigilShape: _SigilShape.heart,
      sigilDurationSeconds: 60,
      sparkleShape: _SparkleShape.heart,
      sparkleColors: [Color(0xFFF5A8BD), Color(0xFFF5D97A)],
      doryeongOffsetBottom: -10,
      doryeongOffsetRight: 0,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStart());
  }

  void _maybeStart() {
    if (!mounted) return;
    // [접근성] prefers-reduced-motion 대응 - 시스템에서 애니메이션 감소를
    // 요청한 경우 자동 슬라이드를 시작하지 않는다.
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (!reduceMotion) _start();
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) {
      if (_paused || !mounted) return;
      _goTo(_index + 1);
    });
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _goTo(int i) {
    final n = _slides.length;
    final target = ((i % n) + n) % n;
    if (!_controller.hasClients) return;
    _controller.animateToPage(
      target,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
    );
  }

  void _onPointerDown() {
    _paused = true;
  }

  void _onPointerUp() {
    _paused = false;
    _start();
  }

  @override
  void dispose() {
    _stop();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width - 4 * 2;
    final height = width * 10 / 16;

    return Container(
      margin: const EdgeInsets.fromLTRB(4, 0, 4, 14),
      child: Column(
        children: [
          Listener(
            onPointerDown: (_) => _onPointerDown(),
            onPointerUp: (_) => _onPointerUp(),
            onPointerCancel: (_) => _onPointerUp(),
            child: SizedBox(
              height: height,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _slides.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) {
                    final data = _slides[i];
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _handleTap(context, data),
                      child: _BannerSlide(data: data),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_slides.length, (i) {
              final active = i == _index;
              return GestureDetector(
                onTap: () {
                  _goTo(i);
                  _start();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFF1F1F24)
                        : const Color(0xFFD4D4DC),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  void _handleTap(BuildContext context, _BannerSlideData data) {
    // [귀인지도 Phase G-1] Slide 1(guinji)만 `/guinji` 온보딩 화면으로 연결한다
    // (AppRouter에 신규 등록). 오늘의 운세(별자리)/인연·궁합 상세 화면과
    // 백엔드 라우팅(`/fortune/today`, `/fortune/compatibility`)은 아직 앱에
    // 구현되어 있지 않으므로 기존 관례대로 안내 토스트를 유지한다.
    if (data.route == '/guinji') {
      Navigator.of(context).pushNamed('/guinji');
      return;
    }
    AppToast.show(context, '곧 만나볼 수 있어요! 준비 중이에요 🙏');
  }
}

enum _SigilShape { hexagon, diamond, heart }

enum _SparkleShape { star, heart }

class _BannerSlideData {
  const _BannerSlideData({
    required this.key,
    required this.route,
    required this.eyebrow,
    required this.titleLines,
    required this.sub,
    required this.ctaLabel,
    required this.ctaIcon,
    required this.badgeLabel,
    required this.imageAsset,
    required this.accentGradient,
    required this.eyebrowColor,
    required this.badgeBg,
    required this.badgeFg,
    required this.ctaBg,
    required this.ctaFg,
    required this.sigilColor,
    required this.haloColor,
    required this.gradientTop,
    required this.gradientMid,
    required this.gradientBottom,
    required this.radial1,
    required this.radial2,
    required this.sigilShape,
    required this.sigilDurationSeconds,
    required this.sparkleShape,
    required this.sparkleColors,
    required this.doryeongOffsetBottom,
    required this.doryeongOffsetRight,
  });

  final String key;
  final String route;
  final String eyebrow;
  final List<String> titleLines; // 두 번째 줄에 {accent}...{/} 토큰 포함 가능
  final String sub;
  final String ctaLabel;
  final String ctaIcon;
  final String badgeLabel;
  final String imageAsset;
  final List<Color> accentGradient;
  final Color eyebrowColor;
  final Color badgeBg;
  final Color badgeFg;
  final Color ctaBg;
  final Color ctaFg;
  final Color sigilColor;
  final Color haloColor;
  final Color gradientTop;
  final Color gradientMid;
  final Color gradientBottom;
  final Color radial1;
  final Color radial2;
  final _SigilShape sigilShape;
  final int sigilDurationSeconds;
  final _SparkleShape sparkleShape;
  final List<Color> sparkleColors;
  final double doryeongOffsetBottom;
  final double doryeongOffsetRight;
}

class _BannerSlide extends StatefulWidget {
  const _BannerSlide({required this.data});

  final _BannerSlideData data;

  @override
  State<_BannerSlide> createState() => _BannerSlideState();
}

class _BannerSlideState extends State<_BannerSlide>
    with TickerProviderStateMixin {
  late final AnimationController _clock; // 별 반짝임용 대형 주기 클럭
  late final AnimationController _sigilCtrl;
  late final AnimationController _haloCtrl;
  late final AnimationController _badgeCtrl;
  late final AnimationController _floatCtrl;
  late final AnimationController _tiltCtrl;
  late final AnimationController _ctaCtrl;
  late final List<_StarSpec> _stars;
  late final List<_SparkleSpec> _sparkles;

  @override
  void initState() {
    super.initState();
    final rnd = math.Random(widget.data.key.hashCode);
    _stars = List.generate(22, (i) {
      return _StarSpec(
        left: rnd.nextDouble(),
        top: rnd.nextDouble(),
        size: 1 + rnd.nextDouble() * 1.5,
        durationMs: 2000 + rnd.nextInt(3000),
        delayMs: rnd.nextInt(3000),
        baseOpacity: 0.4 + rnd.nextDouble() * 0.5,
      );
    });

    _sparkles = const [
      _SparkleSpec(
        right: 30,
        top: 22,
        bottom: null,
        size: 14,
        durationMs: 2200,
        delayMs: 0,
      ),
      _SparkleSpec(
        right: 140,
        top: 44,
        bottom: null,
        size: 10,
        durationMs: 3000,
        delayMs: 700,
      ),
      _SparkleSpec(
        right: 6,
        top: null,
        bottom: 30,
        size: 12,
        durationMs: 2600,
        delayMs: 1300,
      ),
      _SparkleSpec(
        right: 100,
        top: null,
        bottom: 22,
        size: 9,
        durationMs: 3000,
        delayMs: 300,
      ),
    ];

    _clock = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3600),
    )..repeat();
    _sigilCtrl = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.data.sigilDurationSeconds),
    )..repeat();
    _haloCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _badgeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _tiltCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat(reverse: true);
    _ctaCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _ctaCtrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _clock.dispose();
    _sigilCtrl.dispose();
    _haloCtrl.dispose();
    _badgeCtrl.dispose();
    _floatCtrl.dispose();
    _tiltCtrl.dispose();
    _ctaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: data.gradientTop.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 배경 그라디언트(선형) + 라디얼 오버레이 2개
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  data.gradientTop,
                  data.gradientMid,
                  data.gradientBottom,
                ],
                stops: const [0, 0.62, 1],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.4, -0.8),
                radius: 0.9,
                colors: [
                  data.radial1.withValues(alpha: 0.32),
                  data.radial1.withValues(alpha: 0),
                ],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.7, 0.85),
                radius: 0.85,
                colors: [
                  data.radial2.withValues(alpha: 0.2),
                  data.radial2.withValues(alpha: 0),
                ],
              ),
            ),
          ),

          // 별 반짝임
          AnimatedBuilder(
            animation: _clock,
            builder: (context, _) {
              final elapsedMs = _clock.value * 3600 * 1000;
              return CustomPaint(
                painter: _StarsPainter(stars: _stars, elapsedMs: elapsedMs),
                child: const SizedBox.expand(),
              );
            },
          ),

          // 회전 마법진(sigil)
          Positioned(
            top: 0,
            bottom: 0,
            right: -70,
            child: Center(
              child: AnimatedBuilder(
                animation: _sigilCtrl,
                builder: (context, _) {
                  return Transform.rotate(
                    angle: _sigilCtrl.value * 2 * math.pi,
                    child: Opacity(
                      opacity: 0.55,
                      child: CustomPaint(
                        size: const Size(220, 220),
                        painter: _SigilPainter(
                          color: data.sigilColor,
                          shape: data.sigilShape,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // 후광(halo)
          Positioned(
            right: -30,
            bottom: -40,
            child: AnimatedBuilder(
              animation: _haloCtrl,
              builder: (context, _) {
                final scale = 1 + _haloCtrl.value * 0.1;
                final opacity = 0.8 + _haloCtrl.value * 0.2;
                return Opacity(
                  opacity: opacity,
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            data.haloColor.withValues(alpha: 0.4),
                            data.haloColor.withValues(alpha: 0.12),
                            data.haloColor.withValues(alpha: 0),
                          ],
                          stops: const [0, 0.4, 0.7],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // 신통도령 캐릭터(float + tilt)
          Positioned(
            right: data.doryeongOffsetRight,
            bottom: data.doryeongOffsetBottom,
            width: 155,
            height: 155,
            child: AnimatedBuilder(
              animation: _floatCtrl,
              builder: (context, _) {
                final dy = -6 * _floatCtrl.value;
                return Transform.translate(
                  offset: Offset(0, dy),
                  child: AnimatedBuilder(
                    animation: _tiltCtrl,
                    builder: (context, _) {
                      final angleDeg = -1.5 + 3.0 * _tiltCtrl.value;
                      return Transform.rotate(
                        angle: angleDeg * math.pi / 180,
                        child: Image.asset(
                          data.imageAsset,
                          fit: BoxFit.contain,
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),

          // 스파클(pop)
          ..._sparkles.map(
            (s) => _SparkleWidget(
              spec: s,
              shape: data.sparkleShape,
              colors: data.sparkleColors,
            ),
          ),

          // NEW/TODAY/HOT 배지(pulse)
          Positioned(
            top: 12,
            right: 12,
            child: AnimatedBuilder(
              animation: _badgeCtrl,
              builder: (context, _) {
                final scale = 1 + _badgeCtrl.value * 0.06;
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: data.badgeBg,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: data.badgeBg.withValues(alpha: 0.5),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      data.badgeLabel,
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.8,
                        color: data.badgeFg,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // 콘텐츠(Eyebrow / Title / Sub / CTA)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.eyebrow,
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.7,
                    color: data.eyebrowColor,
                  ),
                ),
                const SizedBox(height: 6),
                _buildTitle(data),
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth:
                        (MediaQuery.of(context).size.width - 4 * 2 - 40) * 0.55,
                  ),
                  child: Text(
                    data.sub,
                    style: GoogleFonts.gowunBatang(
                      fontSize: 11,
                      height: 1.5,
                      color: const Color(0xFFE8DCF5).withValues(alpha: 0.85),
                    ),
                  ),
                ),
                const Spacer(),
                AnimatedBuilder(
                  animation: _ctaCtrl,
                  builder: (context, _) {
                    final scale = 1 + _ctaCtrl.value * 0.04;
                    return Transform.scale(
                      scale: scale,
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: data.ctaBg,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: data.ctaBg.withValues(alpha: 0.5),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              data.ctaIcon,
                              style: TextStyle(fontSize: 10, color: data.ctaFg),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              data.ctaLabel,
                              style: GoogleFonts.gowunBatang(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: data.ctaFg,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle(_BannerSlideData data) {
    final line1 = data.titleLines[0];
    final line2 = data.titleLines[1];
    final match = RegExp(r'\{accent\}(.*)\{/\}').firstMatch(line2);
    final before = match == null ? line2 : line2.substring(0, match.start);
    final accentText = match?.group(1) ?? '';
    final after = match == null ? '' : line2.substring(match.end);

    // [google_fonts 6.2.1 고정 버전] 이 버전에는 'Noto Serif KR' 전용 메서드가
    // 없어(패키지 내 검증됨: notoSerifKr 미정의), README.md 스펙의 "900 Noto
    // Serif KR" 타이틀 느낌을 가장 가깝게 재현하는 한글 세리프 `nanumMyeongjo`로
    // 대체한다(무게감 있는 명조체 헤드라인, fontWeight로 최대한 굵게 보정).
    final baseStyle = GoogleFonts.nanumMyeongjo(
      fontSize: 20,
      height: 1.15,
      fontWeight: FontWeight.w900,
      letterSpacing: -0.6,
      color: const Color(0xFFF8F2E6),
    );

    return RichText(
      text: TextSpan(
        style: baseStyle,
        children: [
          TextSpan(text: '$line1\n'),
          TextSpan(text: before),
          if (accentText.isNotEmpty)
            TextSpan(
              text: accentText,
              style: baseStyle.copyWith(
                foreground: Paint()
                  ..shader = LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: data.accentGradient,
                  ).createShader(const Rect.fromLTWH(0, 0, 100, 24)),
              ),
            ),
          TextSpan(text: after),
        ],
      ),
    );
  }
}

class _StarSpec {
  const _StarSpec({
    required this.left,
    required this.top,
    required this.size,
    required this.durationMs,
    required this.delayMs,
    required this.baseOpacity,
  });

  final double left; // 0..1 비율
  final double top; // 0..1 비율
  final double size;
  final int durationMs;
  final int delayMs;
  final double baseOpacity;
}

class _StarsPainter extends CustomPainter {
  _StarsPainter({required this.stars, required this.elapsedMs});

  final List<_StarSpec> stars;
  final double elapsedMs;

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in stars) {
      final t = ((elapsedMs - s.delayMs) % s.durationMs) / s.durationMs;
      final phase = t < 0 ? t + 1 : t;
      // CSS keyframe: 0%,100% opacity base, scale1; 50% opacity 0.2, scale0.6
      final wave = (math.sin(phase * 2 * math.pi - math.pi / 2) + 1) / 2;
      final opacity = 0.2 + wave * (s.baseOpacity - 0.2);
      final scale = 0.6 + wave * 0.4;
      final cx = s.left * size.width;
      final cy = s.top * size.height;
      final r = (s.size * scale) / 2;
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: opacity.clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(cx, cy), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarsPainter oldDelegate) => true;
}

class _SigilPainter extends CustomPainter {
  _SigilPainter({required this.color, required this.shape});

  final Color color;
  final _SigilShape shape;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final scale = size.width / 200; // 원본 viewBox -100..100 => 200
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6 * scale
      ..color = color.withValues(alpha: 0.55);
    canvas.drawCircle(center, 90 * scale, ring);
    canvas.drawCircle(
      center,
      86 * scale,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.4 * scale
        ..color = color.withValues(alpha: 0.3),
    );

    // 36개 눈금(ticks)
    final tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.4 * scale
      ..color = color.withValues(alpha: 0.45);
    for (int i = 0; i < 36; i++) {
      final a = (i / 36) * 2 * math.pi;
      final p1 = center + Offset(math.cos(a), math.sin(a)) * 84 * scale;
      final p2 = center + Offset(math.cos(a), math.sin(a)) * 90 * scale;
      canvas.drawLine(p1, p2, tickPaint);
    }

    switch (shape) {
      case _SigilShape.hexagon:
        final path = Path();
        const pts = [
          [0, -58],
          [50, -29],
          [50, 29],
          [0, 58],
          [-50, 29],
          [-50, -29],
        ];
        for (int i = 0; i < pts.length; i++) {
          final p =
              center +
              Offset(pts[i][0].toDouble(), pts[i][1].toDouble()) * scale;
          if (i == 0) {
            path.moveTo(p.dx, p.dy);
          } else {
            path.lineTo(p.dx, p.dy);
          }
        }
        path.close();
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.5 * scale
            ..color = color.withValues(alpha: 0.6),
        );
        canvas.drawCircle(
          center,
          26 * scale,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.4 * scale
            ..color = color.withValues(alpha: 0.4),
        );
        _drawStar(canvas, center, scale, color.withValues(alpha: 0.55));
        break;
      case _SigilShape.diamond:
        canvas.drawCircle(
          center,
          72 * scale,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.4 * scale
            ..color = color.withValues(alpha: 0.35),
        );
        canvas.drawCircle(
          center,
          54 * scale,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.3 * scale
            ..color = color.withValues(alpha: 0.25),
        );
        _drawStar(
          canvas,
          center,
          scale,
          color.withValues(alpha: 0.55),
          big: true,
        );
        break;
      case _SigilShape.heart:
        final path = Path();
        void moveTo(double x, double y) =>
            path.moveTo(center.dx + x * scale, center.dy + y * scale);
        void curveTo(
          double x1,
          double y1,
          double x2,
          double y2,
          double x3,
          double y3,
        ) => path.cubicTo(
          center.dx + x1 * scale,
          center.dy + y1 * scale,
          center.dx + x2 * scale,
          center.dy + y2 * scale,
          center.dx + x3 * scale,
          center.dy + y3 * scale,
        );
        moveTo(0, 20);
        curveTo(-20, -10, -50, -10, -50, -30);
        curveTo(-50, -50, -20, -50, 0, -25);
        curveTo(20, -50, 50, -50, 50, -30);
        curveTo(50, -10, 20, -10, 0, 20);
        path.close();
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.6 * scale
            ..color = color.withValues(alpha: 0.55),
        );
        break;
    }
  }

  void _drawStar(
    Canvas canvas,
    Offset center,
    double scale,
    Color color, {
    bool big = false,
  }) {
    final path = Path();
    final pts = big
        ? const [
            [0, -14],
            [3.5, -3.5],
            [14, -3.5],
            [5.5, 3.5],
            [9, 14],
            [0, 8],
            [-9, 14],
            [-5.5, 3.5],
            [-14, -3.5],
            [-3.5, -3.5],
          ]
        : const [
            [0, -12],
            [3, -3],
            [12, -3],
            [5, 3],
            [8, 12],
            [0, 7],
            [-8, 12],
            [-5, 3],
            [-12, -3],
            [-3, -3],
          ];
    for (int i = 0; i < pts.length; i++) {
      final p =
          center + Offset(pts[i][0].toDouble(), pts[i][1].toDouble()) * scale;
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SigilPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.shape != shape;
}

class _SparkleSpec {
  const _SparkleSpec({
    required this.size,
    required this.durationMs,
    required this.delayMs,
    this.left,
    this.right,
    this.top,
    this.bottom,
  });

  final double? left;
  final double? right;
  final double? top;
  final double? bottom;
  final double size;
  final int durationMs;
  final int delayMs;
}

class _SparkleWidget extends StatefulWidget {
  const _SparkleWidget({
    required this.spec,
    required this.shape,
    required this.colors,
  });

  final _SparkleSpec spec;
  final _SparkleShape shape;
  final List<Color> colors;

  @override
  State<_SparkleWidget> createState() => _SparkleWidgetState();
}

class _SparkleWidgetState extends State<_SparkleWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.spec.durationMs),
    );
    Future.delayed(Duration(milliseconds: widget.spec.delayMs), () {
      if (mounted) _ctrl.repeat();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    final color =
        widget.colors[(spec.delayMs + spec.durationMs) % widget.colors.length];
    return Positioned(
      left: spec.left,
      right: spec.right,
      top: spec.top,
      bottom: spec.bottom,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final t = _ctrl.value;
          double opacity;
          double scale;
          double rotateDeg;
          if (t < 0.35) {
            final k = t / 0.35;
            opacity = k;
            scale = 0.3 + k * 0.7;
            rotateDeg = k * 90;
          } else if (t < 0.7) {
            final k = (t - 0.35) / 0.35;
            opacity = 1;
            scale = 1 + k * 0.15;
            rotateDeg = 90 + k * 90;
          } else {
            final k = (t - 0.7) / 0.3;
            opacity = 1 - k;
            scale = 1.15 - k * 0.85;
            rotateDeg = 180 + k * 90;
          }
          return Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform.rotate(
              angle: rotateDeg * math.pi / 180,
              child: Transform.scale(
                scale: scale,
                child: CustomPaint(
                  size: Size(spec.size, spec.size),
                  painter: _SparklePainter(color: color, shape: widget.shape),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SparklePainter extends CustomPainter {
  _SparklePainter({required this.color, required this.shape});

  final Color color;
  final _SparkleShape shape;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    final paint = Paint()..color = color;
    final path = Path();
    if (shape == _SparkleShape.star) {
      const pts = [
        [12, 2],
        [14, 10],
        [22, 12],
        [14, 14],
        [12, 22],
        [10, 14],
        [2, 12],
        [10, 10],
      ];
      for (int i = 0; i < pts.length; i++) {
        final p = Offset(pts[i][0].toDouble(), pts[i][1].toDouble()) * scale;
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
    } else {
      void moveTo(double x, double y) => path.moveTo(x * scale, y * scale);
      void curveTo(
        double x1,
        double y1,
        double x2,
        double y2,
        double x3,
        double y3,
      ) => path.cubicTo(
        x1 * scale,
        y1 * scale,
        x2 * scale,
        y2 * scale,
        x3 * scale,
        y3 * scale,
      );
      moveTo(12, 21);
      curveTo(8, 17, 4, 15, 4, 10);
      curveTo(4, 7, 6.5, 5, 9, 5);
      curveTo(10.7, 5, 12, 6, 12, 6);
      curveTo(12, 6, 13.3, 5, 15, 5);
      curveTo(17.5, 5, 20, 7, 20, 10);
      curveTo(20, 15, 16, 17, 12, 21);
      path.close();
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.shape != shape;
}
