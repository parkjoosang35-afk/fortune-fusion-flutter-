import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../intro_palette.dart';
import 'onboarding_orb_sigil.dart';

/// [온보딩 전면 교체 2026-11 — design_handoff_onboarding_v2.zip 반영]
/// `Onboarding v2.html` `.orb` 블록 — 달 + 마법진 2겹 + 공전 별 + 한자
/// 글리프(命/願/福 중 현재 슬라이드만 표시) + 緣 인장. README §2 "Stage —
/// Orb(달 + 마법진)" 수치를 그대로 이식한다.
///
/// 크기: `width: min(72vw, 290px, 40dvh)`(700px 이하는 `min(56vw, 210px,
/// 32dvh)`) — 호출부([_IntroPagerScreenState])가 이미 반응형 폭을 계산해
/// 전달하므로 이 위젯은 전달받은 [size] 정사각형을 그대로 채운다.
class OnboardingOrb extends StatelessWidget {
  const OnboardingOrb({
    super.key,
    required this.size,
    required this.glyphIndex,
    required this.reduceMotion,
  });

  final double size;

  /// 0=命, 1=願, 2=福 — 현재 캐러셀 장에 대응하는 한자만 보인다.
  final int glyphIndex;
  final bool reduceMotion;

  static const List<String> _glyphs = ['命', '願', '福'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // 바깥 마법진 — 100%, 160s 시계방향, color glow op .6.
          SizedBox(
            width: size,
            height: size,
            child: OnboardingRotatingSigil(
              periodSeconds: 160,
              reduceMotion: reduceMotion,
              painterBuilder: (r) => OnboardingOuterSigilPainter(
                color: IntroPalette.primary,
                opacity: 0.6,
                rotationRadians: r,
              ),
            ),
          ),
          // 안쪽 마법진 — inset 16%, 90s 반시계방향, color crystal op .5.
          SizedBox(
            width: size * 0.68,
            height: size * 0.68,
            child: OnboardingRotatingSigil(
              periodSeconds: 90,
              reverse: true,
              reduceMotion: reduceMotion,
              painterBuilder: (r) => OnboardingInnerSigilPainter(
                color: IntroPalette.crystal,
                opacity: 0.5,
                rotationRadians: r,
              ),
            ),
          ),
          // 공전 별 — inset 9% 원 궤도, 36s 1회전.
          SizedBox(
            width: size * 0.82,
            height: size * 0.82,
            child: _OrbitingStars(
              periodSeconds: 36,
              reduceMotion: reduceMotion,
            ),
          ),
          // 달.
          SizedBox(
            width: size * 0.52,
            height: size * 0.52,
            child: _Moon(reduceMotion: reduceMotion),
          ),
          // 한자 글리프 — 命/願/福 중 하나만 opacity 1로 전환.
          SizedBox(
            width: size * 0.52,
            height: size * 0.52,
            child: Stack(
              alignment: Alignment.center,
              children: [
                for (var i = 0; i < _glyphs.length; i++)
                  _GlyphLayer(
                    text: _glyphs[i],
                    visible: i == glyphIndex,
                    fontSizeBase: size,
                  ),
              ],
            ),
          ),
          // 인장 神通 — right 6%, bottom 12%, 세로쓰기.
          Positioned(
            right: size * 0.06,
            bottom: size * 0.12,
            child: _Seal(fontSizeBase: size),
          ),
        ],
      ),
    );
  }
}

/// 공전 별 — 위쪽 ✦(crystal), 아래쪽 ✧(glow), 11px + text-shadow 8px.
class _OrbitingStars extends StatefulWidget {
  const _OrbitingStars({required this.periodSeconds, required this.reduceMotion});

  final int periodSeconds;
  final bool reduceMotion;

  @override
  State<_OrbitingStars> createState() => _OrbitingStarsState();
}

class _OrbitingStarsState extends State<_OrbitingStars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.periodSeconds),
    );
    if (!widget.reduceMotion) {
      _controller.repeat();
    }
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
        final angle = _controller.value * 2 * math.pi;
        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.rotate(
              angle: angle,
              child: Align(
                alignment: Alignment.topCenter,
                child: _starGlyph('✦', IntroPalette.crystal),
              ),
            ),
            Transform.rotate(
              angle: angle,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: _starGlyph('✧', IntroPalette.primary),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _starGlyph(String glyph, Color color) {
    return Text(
      glyph,
      style: TextStyle(
        fontSize: 11,
        color: color,
        shadows: [Shadow(color: color, blurRadius: 8)],
      ),
    );
  }
}

/// 달 — radial-gradient + 크레이터 3개 + shadow(glow + inset).
class _Moon extends StatefulWidget {
  const _Moon({required this.reduceMotion});

  final bool reduceMotion;

  @override
  State<_Moon> createState() => _MoonState();
}

class _MoonState extends State<_Moon> with SingleTickerProviderStateMixin {
  late final AnimationController _breathe;

  @override
  void initState() {
    super.initState();
    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    if (!widget.reduceMotion) {
      _breathe.repeat(reverse: true);
    } else {
      _breathe.value = 0.5;
    }
  }

  @override
  void dispose() {
    _breathe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _breathe,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_breathe.value);
        final blur1 = 44 + t * (64 - 44);
        final blur2 = 100 + t * (140 - 100);
        final alpha1 = 0.45 + t * (0.65 - 0.45);
        final alpha2 = 0.18 + t * (0.3 - 0.18);
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              center: Alignment(-0.28, -0.36),
              colors: [
                Color(0xFFFDF8FF),
                Color(0xFFF1DCFA),
                Color(0xFFD6BDEC),
                Color(0xFFA993D1),
              ],
              stops: [0.0, 0.35, 0.70, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: IntroPalette.primary.withValues(alpha: alpha1),
                blurRadius: blur1,
              ),
              BoxShadow(
                color: IntroPalette.primary.withValues(alpha: alpha2),
                blurRadius: blur2,
              ),
            ],
          ),
          child: CustomPaint(painter: _MoonCraterPainter()),
        );
      },
    );
  }
}

/// 크레이터 3개 — (64%,70%) r8% / (30%,62%) r5% / (70%,30%) r4%.
class _MoonCraterPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    void crater(double cx, double cy, double rPct, Color color) {
      canvas.drawCircle(
        Offset(cx * w, cy * h),
        rPct * w,
        Paint()..color = color,
      );
    }

    crater(0.64, 0.70, 0.08, const Color(0x598F7BBF));
    crater(0.30, 0.62, 0.05, const Color(0x408F7BBF));
    crater(0.70, 0.30, 0.04, const Color(0x388F7BBF));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 한자 글리프 — 命/願/福 중 현재 슬라이드만 opacity/scale/blur 전환.
class _GlyphLayer extends StatelessWidget {
  const _GlyphLayer({
    required this.text,
    required this.visible,
    required this.fontSizeBase,
  });

  final String text;
  final bool visible;
  final double fontSizeBase;

  @override
  Widget build(BuildContext context) {
    // clamp(48px, 15vw, 64px) 근사 — Orb 크기 기준으로 스케일.
    final fontSize = (fontSizeBase * 0.30).clamp(32.0, 64.0);
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeInOut,
      opacity: visible ? 1.0 : 0.0,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 1400),
        curve: const Cubic(0.2, 0.7, 0.2, 1),
        scale: visible ? 1.0 : 0.85,
        child: Semantics(
          excludeSemantics: true,
          child: Text(
            text,
            style: GoogleFonts.nanumMyeongjo(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              height: 1.0,
              color: const Color(0xC73D3568),
              shadows: const [
                Shadow(
                  color: Color(0x80FFFFFF),
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 인장 神通 — 세로쓰기, 인주색(seal red) 그라디언트 배지, rotate(6deg).
class _Seal extends StatelessWidget {
  const _Seal({required this.fontSizeBase});

  final double fontSizeBase;

  @override
  Widget build(BuildContext context) {
    final scale = (fontSizeBase / 290).clamp(0.6, 1.1);
    return Transform.rotate(
      angle: 6 * math.pi / 180,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 7 * scale,
          vertical: 6 * scale,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6 * scale),
          gradient: const LinearGradient(
            begin: Alignment(-0.6, -1),
            end: Alignment(0.6, 1),
            colors: [
              IntroPalette.introSealLight,
              Color(0xFFC94A3B),
              IntroPalette.introSealDark,
            ],
            stops: [0.0, 0.55, 1.0],
          ),
          border: Border.all(
            color: const Color(0x40FFDCC8),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFC94A3B).withValues(alpha: 0.45),
              blurRadius: 18 * scale,
              offset: Offset(0, 4 * scale),
            ),
            const BoxShadow(
              color: Color(0x40FFFFFF),
              blurRadius: 0,
              offset: Offset(0, 1),
            ),
          ],
        ),
        // `writing-mode: vertical-rl` 근사 — 짧은 2자 한자를 세로로
        // 쌓아 세로쓰기 인상을 재현한다(회전이 아니라 수직 배치).
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '神',
              style: GoogleFonts.nanumMyeongjo(
                fontWeight: FontWeight.w800,
                fontSize: 15 * scale,
                color: IntroPalette.introSealText,
                height: 1.1,
              ),
            ),
            Text(
              '通',
              style: GoogleFonts.nanumMyeongjo(
                fontWeight: FontWeight.w800,
                fontSize: 15 * scale,
                color: IntroPalette.introSealText,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
