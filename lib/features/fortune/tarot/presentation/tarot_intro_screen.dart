// [타로 인트로 로딩화면 전면 교체 — 2026 핸드오프 이식]
// 원본 스펙: uploaded_files/design_handoff_tarot_loading.zip
// (`README.md` / `TAROT Loading.html` / `assets/tarot-hero.png`).
//
// "Arcana · Nocturne" 무드의 후드 인물+타로카드+보름달 일러스트 위에
// 골드 마법진/룬/스파크가 떠오르고, 하단에 진행률 바 + 4단계(25%마다)
// 문구가 교차되는 로딩 화면. 핸드오프 README는 "held on screen for
// approximately 9 seconds"로 명시하고 있어, 총 노출 시간을 9초로 고정한다
// (사용자가 9초로 맞춘 것이 핸드오프 스펙과 정확히 일치함 — 7초 아님).
//
// [진입 흐름] 사용자가 "타로" 진입점을 탭 → 이 화면이 마운트되는 즉시
// 0%→100% 진행률이 9초에 걸쳐 채워짐 → 9초 경과 시 타로 메인
// (TarotHomeScreen, AppRouter.tarotHomeRoute)으로 pushReplacementNamed.
//
// [폰트 대체] 프로젝트에 고정된 `google_fonts: 6.2.1`에는 'Noto Serif KR'
// 전용 메서드가 없어(다른 화면에서도 이미 확인된 제약, 예:
// sintong_hero_carousel.dart, oz_theme.dart 주석 참고), 동일한 명조 계열인
// `nanumMyeongjo`로 대체한다. `Cormorant Garamond`/`Gowun Batang`/
// `IBM Plex Mono`는 6.2.1에 그대로 존재해 스펙과 동일하게 사용한다.
//
// [이미지 크롭] 원본 `tarot-hero.png`(572×1024)는 우측 ~35%에 영문
// 텍스트("Adult · Musit and TAROT Application")가 베이크되어 있어, 핸드오프
// CSS와 동일한 비율(좌측 약 62% 영역, 세로 전체)로 사전에 크롭해
// `assets/images/tarot/tarot_loading_hero.png`(340×606, 9:16에 근접)로
// 저장했다 — 런타임에 `background-position`/`background-size` 트릭을
// 재현할 필요 없이 `BoxFit.cover`만으로 텍스트 패널이 보이지 않는다.
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/router/app_router.dart' show AppRouter;

/// 핸드오프 `:root` 디자인 토큰 그대로.
class _TL {
  _TL._();
  static const Color ink = Color(0xFF0B0616);
  static const Color gold = Color(0xFFF5CF6A);
  static const Color gold2 = Color(0xFFF2E0A8);
  static const Color violet = Color(0xFF6B4A9A);
  static const Color fg = Color(0xFFF8F2E6);
}

class TarotIntroScreen extends StatefulWidget {
  const TarotIntroScreen({
    super.key,
    this.duration = 9,
    this.targetRoute = AppRouter.tarotHomeRoute,
  });

  /// 인트로 전체 노출 시간(초). 핸드오프 스펙(총 9000ms)과 동일하게 9초
  /// 고정. 진행률 바가 0%→100%로 이 시간에 걸쳐 정확히 채워진 뒤 이동한다.
  final int duration;

  /// 완료 시 이동할 라우트. 기본값은 타로 메인 정문.
  final String targetRoute;

  @override
  State<TarotIntroScreen> createState() => _TarotIntroScreenState();
}

class _TarotIntroScreenState extends State<TarotIntroScreen>
    with SingleTickerProviderStateMixin {
  static const List<(String, String)> _phases = [
    ('ARCANA · 001', '별자리를 정렬하는 중'),
    ('ARCANA · 002', '카드의 숨을 고르는 중'),
    ('ARCANA · 003', '당신의 오늘을 읽는 중'),
    ('ARCANA · 004', '봉인이 곧 풀립니다'),
  ];

  late final Ticker _ticker;
  double _ms = 0;
  Timer? _finishTimer;
  bool _finished = false;

  int get _totalMs => widget.duration * 1000;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    _finishTimer = Timer(Duration(seconds: widget.duration), _finish);
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    setState(() => _ms = elapsed.inMilliseconds.toDouble());
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    Navigator.of(context).pushReplacementNamed(widget.targetRoute);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _finishTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ms = _ms;
    final pct = _clamp01(ms / _totalMs) * 100;
    final phaseIdx = (pct / 25).floor().clamp(0, _phases.length - 1);

    return Scaffold(
      backgroundColor: _TL.ink,
      body: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // z-0 히어로 배경 일러스트 (breathe 애니메이션)
            _HeroImage(ms: ms),
            // z-1 웜톤 컬러그레이드 워시
            _HeroTint(ms: ms),
            // z-2 비네트(상/하단만 어둡게)
            const _Vignette(),
            // z-3 회전 외곽 마법진 + 룬
            _SigilOverlay(ms: ms),
            // z-4 떠오르는 골드 스파크
            _Sparks(ms: ms),
            // z-4 카드 영역 오라 펄스
            _Aura(ms: ms),
            // z-20 상단 브랜드 필
            _TopBrand(ms: ms),
            // z-20 하단 로더 블록
            _LoaderBlock(ms: ms, pct: pct, phaseIdx: phaseIdx),
          ],
        ),
      ),
    );
  }
}

// ---------------- 시간 기반 애니메이션 헬퍼 ----------------

double _clamp01(double v) => v.clamp(0.0, 1.0);

double _progress(double ms, double start, double dur, {Curve? curve}) {
  final t = _clamp01((ms - start) / dur);
  return (curve ?? Curves.easeOutCubic).transform(t);
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// 0%→max, 50%→min, 100%→max.
double _pulseDown(double phase, double min, double max) {
  final base = (min + max) / 2;
  final amp = (max - min) / 2;
  return base + amp * math.cos(2 * math.pi * phase);
}

/// 0%→min, 50%→max, 100%→min.
double _pulseUp(double phase, double min, double max) {
  final base = (min + max) / 2;
  final amp = (max - min) / 2;
  return base - amp * math.cos(2 * math.pi * phase);
}

double _loopPhase(double ms, double start, double period) {
  if (ms < start) return 0;
  return ((ms - start) % period) / period;
}

/// 채도 보정용 컬러 매트릭스(HTML `filter: saturate()`에 대응).
List<double> _saturationMatrix(double s) {
  const lumR = 0.2126, lumG = 0.7152, lumB = 0.0722;
  final sr = (1 - s) * lumR;
  final sg = (1 - s) * lumG;
  final sb = (1 - s) * lumB;
  return <double>[
    sr + s, sg, sb, 0, 0,
    sr, sg + s, sb, 0, 0,
    sr, sg, sb + s, 0, 0,
    0, 0, 0, 1, 0, //
  ];
}

// ---------------- 레이어 1: 히어로 이미지 ----------------

/// `hero-breathe` — 14s ease-in-out infinite, scale 1.0→1.04→1.0 +
/// saturation 1.0→1.1→1.0.
class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.ms});
  final double ms;

  @override
  Widget build(BuildContext context) {
    final phase = _loopPhase(ms, 0, 14000);
    final scale = _pulseUp(phase, 1.0, 1.04);
    final saturation = _pulseUp(phase, 1.0, 1.1);
    return IgnorePointer(
      child: Transform.scale(
        scale: scale,
        child: ColorFiltered(
          colorFilter: ColorFilter.matrix(_saturationMatrix(saturation)),
          child: Image.asset(
            'assets/images/tarot/tarot_loading_hero.png',
            fit: BoxFit.cover,
            alignment: const Alignment(0, -0.15),
            width: double.infinity,
            height: double.infinity,
          ),
        ),
      ),
    );
  }
}

/// `.hero-tint` — 골드(달 주변) + 바이올렛(하단 옷자락) 라디얼 그라디언트,
/// mix-blend-mode: screen, opacity 0.9.
class _HeroTint extends StatelessWidget {
  const _HeroTint({required this.ms});
  final double ms;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(painter: _HeroTintPainter(), size: Size.infinite),
    );
  }
}

class _HeroTintPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 골드 — 달 부근 (50% 32%, 반경 70%x45%)
    final goldCenter = Offset(size.width * 0.5, size.height * 0.32);
    final goldRadius = size.width * 0.7;
    final goldPaint = Paint()
      ..blendMode = BlendMode.screen
      ..shader = RadialGradient(
        colors: [
          _TL.gold.withValues(alpha: 0.9 * 0.14),
          _TL.gold.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.7],
      ).createShader(
        Rect.fromCircle(center: goldCenter, radius: goldRadius),
      );
    canvas.drawRect(Offset.zero & size, goldPaint);

    // 바이올렛 — 옷자락 하단 (50% 85%, 반경 50%x40%)
    final violetCenter = Offset(size.width * 0.5, size.height * 0.85);
    final violetRadius = size.width * 0.5;
    final violetPaint = Paint()
      ..blendMode = BlendMode.screen
      ..shader = RadialGradient(
        colors: [
          _TL.violet.withValues(alpha: 0.9 * 0.25),
          _TL.violet.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.7],
      ).createShader(
        Rect.fromCircle(center: violetCenter, radius: violetRadius),
      );
    canvas.drawRect(Offset.zero & size, violetPaint);
  }

  @override
  bool shouldRepaint(covariant _HeroTintPainter oldDelegate) => false;
}

/// `.vignette` — 상/하단만 어둡게, 중앙 45~65%는 그대로.
class _Vignette extends StatelessWidget {
  const _Vignette();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.10, 0.18, 0.62, 0.78, 0.96, 1.0],
            colors: [
              _TL.ink.withValues(alpha: 0.45),
              _TL.ink.withValues(alpha: 0.10),
              _TL.ink.withValues(alpha: 0),
              _TL.ink.withValues(alpha: 0),
              _TL.ink.withValues(alpha: 0.40),
              _TL.ink.withValues(alpha: 0.92),
              _TL.ink,
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- 레이어 2: 회전 외곽 마법진 ----------------

/// `.sigil-overlay` — top:34%, width:110%, mix-blend:screen, opacity 0.55.
/// 두 개의 골드 링(draw-in 4s, 0.4s/0.9s 스태거) + 12개 룬 글리프(2s부터
/// 0.08s 스태거 1.5s 페이드) + 전체 회전(140s linear infinite).
class _SigilOverlay extends StatelessWidget {
  const _SigilOverlay({required this.ms});
  final double ms;

  static const List<String> _runes = [
    '✧', '✦', '☾', '❋', '◈', '✵', '❈', '✺', '✶', '☆', '◇', '⟡', //
  ];

  @override
  Widget build(BuildContext context) {
    final fadeIn = _progress(ms, 0, 3000, curve: Curves.easeOut);
    final ring1Reveal = _progress(ms, 400, 4000, curve: Curves.easeOut);
    final ring2Reveal = _progress(ms, 900, 4000, curve: Curves.easeOut);
    final spinAngle = (ms / 140000) * 2 * math.pi;
    final runeOpacities = List<double>.generate(
      _runes.length,
      (i) => _progress(ms, 2000 + i * 80, 1500, curve: Curves.easeOut) * 0.65,
    );

    // 주의: `Positioned`는 반드시 `Stack`의 직접 자식이어야 한다. 여기서는
    // `Positioned.fill`을 외곽 Stack의 직접 자식으로 두고, 그 안에서
    // `IgnorePointer`/`LayoutBuilder`를 거쳐 내부 Stack + Positioned로
    // 실제 위치를 계산한다(순서를 반대로 하면 `ParentData is not a
    // subtype of StackParentData` 런타임 예외가 발생한다).
    return Positioned.fill(
      child: IgnorePointer(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            final size = w * 1.1;
            return Stack(
              children: [
                Positioned(
                  left: w / 2 - size / 2,
                  top: h * 0.34 - size / 2,
                  width: size,
                  height: size,
                  child: Opacity(
                    opacity: fadeIn * 0.55,
                    child: Transform.rotate(
                      angle: spinAngle,
                      child: CustomPaint(
                        painter: _SigilPainter(
                          ring1Reveal: ring1Reveal,
                          ring2Reveal: ring2Reveal,
                          runeOpacities: runeOpacities,
                          runes: _runes,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SigilPainter extends CustomPainter {
  _SigilPainter({
    required this.ring1Reveal,
    required this.ring2Reveal,
    required this.runeOpacities,
    required this.runes,
  });

  final double ring1Reveal;
  final double ring2Reveal;
  final List<double> runeOpacities;
  final List<String> runes;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final scale = size.width / 200;

    void drawRevealedCircle(double radius, double opacity, double reveal) {
      if (reveal <= 0) return;
      final rect = Rect.fromCircle(center: center, radius: radius);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.25 * scale
        ..color = _TL.gold.withValues(alpha: opacity);
      final path = Path()..addOval(rect);
      final metrics = path.computeMetrics().toList();
      if (metrics.isEmpty) return;
      final metric = metrics.first;
      final extracted = metric.extractPath(0, metric.length * reveal);
      canvas.drawPath(extracted, paint);
    }

    drawRevealedCircle(96 * scale, 0.5, ring1Reveal);
    drawRevealedCircle(92 * scale, 0.35, ring2Reveal);

    for (var i = 0; i < runes.length; i++) {
      final opacity = runeOpacities[i];
      if (opacity <= 0) continue;
      final angle = (i / runes.length) * 2 * math.pi - math.pi / 2;
      final pos =
          center + Offset(math.cos(angle), math.sin(angle)) * 88 * scale;
      final tp = TextPainter(
        text: TextSpan(
          text: runes[i],
          style: TextStyle(
            fontSize: 4 * scale * 2.4,
            color: _TL.gold.withValues(alpha: opacity),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _SigilPainter oldDelegate) => true;
}

// ---------------- 레이어 3: 떠오르는 스파크 ----------------

/// `.sparks` — 28개 입자, 7~11s ease-out infinite, 스태거 딜레이.
class _Sparks extends StatelessWidget {
  const _Sparks({required this.ms});
  final double ms;

  static final List<_SparkSpec> _specs = List.generate(28, (i) {
    final left = ((i * 13 + 7) % 100) / 100;
    final delayMs = ((i * 0.6) % 9) * 1000;
    final durMs = (7 + (i % 5)) * 1000.0;
    final size = (2 + (i % 3)).toDouble();
    return _SparkSpec(left: left, delayMs: delayMs, durMs: durMs, size: size);
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _SparksPainter(ms: ms, specs: _specs),
        size: Size.infinite,
      ),
    );
  }
}

class _SparkSpec {
  const _SparkSpec({
    required this.left,
    required this.delayMs,
    required this.durMs,
    required this.size,
  });
  final double left;
  final double delayMs;
  final double durMs;
  final double size;
}

class _SparksPainter extends CustomPainter {
  _SparksPainter({required this.ms, required this.specs});
  final double ms;
  final List<_SparkSpec> specs;

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in specs) {
      final phase = ((ms - s.delayMs) % s.durMs) / s.durMs;
      final t = phase < 0 ? phase + 1 : phase;
      double opacity;
      if (t < 0.10) {
        opacity = _lerp(0, 1, t / 0.10);
      } else if (t < 0.70) {
        opacity = _lerp(1, 0.7, (t - 0.10) / 0.60);
      } else {
        opacity = _lerp(0.7, 0, (t - 0.70) / 0.30);
      }
      final scale = _lerp(0.6, 1.1, t);
      final dy = size.height + 12 - t * (size.height + 12);
      final dx = s.left * size.width + t * 20;
      final r = (s.size * scale) / 2;
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFF8DD).withValues(alpha: opacity),
            _TL.gold.withValues(alpha: 0.8 * opacity),
            _TL.gold.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.4, 0.7],
        ).createShader(Rect.fromCircle(center: Offset(dx, dy), radius: r));
      canvas.drawCircle(Offset(dx, dy), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparksPainter oldDelegate) =>
      oldDelegate.ms != ms;
}

// ---------------- 레이어 4: 오라 펄스 ----------------

/// `.aura` — 4s ease-in-out infinite, opacity 0.55↔1, scale 1↔1.06.
class _Aura extends StatelessWidget {
  const _Aura({required this.ms});
  final double ms;

  @override
  Widget build(BuildContext context) {
    final phase = _loopPhase(ms, 0, 4000);
    final opacity = _pulseDown(phase, 0.55, 1.0);
    final scale = _pulseUp(phase, 1.0, 1.06);
    // 주의: `Positioned`는 반드시 `Stack`의 직접 자식이어야 한다(위
    // `_SigilOverlay`와 동일한 이유).
    return Positioned.fill(
      child: IgnorePointer(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final size = w * 0.78;
            return Stack(
              children: [
                Positioned(
                  left: w / 2 - size / 2,
                  top: constraints.maxHeight * 0.42 - size / 2,
                  width: size,
                  height: size,
                  child: Opacity(
                    opacity: opacity,
                    child: Transform.scale(
                      scale: scale,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              _TL.gold.withValues(alpha: 0.12),
                              _TL.gold.withValues(alpha: 0),
                            ],
                            stops: const [0.0, 0.55],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---------------- 레이어 5: 상단 브랜드 필 ----------------

/// `.top-bar > .brand` — fade-down 1.2s (0.2s delay).
class _TopBrand extends StatelessWidget {
  const _TopBrand({required this.ms});
  final double ms;

  @override
  Widget build(BuildContext context) {
    final t = _progress(ms, 200, 1200);
    final topInset = MediaQuery.of(context).padding.top;
    // 주의: `Positioned`는 반드시 `Stack`의 직접 자식이어야 한다(위
    // `_SigilOverlay`/`_Aura`와 동일한 이유).
    return Positioned(
      top: topInset + 20,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, _lerp(-10, 0, t)),
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B0616).withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: _TL.gold.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '占',
                          style: GoogleFonts.nanumMyeongjo(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: _TL.gold,
                            shadows: [
                              Shadow(
                                color: _TL.gold.withValues(alpha: 0.7),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'ARCANA · NOCTURNE',
                          style: GoogleFonts.ibmPlexMono(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 4.2,
                            color: _TL.gold2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------- 레이어 5: 하단 로더 블록 ----------------

/// `.loader` — fade-up 1.4s (0.4s delay), 그라디언트 배경 + 텍스트/바.
class _LoaderBlock extends StatelessWidget {
  const _LoaderBlock({
    required this.ms,
    required this.pct,
    required this.phaseIdx,
  });

  final double ms;
  final double pct;
  final int phaseIdx;

  static const List<(String, String)> _phases = [
    ('ARCANA · 001', '별자리를 정렬하는 중'),
    ('ARCANA · 002', '카드의 숨을 고르는 중'),
    ('ARCANA · 003', '당신의 오늘을 읽는 중'),
    ('ARCANA · 004', '봉인이 곧 풀립니다'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = _progress(ms, 400, 1400);
    final glowPhase = _loopPhase(ms, 0, 4000);
    final glowBlur = _pulseUp(glowPhase, 22, 40);
    final glowAlpha = _pulseUp(glowPhase, 0.45, 0.85);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final pctText = pct.round().toString().padLeft(2, '0');

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, _lerp(20, 0, t)),
          child: Container(
            padding: EdgeInsets.fromLTRB(28, 40, 28, 40 + bottomInset),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.25, 0.60, 1.0],
                colors: [
                  _TL.ink.withValues(alpha: 0),
                  _TL.ink.withValues(alpha: 0.45),
                  _TL.ink.withValues(alpha: 0.85),
                  _TL.ink.withValues(alpha: 0.98),
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Adult · Mystic and Tarot',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cormorantGaramond(
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w300,
                    fontSize: 13,
                    letterSpacing: 2.86,
                    color: const Color(0xFFF5E0A8).withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '타\u00A0로\u00A0점\u00A0술',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nanumMyeongjo(
                    fontWeight: FontWeight.w900,
                    fontSize: 34,
                    letterSpacing: 4.76,
                    height: 1.05,
                    color: _TL.fg,
                    shadows: [
                      Shadow(
                        color: _TL.gold.withValues(alpha: glowAlpha),
                        blurRadius: glowBlur,
                      ),
                      const Shadow(
                        color: Color(0x99000000),
                        blurRadius: 12,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 8.25),
                  child: Text(
                    'T\u00A0A\u00A0R\u00A0O\u00A0T',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cormorantGaramond(
                      fontWeight: FontWeight.w400,
                      fontSize: 15,
                      letterSpacing: 8.25,
                      color: _TL.gold2,
                      shadows: [
                        Shadow(
                          color: _TL.gold.withValues(alpha: 0.45),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _ProgressBar(pct: pct),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _phases[phaseIdx].$1,
                        style: GoogleFonts.ibmPlexMono(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 2.8,
                          color: _TL.gold2,
                        ),
                      ),
                      Text(
                        '$pctText%',
                        style: GoogleFonts.ibmPlexMono(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 2.8,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: _TL.gold.withValues(alpha: 0.55),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0, 0.06),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: Text(
                    _phases[phaseIdx].$2,
                    key: ValueKey(phaseIdx),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.gowunBatang(
                      fontSize: 13.5,
                      letterSpacing: 0.7,
                      color: const Color(0xFFF0E4C8).withValues(alpha: 0.85),
                      shadows: const [
                        Shadow(color: Color(0x8C000000), blurRadius: 6),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '"달이 밝을수록\u00A0·\u00A0카드는 더 정직해집니다"',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.gowunBatang(
                    fontStyle: FontStyle.italic,
                    fontSize: 11.5,
                    letterSpacing: 0.23,
                    color: const Color(0xFFE8DCC8).withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `.bar-wrap > .bar-fill` — 골드 그라디언트 진행률 바 + 밝은 head sprite.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.pct});
  final double pct;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fillWidth = constraints.maxWidth * (pct / 100);
          return SizedBox(
            height: 8,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 2,
                  margin: const EdgeInsets.only(top: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBC8).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Container(
                  width: fillWidth.clamp(0.0, constraints.maxWidth),
                  height: 2,
                  margin: const EdgeInsets.only(top: 3),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _TL.gold.withValues(alpha: 0.5),
                        _TL.gold,
                        const Color(0xFFFFF8DD),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: _TL.gold.withValues(alpha: 0.85),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: (fillWidth - 7).clamp(-6.0, constraints.maxWidth),
                  top: 0,
                  child: Container(
                    width: 12,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFFFF8DD),
                          _TL.gold.withValues(alpha: 0.7),
                          _TL.gold.withValues(alpha: 0),
                        ],
                        stops: const [0.0, 0.45, 0.7],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
