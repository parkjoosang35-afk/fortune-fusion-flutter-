// [타로 인트로 핸드오프 이식] "메인 타로섹션" 진입 시 표시되는 5초(+2.6초
// 사전연출) 로딩 인트로. 원본 스펙: uploaded_files/handoff3_extracted/
// (README.md / TarotIntro.jsx / tarot-intro.css). 이 화면은 다음의 텍스트/
// 색상/구조/타이밍을 "임의로 바꾸지 않고" 그대로 재현한다(부적게이트 사건의
// 교훈 반영):
//   - 워드마크: "신통방통" 4글자 순차 등장 + 크롬(금색) 스윕
//   - 라벨: "TAROT · 神通萬通"
//   - 카피: "신통방통 타로, 보이지 않는 마음의 흐름을 읽다."
//   - 힌트: "잠시, 카드를 섞는 중"
//   - 타이밍: 2.6s 시점부터 5→1 카운트다운 시작, 총 7.6초 후 타로 메인 진입
//
// 진입 흐름(README §동작 요약): 사용자가 "타로" 진입점을 탭 → 이 화면이
// 마운트 → 애니메이션 재생 → 카운트다운 완료 → 타로 메인(TarotHomeScreen,
// AppRouter.tarotHomeRoute)으로 pushReplacementNamed.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/router/app_router.dart' show AppRouter;

/// 원본 CSS `.tarot-intro` 스코프 디자인 토큰 그대로.
class _TI {
  _TI._();
  static const Color bg1 = Color(0xFF0E4D5A); // teal top
  static const Color bg2 = Color(0xFF06212A); // deep base
  static const Color fg = Color(0xFFFDF7E6); // warm off-white
  static const Color glow = Color(0xFFF5CF6A); // candle gold
  static const Color cool = Color(0xFF8BDCDC); // mystic aqua
}

const int _kRingStartDelayMs = 2600; // README: ring fill / countdown 시작 시점

class TarotIntroScreen extends StatefulWidget {
  const TarotIntroScreen({
    super.key,
    this.duration = 5,
    this.targetRoute = AppRouter.tarotHomeRoute,
    this.label = 'TAROT · 神通萬通',
    this.copyBrand = '신통방통 타로',
    this.copyRest = '보이지 않는 마음의 흐름을 읽다.',
    this.hint = '잠시, 카드를 섞는 중',
  });

  /// 카운트다운 시간(초). 기본 5 — README 기본값과 동일.
  final int duration;

  /// 카운트다운 완료 시 이동할 라우트. 기본값은 타로 메인 정문.
  final String targetRoute;
  final String label;
  final String copyBrand;
  final String copyRest;
  final String hint;

  @override
  State<TarotIntroScreen> createState() => _TarotIntroScreenState();
}

class _TarotIntroScreenState extends State<TarotIntroScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _ms = 0;
  late int _count;
  Timer? _countdownTimer;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _count = widget.duration;
    _ticker = createTicker(_onTick)..start();
    Future.delayed(const Duration(milliseconds: _kRingStartDelayMs), () {
      if (!mounted) return;
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() => _count -= 1);
        if (_count <= 0) {
          t.cancel();
          _finish();
        }
      });
    });
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
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ms = _ms;
    return Scaffold(
      backgroundColor: _TI.bg2,
      body: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── 배경 그라디언트(원본 radial-gradient 근사) ──
            const _BgGradient(),
            _StarField(ms: ms),
            _CentralGlow(ms: ms),
            _OuterSigil(ms: ms),
            _InnerSigil(ms: ms),
            _CardFan(ms: ms),
            _DustLayer(ms: ms),
            _CenterContent(
              ms: ms,
              label: widget.label,
              copyBrand: widget.copyBrand,
              copyRest: widget.copyRest,
            ),
            _Loader(ms: ms, count: _count, hint: widget.hint),
          ],
        ),
      ),
    );
  }
}

// ---------------- 시간 기반 애니메이션 헬퍼 ----------------

double _clamp01(double v) => v.clamp(0.0, 1.0);

/// [start, start+dur] 구간의 진행률(0~1), easeOutCubic 적용.
double _progress(double ms, double start, double dur, {Curve? curve}) {
  final t = _clamp01((ms - start) / dur);
  return (curve ?? Curves.easeOutCubic).transform(t);
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// 0%→max, 50%→min, 100%→max (opacity 펄스류).
double _pulseDown(double phase, double min, double max) {
  final base = (min + max) / 2;
  final amp = (max - min) / 2;
  return base + amp * math.cos(2 * math.pi * phase);
}

/// 0%→min, 50%→max, 100%→min (scale 펄스류).
double _pulseUp(double phase, double min, double max) {
  final base = (min + max) / 2;
  final amp = (max - min) / 2;
  return base - amp * math.cos(2 * math.pi * phase);
}

double _loopPhase(double ms, double start, double period) {
  if (ms < start) return 0;
  return ((ms - start) % period) / period;
}

// ---------------- 배경 ----------------

class _BgGradient extends StatelessWidget {
  const _BgGradient();
  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -1),
              radius: 1.4,
              colors: [
                const Color(0xFF0B3D47),
                _TI.bg1,
                const Color(0xFF0D5766),
                const Color(0xFF0F4D5C),
                const Color(0xFF0A2F3A),
                _TI.bg2,
              ],
              stops: const [0.0, 0.22, 0.42, 0.62, 0.88, 1.0],
            ),
          ),
        ),
        // ::after 이중 비네트(상/하단 암전)
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, 1),
              radius: 0.9,
              colors: [Color(0x8C000000), Colors.transparent],
              stops: [0.0, 0.6],
            ),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -1),
              radius: 1.0,
              colors: [Color(0x59000000), Colors.transparent],
              stops: [0.0, 0.6],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------- 별밭 ----------------

class _StarField extends StatelessWidget {
  const _StarField({required this.ms});
  final double ms;

  static const List<(double, double, double)> _stars = [
    (0.12, 0.18, 1.0),
    (0.78, 0.09, 1.0),
    (0.34, 0.32, 1.0),
    (0.88, 0.24, 1.5),
    (0.58, 0.45, 1.0),
    (0.20, 0.62, 1.0),
    (0.72, 0.68, 1.5),
    (0.44, 0.78, 1.0),
    (0.90, 0.84, 1.0),
    (0.08, 0.92, 1.0),
  ];

  @override
  Widget build(BuildContext context) {
    final fadeIn = _progress(ms, 200, 1600);
    final twinkle = ms >= 2000 ? _pulseDown(_loopPhase(ms, 2000, 4400), 0.55, 1.0) : 1.0;
    final opacity = fadeIn * twinkle;
    return IgnorePointer(
      child: CustomPaint(
        painter: _StarFieldPainter(stars: _stars, opacity: opacity),
        size: Size.infinite,
      ),
    );
  }
}

class _StarFieldPainter extends CustomPainter {
  _StarFieldPainter({required this.stars, required this.opacity});
  final List<(double, double, double)> stars;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.55 * opacity);
    for (final s in stars) {
      canvas.drawCircle(Offset(s.$1 * size.width, s.$2 * size.height), s.$3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarFieldPainter oldDelegate) =>
      oldDelegate.opacity != opacity;
}

// ---------------- 중앙 글로우 ----------------

class _CentralGlow extends StatelessWidget {
  const _CentralGlow({required this.ms});
  final double ms;

  @override
  Widget build(BuildContext context) {
    final fadeIn = _progress(ms, 900, 2200);
    final pulseOpacity = ms >= 3100 ? _pulseDown(_loopPhase(ms, 3100, 5000), 0.75, 1.0) : 1.0;
    final pulseScale = ms >= 3100 ? _pulseUp(_loopPhase(ms, 3100, 5000), 1.0, 1.08) : 1.0;
    return IgnorePointer(
      child: Center(
        child: Opacity(
          opacity: _clamp01(fadeIn * pulseOpacity),
          child: Transform.scale(
            scale: pulseScale,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _TI.glow.withValues(alpha: 0.22),
                    _TI.cool.withValues(alpha: 0.10),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.3, 0.65],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------- 마법진(외곽 12룬 + 내부 육각별) ----------------

class _OuterSigil extends StatelessWidget {
  const _OuterSigil({required this.ms});
  final double ms;

  @override
  Widget build(BuildContext context) {
    final entrance = _progress(ms, 400, 2400);
    final opacity = _lerp(0, 0.5, entrance);
    final scale = _lerp(0.7, 1.0, entrance);
    final entranceRotationDeg = _lerp(-30, 0, entrance);
    final spinDeg = ms >= 2400 ? (ms - 2400) / 90000 * 360 : 0.0;
    final rotationRad = (entranceRotationDeg + spinDeg) * math.pi / 180;
    return IgnorePointer(
      child: Center(
        child: Transform.scale(
          scale: scale,
          child: SizedBox(
            width: 260,
            height: 260,
            child: CustomPaint(
              painter: _OuterSigilPainter(opacity: opacity, rotation: rotationRad),
            ),
          ),
        ),
      ),
    );
  }
}

class _OuterSigilPainter extends CustomPainter {
  _OuterSigilPainter({required this.opacity, required this.rotation});
  final double opacity;
  final double rotation;

  static const List<(String, double, double)> _runes = [
    ('神', 0, -82),
    ('通', 41, -71),
    ('萬', 71, -41),
    ('通', 82, 0),
    ('✧', 71, 41),
    ('☾', 41, 71),
    ('◈', 0, 82),
    ('✵', -41, 71),
    ('❋', -71, 41),
    ('✺', -82, 0),
    ('✶', -71, -41),
    ('⟡', -41, -71),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;
    final scale = size.width / 200.0;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(rotation);

    final ring1 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5 * scale
      ..color = _TI.fg.withValues(alpha: 0.5 * opacity);
    canvas.drawCircle(Offset.zero, 94 * scale, ring1);

    final ring2 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.4 * scale
      ..color = _TI.fg.withValues(alpha: 0.3 * opacity);
    canvas.drawCircle(Offset.zero, 88 * scale, ring2);

    final dashPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5 * scale
      ..color = _TI.glow.withValues(alpha: 0.45 * opacity);
    _drawDashedCircle(canvas, 70 * scale, dashPaint, 1 * scale, 3 * scale);

    for (final r in _runes) {
      _drawCenteredText(
        canvas,
        r.$1,
        Offset(r.$2 * scale, r.$3 * scale),
        7 * scale,
        _TI.fg.withValues(alpha: 0.7 * opacity),
        fontFamily: 'serif',
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _OuterSigilPainter oldDelegate) =>
      oldDelegate.opacity != opacity || oldDelegate.rotation != rotation;
}

class _InnerSigil extends StatelessWidget {
  const _InnerSigil({required this.ms});
  final double ms;

  @override
  Widget build(BuildContext context) {
    final entrance = _progress(ms, 700, 2000);
    final opacity = _lerp(0, 0.32, entrance);
    final scale = _lerp(0.5, 1.0, entrance);
    final entranceRotationDeg = _lerp(30, 0, entrance);
    final spinDeg = ms >= 2700 ? (ms - 2700) / 120000 * 360 : 0.0;
    // reverse 방향(시계 반대)
    final rotationRad = (entranceRotationDeg - spinDeg) * math.pi / 180;
    return IgnorePointer(
      child: Center(
        child: Transform.scale(
          scale: scale,
          child: SizedBox(
            width: 150,
            height: 150,
            child: CustomPaint(
              painter: _InnerSigilPainter(opacity: opacity, rotation: rotationRad),
            ),
          ),
        ),
      ),
    );
  }
}

class _InnerSigilPainter extends CustomPainter {
  _InnerSigilPainter({required this.opacity, required this.rotation});
  final double opacity;
  final double rotation;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;
    final scale = size.width / 200.0;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(rotation);

    Offset p(double x, double y) => Offset(x * scale, y * scale);

    canvas.drawCircle(
      Offset.zero,
      88 * scale,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6 * scale
        ..color = _TI.glow.withValues(alpha: 0.5 * opacity),
    );
    canvas.drawCircle(
      Offset.zero,
      70 * scale,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.4 * scale
        ..color = _TI.fg.withValues(alpha: 0.35 * opacity),
    );

    final hexPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6 * scale
      ..color = _TI.fg.withValues(alpha: 0.5 * opacity);
    final hexPath = Path()
      ..addPolygon([
        p(0, -72),
        p(62, -36),
        p(62, 36),
        p(0, 72),
        p(-62, 36),
        p(-62, -36),
      ], true);
    canvas.drawPath(hexPath, hexPaint);

    final triPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5 * scale
      ..color = _TI.glow.withValues(alpha: 0.4 * opacity);
    canvas.drawPath(
      Path()..addPolygon([p(0, 72), p(-62, -36), p(62, -36)], true),
      triPaint,
    );
    canvas.drawPath(
      Path()..addPolygon([p(0, -72), p(-62, 36), p(62, 36)], true),
      triPaint,
    );

    canvas.drawCircle(
      Offset.zero,
      30 * scale,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5 * scale
        ..color = _TI.fg.withValues(alpha: 0.5 * opacity),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _InnerSigilPainter oldDelegate) =>
      oldDelegate.opacity != opacity || oldDelegate.rotation != rotation;
}

void _drawDashedCircle(
  Canvas canvas,
  double radius,
  Paint paint,
  double dashLen,
  double gapLen,
) {
  if (radius <= 0) return;
  final circumference = 2 * math.pi * radius;
  double pos = 0;
  final rect = Rect.fromCircle(center: Offset.zero, radius: radius);
  while (pos < circumference) {
    final startAngle = pos / radius;
    final sweepAngle = dashLen / radius;
    canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
    pos += dashLen + gapLen;
  }
}

void _drawCenteredText(
  Canvas canvas,
  String text,
  Offset center,
  double fontSize,
  Color color, {
  String? fontFamily,
}) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(fontSize: fontSize, color: color, fontFamily: fontFamily),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
}

// ---------------- 타로 카드 3장 부채꼴 ----------------

class _CardFan extends StatelessWidget {
  const _CardFan({required this.ms});
  final double ms;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: const Alignment(0, -0.1),
        child: SizedBox(
          width: 240,
          height: 300,
          child: Stack(
            alignment: Alignment.center,
            children: [
              _FanCard(
                ms: ms,
                startMs: 900,
                targetDx: -72,
                targetDy: -14,
                targetRotateDeg: -14,
                targetScale: 1.0,
                targetOpacity: 0.85,
                floatStart: 2500,
                glyph: '☾',
                zIndexAbove: false,
              ),
              _FanCard(
                ms: ms,
                startMs: 1300,
                targetDx: 72,
                targetDy: -14,
                targetRotateDeg: 14,
                targetScale: 1.0,
                targetOpacity: 0.85,
                floatStart: 2900,
                glyph: '✧',
                zIndexAbove: false,
              ),
              _FanCard(
                ms: ms,
                startMs: 1100,
                targetDx: 0,
                targetDy: -28,
                targetRotateDeg: 0,
                targetScale: 1.05,
                targetOpacity: 1.0,
                floatStart: 2700,
                glyph: '✦',
                zIndexAbove: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FanCard extends StatelessWidget {
  const _FanCard({
    required this.ms,
    required this.startMs,
    required this.targetDx,
    required this.targetDy,
    required this.targetRotateDeg,
    required this.targetScale,
    required this.targetOpacity,
    required this.floatStart,
    required this.glyph,
    required this.zIndexAbove,
  });

  final double ms;
  final double startMs;
  final double targetDx;
  final double targetDy;
  final double targetRotateDeg;
  final double targetScale;
  final double targetOpacity;
  final double floatStart;
  final String glyph;
  final bool zIndexAbove;

  @override
  Widget build(BuildContext context) {
    final t = _progress(ms, startMs, 1600);
    final opacity = _lerp(0, targetOpacity, t);
    final dx = _lerp(0, targetDx, t);
    final dy = _lerp(-20, targetDy, t);
    final rotateDeg = _lerp(0, targetRotateDeg, t);
    final scale = _lerp(0.7, targetScale, t);

    // idle float(진입 완료 후 은은한 상하 흔들림)
    double floatDy = 0;
    if (ms >= floatStart) {
      final phase = _loopPhase(ms, floatStart, 6000);
      floatDy = _pulseUp(phase, 0, -6 - (dy - dy)); // 0 ~ -6 사이 진동
      floatDy = -3 + 3 * math.cos(2 * math.pi * phase);
    }

    return Transform.translate(
      offset: Offset(dx, dy + floatDy),
      child: Transform.rotate(
        angle: rotateDeg * math.pi / 180,
        child: Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: _clamp01(opacity),
            child: Container(
              width: 88,
              height: 138,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1A3540), Color(0xFF0A1E26)],
                ),
                border: Border.all(color: _TI.glow.withValues(alpha: 0.5)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: _TI.glow.withValues(alpha: 0.15),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Text(
                glyph,
                style: GoogleFonts.notoSansKr(
                  fontSize: 32,
                  color: _TI.glow,
                  shadows: [
                    Shadow(color: _TI.glow.withValues(alpha: 0.7), blurRadius: 12),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------- 떠오르는 먼지 입자 ----------------

class _DustLayer extends StatelessWidget {
  const _DustLayer({required this.ms});
  final double ms;

  // (leftPercent, delayMs, durationMs)
  static const List<(double, double, double)> _particles = [
    (0.07, 0, 9000),
    (0.18, 1400, 11000),
    (0.27, 700, 8000),
    (0.39, 2600, 12000),
    (0.52, 3200, 9000),
    (0.64, 1100, 10000),
    (0.73, 4000, 11000),
    (0.84, 2000, 9000),
    (0.91, 5200, 12000),
    (0.46, 6000, 8000),
    (0.33, 4600, 10000),
    (0.60, 5800, 11000),
  ];

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _DustPainter(ms: ms, particles: _particles),
        size: Size.infinite,
      ),
    );
  }
}

class _DustPainter extends CustomPainter {
  _DustPainter({required this.ms, required this.particles});
  final double ms;
  final List<(double, double, double)> particles;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final left = p.$1;
      final delay = p.$2;
      final duration = p.$3;
      if (ms < delay) continue;
      final phase = ((ms - delay) % duration) / duration;
      double opacity;
      if (phase < 0.15) {
        opacity = _lerp(0, 0.9, phase / 0.15);
      } else if (phase < 0.85) {
        opacity = _lerp(0.9, 0.5, (phase - 0.15) / 0.70);
      } else {
        opacity = _lerp(0.5, 0, (phase - 0.85) / 0.15);
      }
      final dy = size.height * 0.0 + (-phase * size.height * 1.1) + size.height - 12;
      final dx = left * size.width + phase * 24;
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFBE5A4).withValues(alpha: opacity),
            const Color(0xFFFBE5A4).withValues(alpha: 0),
          ],
          stops: const [0.0, 0.62],
        ).createShader(Rect.fromCircle(center: Offset(dx, dy), radius: 3));
      canvas.drawCircle(Offset(dx, dy), 1.8, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DustPainter oldDelegate) => oldDelegate.ms != ms;
}

// ---------------- 중앙 컨텐츠(아치+워드마크+라벨+카피) ----------------

class _CenterContent extends StatelessWidget {
  const _CenterContent({
    required this.ms,
    required this.label,
    required this.copyBrand,
    required this.copyRest,
  });

  final double ms;
  final String label;
  final String copyBrand;
  final String copyRest;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Arc(ms: ms),
              const SizedBox(height: 2),
              _Wordmark(ms: ms),
              const SizedBox(height: 12),
              _LabelRow(ms: ms, label: label),
              const SizedBox(height: 20),
              _CopyText(ms: ms, copyBrand: copyBrand, copyRest: copyRest),
            ],
          ),
        ),
      ),
    );
  }
}

class _Arc extends StatelessWidget {
  const _Arc({required this.ms});
  final double ms;
  @override
  Widget build(BuildContext context) {
    final progress = _progress(ms, 400, 1400);
    return SizedBox(
      width: 130,
      height: 40,
      child: CustomPaint(painter: _ArcPainter(progress: progress)),
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final sx = size.width / 300;
    final sy = size.height / 60;
    final path = Path()
      ..moveTo(8 * sx, 52 * sy)
      ..quadraticBezierTo(150 * sx, -8 * sy, 292 * sx, 52 * sy);
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final metric = metrics.first;
    final extracted = metric.extractPath(0, metric.length * progress);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = _TI.fg;
    canvas.drawPath(extracted, paint);
  }

  @override
  bool shouldRepaint(covariant _ArcPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.ms});
  final double ms;

  static const List<String> _chars = ['신', '통', '방', '통'];
  static const List<double> _delays = [600, 750, 900, 1050];

  @override
  Widget build(BuildContext context) {
    // 크롬 스윕: 0% pos100% → 60% pos-50% → 100% pos-50%(유지), 3.2s 루프, 0.6s 지연.
    double sweepT = 0;
    if (ms >= 600) {
      final phase = _loopPhase(ms, 600, 3200);
      sweepT = phase < 0.6 ? Curves.easeOutCubic.transform(phase / 0.6) : 1.0;
    }
    final shiftX = _lerp(1.0, -0.5, sweepT); // 100% -> -50% (배경 위치 비율)

    return Semantics(
      label: '신통방통',
      child: ShaderMask(
        shaderCallback: (bounds) {
          final w = bounds.width;
          // background-size 250% 를 텍스트 폭 기준으로 근사 확장.
          final gradWidth = w * 2.5;
          final left = bounds.left - w * (shiftX - 0);
          return const LinearGradient(
            colors: [
              Color(0xFFFDF7E6),
              Color(0xFFFDF7E6),
              Colors.white,
              _TI.glow,
              Colors.white,
              Color(0xFFFDF7E6),
              Color(0xFFFDF7E6),
            ],
            stops: [0.0, 0.3, 0.45, 0.5, 0.55, 0.7, 1.0],
          ).createShader(Rect.fromLTWH(left, bounds.top, gradWidth, bounds.height));
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: List.generate(_chars.length, (i) {
            final t = _progress(ms, _delays[i], 1000);
            return Opacity(
              opacity: _clamp01(t),
              child: Transform.translate(
                offset: Offset(0, _lerp(10, 0, t)),
                child: Text(
                  _chars[i],
                  style: GoogleFonts.notoSansKr(
                    fontWeight: FontWeight.w900,
                    fontSize: 28,
                    letterSpacing: -1.1,
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _LabelRow extends StatelessWidget {
  const _LabelRow({required this.ms, required this.label});
  final double ms;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = _progress(ms, 1700, 1000);
    return Opacity(
      opacity: _clamp01(t),
      child: Transform.translate(
        offset: Offset(0, _lerp(8, 0, t)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 24, height: 1, color: _TI.glow.withValues(alpha: 0.6)),
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.ibmPlexMono(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                letterSpacing: 4.2,
                color: _TI.glow.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(width: 10),
            Container(width: 24, height: 1, color: _TI.glow.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }
}

class _CopyText extends StatelessWidget {
  const _CopyText({required this.ms, required this.copyBrand, required this.copyRest});
  final double ms;
  final String copyBrand;
  final String copyRest;

  @override
  Widget build(BuildContext context) {
    final t = _progress(ms, 2100, 1400);
    return Opacity(
      opacity: _clamp01(t),
      child: Transform.translate(
        offset: Offset(0, _lerp(8, 0, t)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: copyBrand,
                  style: GoogleFonts.gowunBatang(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    letterSpacing: -0.1,
                    color: _TI.glow,
                  ),
                ),
                TextSpan(
                  text: ',\n$copyRest',
                  style: GoogleFonts.gowunBatang(
                    fontSize: 13.5,
                    height: 1.7,
                    letterSpacing: 0.3,
                    color: _TI.fg.withValues(alpha: 0.82),
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

// ---------------- 하단 카운트다운 링 로더 ----------------

class _Loader extends StatelessWidget {
  const _Loader({required this.ms, required this.count, required this.hint});
  final double ms;
  final int count;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final fadeT = _progress(ms, 2400, 800);
    final fillProgress = _clamp01((ms - _kRingStartDelayMs) / 5000);
    return IgnorePointer(
      child: Align(
        alignment: const Alignment(0, 0.82),
        child: Opacity(
          opacity: _clamp01(fadeT),
          child: Transform.translate(
            offset: Offset(0, _lerp(8, 0, fadeT)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 44,
                  height: 44,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(44, 44),
                        painter: _RingPainter(fillProgress: fillProgress),
                      ),
                      Text(
                        '$count',
                        style: GoogleFonts.ibmPlexMono(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                          color: _TI.glow,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  hint,
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 4.2,
                    color: _TI.fg.withValues(alpha: 0.5),
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

class _RingPainter extends CustomPainter {
  _RingPainter({required this.fillProgress});
  final double fillProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 2.5;
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = _TI.fg.withValues(alpha: 0.15);
    canvas.drawCircle(center, radius, trackPaint);

    if (fillProgress <= 0) return;
    final fillPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..color = _TI.glow;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * fillProgress,
      false,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.fillProgress != fillProgress;
}
