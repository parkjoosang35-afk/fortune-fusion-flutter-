// burn_fx.dart — 부적이 타는 동안의 재·그을림·테두리·불꽃 장식 레이어.
// 웹 원본 `.burnfx`(shrine.css 560~583행, shrine-screens-a.jsx 290~293행)의
// ash/char/edge/flames 네 겹을 1:1 근사 포팅한다.
//
// [신당 집중 수정] RitualScreen(부적 쓰기·태우기)의 burn/reveal/read 단계에서
// 기존에는 ShaderMask 기반의 "종이가 사라지는" 기능적 마스킹만 있었고, 이
// 장식 레이어 자체는 없었다(talisman_stage.dart 15행 주석에 좌표만 남아
// 있었음). 기능(태우기 진행·burnLine)은 그대로 두고, 그 위에 덧그리는
// 순수 시각 효과만 추가한다 — RitualScreen의 로직/문구/흐름은 변경하지 않음.
import 'dart:ui';
import 'package:flutter/material.dart';

/// [burn] 0~1 — RitualScreen.burnLine과 동일한 값(태워진 비율, 아래→위).
/// [done] true면 ph가 더 이상 'burn'이 아님(reveal/read) — 원본 `.burnfx.done`과
/// 동일하게 불꽃·테두리·그을림 번짐을 감추고 재만 은은히 빛나는 정지 상태로 둔다.
class BurnFx extends StatelessWidget {
  final double burn;
  final bool done;
  const BurnFx({super.key, required this.burn, required this.done});

  @override
  Widget build(BuildContext context) {
    final b = (done ? 1.0 : burn).clamp(0.0, 1.0);
    // 원본 opacity 공식 근사: min(1, burn*k) · (1 - max(0, burn-.96)*25) — 타기
    // 시작하면 빠르게 또렷해지고, 거의 다 탄 뒤(.96 이후)엔 빠르게 사라진다.
    double rampDown(double v) =>
        (1 - ((v - .96).clamp(0.0, 1.0) * 25)).clamp(0.0, 1.0);
    final edgeOpacity = done ? 0.0 : (b * 40).clamp(0.0, 1.0) * rampDown(b);
    final charOpacity = done ? 0.0 : (b * 40).clamp(0.0, 1.0);
    final flameOpacity = done ? 0.0 : (b * 30).clamp(0.0, 1.0) * rampDown(b);

    return IgnorePointer(
      child: ClipRect(
        child: LayoutBuilder(
          builder: (context, c) {
            final h = c.maxHeight;
            final w = c.maxWidth;
            final ashH = (h * (b + .02)).clamp(0.0, h + h * .02);
            final edgeY =
                h *
                b; // 컨테이너 bottom 기준 거리 = CSS `bottom: calc(var(--burn)*100%)`
            return Stack(
              clipBehavior: Clip.none,
              children: [
                // ── ash: 타고 지나간 자리를 덮는 어두운 재
                Positioned(
                  left: -w * .03,
                  right: -w * .03,
                  bottom: -h * .02,
                  height: ashH,
                  child: _AshLayer(glowing: done),
                ),
                // ── char: 그을린 경계 바로 위, 흐릿한 주황빛 번짐
                if (!done)
                  Positioned(
                    left: -w * .02,
                    right: -w * .02,
                    bottom: (edgeY - h * .01).clamp(-h, h),
                    height: h * .14,
                    child: Opacity(
                      opacity: charOpacity,
                      child: ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Color(0xF2140804),
                                Color(0xBF461906),
                                Color(0x59965600),
                                Colors.transparent,
                              ],
                              stops: [0, .4, .75, 1],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                // ── edge: 타는 경계선 — 밝게 빛나는 가로줄
                if (!done)
                  Positioned(
                    left: -w * .04,
                    right: -w * .04,
                    bottom: (edgeY - h * .012).clamp(-h, h),
                    height: h * .024,
                    child: Opacity(
                      opacity: edgeOpacity,
                      child: ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 1, sigmaY: 1),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(40),
                            gradient: const LinearGradient(
                              colors: [
                                Colors.transparent,
                                Color(0xFFFFB347),
                                Color(0xFFFFF1B0),
                                Color(0xFFFF7A2A),
                                Color(0xFFFFF1B0),
                                Color(0xFFFFB347),
                                Colors.transparent,
                              ],
                              stops: [0, .08, .30, .55, .75, .92, 1],
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0xD9FF7828),
                                blurRadius: 18,
                                spreadRadius: 6,
                              ),
                              BoxShadow(
                                color: Color(0x8CE0412F),
                                blurRadius: 50,
                                spreadRadius: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                // ── flames: 경계선에서 피어오르는 5개의 흔들리는 불꽃
                if (!done)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: edgeY,
                    height: 0,
                    child: Opacity(
                      opacity: flameOpacity,
                      child: SizedBox(
                        width: w,
                        height: 0,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: const [
                            _Flame(
                              leftFrac: .12,
                              height: 54,
                              periodMs: 380,
                              phase: 0,
                            ),
                            _Flame(
                              leftFrac: .32,
                              height: 82,
                              periodMs: 380,
                              phase: .25,
                            ),
                            _Flame(
                              leftFrac: .52,
                              height: 66,
                              periodMs: 380,
                              phase: .05,
                            ),
                            _Flame(
                              leftFrac: .72,
                              height: 88,
                              periodMs: 380,
                              phase: .30,
                            ),
                            _Flame(
                              leftFrac: .90,
                              height: 50,
                              periodMs: 380,
                              phase: .18,
                            ),
                          ],
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

/// 재 레이어 — 어두운 바탕 + 은은한 잔불 점(ember). `done`이면 원본
/// `@keyframes ashGlow`(밝기 1↔1.6, 3s)처럼 천천히 숨쉬듯 밝아진다.
class _AshLayer extends StatefulWidget {
  final bool glowing;
  const _AshLayer({required this.glowing});
  @override
  State<_AshLayer> createState() => _AshLayerState();
}

class _AshLayerState extends State<_AshLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3000),
  )..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static const _embers = [
    Alignment(-.6, -.55),
    Alignment(.24, .1),
    Alignment(-.2, .6),
  ];

  @override
  Widget build(BuildContext context) {
    Widget base = Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xF70C0604), Color(0xF5160A06)],
            ),
          ),
        ),
        for (final a in _embers)
          Align(
            alignment: a,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xCCFF8C3C),
                    const Color(0xCCFF8C3C).withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
    // 타는 중에는 위쪽으로 갈수록 투명해지는 마스크(원본 webkit-mask 근사)
    base = ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (r) => const LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [Colors.black, Colors.black, Colors.transparent],
        stops: [0, .85, 1],
      ).createShader(r),
      child: base,
    );
    if (!widget.glowing) return base;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => ColorFiltered(
        colorFilter: ColorFilter.mode(
          Colors.white.withValues(alpha: .08 + .08 * _c.value),
          BlendMode.plus,
        ),
        child: child,
      ),
      child: base,
    );
  }
}

/// 불꽃 하나 — 원본 `@keyframes flick2`(scale 1→1.15,1.25 + skew -4°→5°,
/// opacity .85→1, .38s ease-in-out infinite alternate) 근사.
class _Flame extends StatefulWidget {
  final double leftFrac;
  final double height;
  final int periodMs;
  final double phase; // 0~1, 위상차(원본 animation-delay 근사)
  const _Flame({
    required this.leftFrac,
    required this.height,
    required this.periodMs,
    required this.phase,
  });
  @override
  State<_Flame> createState() => _FlameState();
}

class _FlameState extends State<_Flame> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.periodMs),
  )..repeat(reverse: true, period: Duration(milliseconds: widget.periodMs));

  @override
  void initState() {
    super.initState();
    _c.value = widget.phase;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const flameW = 46.0;
    return Positioned(
      left: null,
      bottom: -6,
      child: FractionalTranslation(
        translation: const Offset(-.5, 0),
        child: Builder(
          builder: (context) {
            // leftFrac는 부모(SizedBox width:w) 기준 — Positioned.left를 직접
            // 퍼센트로 줄 수 없으므로 Align으로 가로 위치를 잡는다.
            return Align(
              alignment: Alignment(widget.leftFrac * 2 - 1, 1),
              child: AnimatedBuilder(
                animation: _c,
                builder: (_, __) {
                  final p = _c.value;
                  final scaleX = 1 + .15 * p;
                  final scaleY = 1 + .25 * p;
                  final skew = (-4 + 9 * p) * 3.1415926 / 180;
                  return Opacity(
                    opacity: .85 + .15 * p,
                    child: Transform(
                      alignment: Alignment.bottomCenter,
                      transform: Matrix4.identity()
                        ..scale(scaleX, scaleY)
                        ..setEntry(0, 1, skew),
                      child: ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                        child: Opacity(
                          opacity: .9,
                          child: ClipPath(
                            clipper: _FlameClip(),
                            child: Container(
                              width: flameW,
                              height: widget.height,
                              decoration: const BoxDecoration(
                                gradient: RadialGradient(
                                  center: Alignment(0, .7),
                                  radius: .75,
                                  colors: [
                                    Color(0xFFFFF6C8),
                                    Color(0xFFFFCB4A),
                                    Color(0xD9FF6E1E),
                                    Color(0x59E0412F),
                                    Colors.transparent,
                                  ],
                                  stops: [0, .25, .5, .7, .76],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FlameClip extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width, h = size.height;
    final p = Path();
    p.moveTo(w * .5, h);
    p.cubicTo(w * -.05, h * .55, w * .15, h * .1, w * .5, 0);
    p.cubicTo(w * .85, h * .1, w * 1.05, h * .55, w * .5, h);
    p.close();
    return p;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
