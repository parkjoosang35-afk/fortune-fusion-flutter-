import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../intro_palette.dart';
import 'onboarding_sigil.dart';

/// 공용 진행률 계산 — [SplashScreen]의 `_progress` 헬퍼와 동일한 패턴.
double _progress(double elapsed, double start, double duration) {
  if (duration <= 0) return elapsed >= start ? 1.0 : 0.0;
  return ((elapsed - start) / duration).clamp(0.0, 1.0);
}

/// [온보딩 화면 교체 2026-10-11] `Onboarding.html` `.hero` 블록 — 아치형
/// 프레임 히어로 이미지 + 헤일로(halo) + 마법진(sigil) + 인장(緣) 조합.
/// README §1-1 / 개발지시서 §03-2 수치를 그대로 이식한다.
///
/// 레이어 순서(바깥→안):
/// 1. halo — 원형 radial glow, breathe 애니메이션(B2, 5s)
/// 2. sigil — Hero의 150% 크기, 중앙(50%,44%), 회전(B1, 140s)
/// 3. frame — 그라디언트 테두리(6px) + 아치 상단/둥근 하단
/// 4. art — 실제 일러스트, Ken Burns(B3, 18s) + shimmer 스윕(B4, 7s)
///    + 하단 비네팅
/// 5. seal — "緣" 인장, 우하단 고정, 8° 회전
///
/// 등장 애니메이션(A1 Hero / A2 인장)은 [entryProgress](0~1, 호출부의
/// 진입 시퀀스 컨트롤러 값)로 제어한다. 앰비언트(B1~B4)는 이 위젯이
/// 자체 컨트롤러로 무한 반복한다.
class OnboardingHeroFrame extends StatefulWidget {
  const OnboardingHeroFrame({
    super.key,
    required this.heroAsset,
    required this.elapsedSeconds,
    this.reduceMotion = false,
  });

  /// 일러스트 에셋 경로(기존 앱 원본 — `hero-fullbody.png`).
  final String heroAsset;

  /// 진입 시퀀스 시작부터 경과한 시간(초). A1(0.2s~1.8s)/A2(1.5s~2.4s)
  /// 타이밍을 이 값 하나로 정확히 계산한다(스플래시 화면의 `elapsed`
  /// 패턴과 동일).
  final double elapsedSeconds;

  final bool reduceMotion;

  @override
  State<OnboardingHeroFrame> createState() => _OnboardingHeroFrameState();
}

class _OnboardingHeroFrameState extends State<OnboardingHeroFrame>
    with TickerProviderStateMixin {
  // B2 halo breathe: scale .97↔1.03, opacity .7↔1, 5s ease-in-out.
  late final AnimationController _haloController;
  // B3 Ken Burns: scale 1.02→1.10, y -1.5%, 18s ease-in-out alternate.
  late final AnimationController _kenBurnsController;
  // B4 shimmer sweep: 7s, 지연 2.2s, 이동은 앞 35% 구간.
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _haloController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    );
    _kenBurnsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 18000),
    );
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7000),
    );
    if (!widget.reduceMotion) {
      _haloController.repeat(reverse: true);
      _kenBurnsController.repeat(reverse: true);
      Future.delayed(const Duration(milliseconds: 2200), () {
        if (mounted) _shimmerController.repeat();
      });
    } else {
      _haloController.value = 0.5;
      _kenBurnsController.value = 0.5;
    }
  }

  @override
  void dispose() {
    _haloController.dispose();
    _kenBurnsController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A1 Hero: opacity 0→1, translateY 18→0, scale .97→1, blur 6→0.
    // 지연 0.2s / 길이 1.6s(README §1-4 A1).
    final p = _progress(widget.elapsedSeconds, 0.2, 1.6);
    final eased = Curves.easeOutCubic.transform(p);

    Widget hero = AspectRatio(
      aspectRatio: 280 / 410,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. halo
          Positioned.fill(
            child: FractionallySizedBox(
              widthFactor: 1.36, // inset -18% 양쪽 → 폭 +36%
              heightFactor: 1.24, // inset -12% 양쪽 → 높이 +24%
              alignment: Alignment.center,
              child: AnimatedBuilder(
                animation: _haloController,
                builder: (context, _) {
                  final t = _haloController.value;
                  final scale = 0.97 + t * (1.03 - 0.97);
                  final opacity = 0.7 + t * (1.0 - 0.7);
                  return Opacity(
                    opacity: opacity,
                    child: Transform.scale(
                      scale: scale,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              IntroPalette.primary.withValues(alpha: 0.28),
                              IntroPalette.primary.withValues(alpha: 0.08),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.6, 1.0],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          // 2. sigil — Hero의 150% 크기, 중앙(50%, 44%).
          Positioned.fill(
            child: Align(
              alignment: const Alignment(0, -0.12), // top:44% 근사
              child: FractionallySizedBox(
                widthFactor: 1.5,
                heightFactor: 1.5,
                child: OnboardingSigil(
                  color: IntroPalette.primary,
                  opacity: 0.55,
                  reduceMotion: widget.reduceMotion,
                ),
              ),
            ),
          ),
          // 3~4. frame + art.
          Positioned.fill(
            child: _ArchFrame(
              asset: widget.heroAsset,
              kenBurnsController: _kenBurnsController,
              shimmerController: _shimmerController,
            ),
          ),
          // 5. seal — 緣, 우하단. 지연 1.5s / 길이 0.9s(README §1-4 A2).
          Positioned(
            right: -10,
            bottom: 22,
            child: _Seal(
              progress: _progress(widget.elapsedSeconds, 1.5, 0.9),
            ),
          ),
        ],
      ),
    );

    return Opacity(
      opacity: eased,
      child: Transform.translate(
        offset: Offset(0, 18 * (1 - eased)),
        child: Transform.scale(
          scale: 0.97 + 0.03 * eased,
          child: hero,
        ),
      ),
    );
  }
}

/// 3~4. 아치형 프레임(그라디언트 테두리) + 내부 art(일러스트 + Ken
/// Burns + shimmer + 비네팅).
class _ArchFrame extends StatelessWidget {
  const _ArchFrame({
    required this.asset,
    required this.kenBurnsController,
    required this.shimmerController,
  });

  final String asset;
  final AnimationController kenBurnsController;
  final AnimationController shimmerController;

  static const _archRadius = BorderRadius.only(
    topLeft: Radius.circular(999),
    topRight: Radius.circular(999),
    bottomLeft: Radius.circular(22),
    bottomRight: Radius.circular(22),
  );
  static const _innerArchRadius = BorderRadius.only(
    topLeft: Radius.circular(999),
    topRight: Radius.circular(999),
    bottomLeft: Radius.circular(17),
    bottomRight: Radius.circular(17),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        borderRadius: _archRadius,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            IntroPalette.primary.withValues(alpha: 0.55),
            IntroPalette.crystal.withValues(alpha: 0.18),
            IntroPalette.primary.withValues(alpha: 0.35),
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A061E).withValues(alpha: 0.55),
            blurRadius: 50,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: IntroPalette.glowShadow,
            blurRadius: 40,
          ),
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: _innerArchRadius,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.18),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: _innerArchRadius,
          child: Container(
            color: IntroPalette.backgroundBottom,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // art-img — Ken Burns scale 1.02→1.10, y -1.5%.
                AnimatedBuilder(
                  animation: kenBurnsController,
                  builder: (context, _) {
                    final t = kenBurnsController.value;
                    final scale = 1.02 + t * (1.10 - 1.02);
                    return Transform.translate(
                      offset: Offset(0, -t * 6),
                      child: Transform.scale(
                        scale: scale,
                        alignment: const Alignment(0, -0.3), // origin 50% 35%
                        child: Image.asset(
                          asset,
                          fit: BoxFit.cover,
                          alignment: const Alignment(0, -0.6),
                        ),
                      ),
                    );
                  },
                ),
                // 하단 비네팅.
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        IntroPalette.backgroundBottom.withValues(alpha: 0.75),
                      ],
                      stops: const [0.6, 1.0],
                    ),
                  ),
                ),
                // shimmer — 115° 띠, 앞 35% 구간 이동.
                AnimatedBuilder(
                  animation: shimmerController,
                  builder: (context, _) {
                    final t = shimmerController.value;
                    if (t > 0.35) {
                      return const SizedBox.shrink();
                    }
                    final progress = t / 0.35; // 0~1
                    final pos = -1.2 + progress * 2.4; // -120% → 120%
                    return IgnorePointer(
                      child: ShaderMask(
                        blendMode: BlendMode.srcOver,
                        shaderCallback: (bounds) {
                          return LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.transparent,
                              Colors.white.withValues(alpha: 0.18),
                              Colors.transparent,
                            ],
                            stops: [
                              (pos - 0.15).clamp(0.0, 1.0),
                              pos.clamp(0.0, 1.0),
                              (pos + 0.15).clamp(0.0, 1.0),
                            ],
                          ).createShader(bounds);
                        },
                        child: Container(color: Colors.black),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 5. 인장 "緣" — 42×42, radius 6, rotate(8deg). A2(스탬프 등장,
/// cubic-bezier(.34,1.56,.64,1) 스프링 근사) scale 1.8→1, opacity 0→1.
class _Seal extends StatelessWidget {
  const _Seal({required this.progress});

  /// 0~1. 0=아직 등장 전(투명), 1=등장 완료.
  final double progress;

  @override
  Widget build(BuildContext context) {
    final p = progress.clamp(0.0, 1.0);
    final eased = Curves.elasticOut.transform(p.clamp(0.0, 0.999));
    final scale = p <= 0 ? 0.0 : (1.8 + (1 - 1.8) * eased);
    final opacity = p <= 0 ? 0.0 : 1.0;

    return Opacity(
      opacity: opacity,
      child: Transform.rotate(
        angle: 8 * math.pi / 180,
        child: Transform.scale(
          scale: scale.clamp(0.0, 3.0),
          child: Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [IntroPalette.glowLight, IntroPalette.primary],
              ),
              boxShadow: [
                BoxShadow(
                  color: IntroPalette.glowShadow,
                  blurRadius: 18,
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.6),
                  blurRadius: 0,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              '緣',
              style: GoogleFonts.nanumMyeongjo(
                fontWeight: FontWeight.w800, // 핸드오프 900 요청, 폰트 최대치 800 근사.
                fontSize: 22,
                color: IntroPalette.onPrimary,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
