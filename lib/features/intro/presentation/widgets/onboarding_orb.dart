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
          // 바깥 마법진 — 100%, 160s 시계방향. [온보딩 v3] color
          // glow(#e0c264) op .55(기존 라벤더 primary op .6 대체).
          SizedBox(
            width: size,
            height: size,
            child: OnboardingRotatingSigil(
              periodSeconds: 160,
              reduceMotion: reduceMotion,
              painterBuilder: (r) => OnboardingOuterSigilPainter(
                color: IntroPalette.onboardingV3Glow,
                opacity: 0.55,
                rotationRadians: r,
              ),
            ),
          ),
          // 안쪽 마법진 — inset 16%, 90s 반시계방향. [온보딩 v3] color
          // crystal(#9fb6dc) op .45(기존 라벤더 crystal op .5 대체).
          SizedBox(
            width: size * 0.68,
            height: size * 0.68,
            child: OnboardingRotatingSigil(
              periodSeconds: 90,
              reverse: true,
              reduceMotion: reduceMotion,
              painterBuilder: (r) => OnboardingInnerSigilPainter(
                color: IntroPalette.onboardingV3Crystal,
                opacity: 0.45,
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
          // [온보딩 v3 — 神通 인장 삭제] README §2 "神通 인장 → 삭제":
          // Orb 오른쪽 아래의 빨간 세로 인장(神通)과 등장 애니메이션을
          // 모두 제거한다. 과거 `_Seal` 위젯 정의는 아래에 더 이상
          // 참조되지 않지만 프로젝트 관례(구 코드 보존)에 따라 그대로
          // 남겨 두고, 호출부(여기)에서만 제거한다.
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
                child: _starGlyph('✦', IntroPalette.onboardingV3Crystal),
              ),
            ),
            Transform.rotate(
              angle: angle,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: _starGlyph('✧', IntroPalette.onboardingV3Glow),
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
        // [온보딩 v3] README §2 "달" 빛 숨쉬기 — alpha .45↔.65(색만
        // 골드로 교체, blur 범위는 기존과 동일).
        final alpha1 = 0.45 + t * (0.65 - 0.45);
        final alpha2 = 0.18 + t * (0.3 - 0.18);
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // [온보딩 v3] README §2 "달" 면 — `radial-gradient(circle at
            // 36% 32%, #fffaee 0%, #f7e8bf 35%, #e3c47c 70%, #b88e45
            // 100%)`(기존 라벤더 4색 대체, center 좌표는 동일).
            gradient: const RadialGradient(
              center: Alignment(-0.28, -0.36),
              colors: [
                Color(0xFFFFFAEE),
                Color(0xFFF7E8BF),
                Color(0xFFE3C47C),
                Color(0xFFB88E45),
              ],
              stops: [0.0, 0.35, 0.70, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: IntroPalette.onboardingV3Glow.withValues(alpha: alpha1),
                blurRadius: blur1,
              ),
              BoxShadow(
                color: IntroPalette.onboardingV3Glow.withValues(alpha: alpha2),
                blurRadius: blur2,
              ),
              // README "inset -14px -18px 34px rgba(110,70,20,.35)" —
              // Flutter BoxDecoration은 inset shadow를 직접 지원하지
              // 않으므로 `_MoonCraterPainter` 쪽에서 근사한 음영을 더해
              // 입체감을 보완한다(아래 크레이터 참고).
            ],
          ),
          child: CustomPaint(painter: _MoonCraterPainter()),
        );
      },
    );
  }
}

/// 크레이터 3개 — (64%,70%) r8% / (30%,62%) r5% / (70%,30%) r4%.
/// [온보딩 v3] README §2 "달" 크레이터 — 보라빛 틴트에서 갈색
/// `rgba(170,130,60, a)`(a=.28/.20/.18)로 교체.
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

    crater(0.64, 0.70, 0.08, const Color(0x47AA823C));
    crater(0.30, 0.62, 0.05, const Color(0x33AA823C));
    crater(0.70, 0.30, 0.04, const Color(0x2EAA823C));
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
              // [온보딩 v3] README §2 "달" 한자 글리프 — 짙은 갈색 음각
              // `rgba(70,48,18,.72)`(기존 라벤더 잉크 대체).
              color: const Color(0xB8463012),
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

// [온보딩 v3 — 신통 인장 삭제] README §2 "神通 인장 → 삭제"에 따라
// `_Seal` 위젯 전체(정의)를 제거했다. v2까지는 Orb 오른쪽 아래에
// 세로쓰기 빨간 인장(神通)을 그렸으나, v3는 브랜드 교체로 더 이상
// 표시하지 않는다(진입 시퀀스의 인장 1.6s 단계도 함께 사라짐).
// `IntroPalette.introSealLight/introSealDark/introSealText`는 다른
// 화면이 참조하지 않는 이 전용 토큰이지만, 프로젝트 관례(구 코드/토큰
// 보존 원칙)에 따라 `intro_palette.dart`에서는 삭제하지 않고 남겨둔다.
