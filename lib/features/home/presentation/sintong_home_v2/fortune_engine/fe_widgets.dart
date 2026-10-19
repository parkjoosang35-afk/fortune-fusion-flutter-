// ═══════════════════════════════════════════════════════════════
// FILE: fe_widgets.dart
// [운세 엔진 디자인 핸드오프] 공용 모티프 위젯.
// 출처: uploaded_files/fortune_engine_extracted/flutter/lib/widgets/sintong_widgets.dart
// (README.md 명시 레퍼런스 구현) + sigils.jsx(Dust) 포팅.
// Sigil(마법진) · Seal(도장) · SectionHead · GlowCard · Reveal(스크롤
// 진입) · StarField · StatusBadge · PrimaryButton · Dust(먼지입자) ·
// Marquee(무한스크롤 띠).
//
// [네이밍] 기존 앱에 이미 존재하는 동명 위젯과 충돌하지 않도록 전부
// `Fe` 접두사를 사용한다 — 이 파일 밖 어떤 화면도 참조하지 않는다.
// ═══════════════════════════════════════════════════════════════
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'fe_tokens.dart';

/// 마법진 — sigils.jsx <Sigil> 포팅. viewBox -100..100 기준.
class FeSigilPainter extends CustomPainter {
  final Color color;
  final double opacity;
  FeSigilPainter({this.color = FeColors.glow, this.opacity = 0.5});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 200;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(s);
    Paint st(double a, double w) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..color = color.withValues(alpha: (opacity * a).clamp(0, 1));
    canvas.drawCircle(
      Offset.zero,
      95,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: 95)),
    );
    canvas.drawCircle(Offset.zero, 90, st(1, .6));
    canvas.drawCircle(Offset.zero, 86, st(.5, .4));
    for (var i = 0; i < 36; i++) {
      final a = i / 36 * math.pi * 2;
      canvas.drawLine(
        Offset(math.cos(a) * 86, math.sin(a) * 86),
        Offset(math.cos(a) * 90, math.sin(a) * 90),
        st(.8, .5),
      );
    }
    const runes = ['✧', '✦', '☾', '❋', '◈', '✵', '❈', '✺', '✶', '☆', '◇', '⟡'];
    for (var i = 0; i < 12; i++) {
      final a = i / 12 * math.pi * 2 - math.pi / 2;
      final tp = TextPainter(
        text: TextSpan(
          text: runes[i],
          style: TextStyle(
            fontSize: 6,
            color: color.withValues(alpha: opacity),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(
          math.cos(a) * 78 - tp.width / 2,
          math.sin(a) * 78 - tp.height / 2,
        ),
      );
    }
    canvas.drawCircle(Offset.zero, 60, st(.6, .5));
    Path poly(List<List<double>> p) =>
        Path()..addPolygon(p.map((e) => Offset(e[0], e[1])).toList(), true);
    canvas.drawPath(
      poly([
        [0, -52],
        [45, -26],
        [45, 26],
        [0, 52],
        [-45, 26],
        [-45, -26],
      ]),
      st(.8, .6),
    );
    canvas.drawPath(
      poly([
        [0, 52],
        [-45, -26],
        [45, -26],
      ]),
      st(.5, .5),
    );
    canvas.drawPath(
      poly([
        [0, -52],
        [-45, 26],
        [45, 26],
      ]),
      st(.5, .5),
    );
    canvas.drawCircle(Offset.zero, 26, st(1, .6));
    canvas.drawCircle(Offset.zero, 22, st(.5, .4));
    canvas.drawPath(
      poly([
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
      ]),
      Paint()..color = color.withValues(alpha: opacity * .6),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant FeSigilPainter o) =>
      o.color != color || o.opacity != opacity;
}

/// 회전하는 마법진 (기본 120초/1회전, reverse 지원)
class FeSigil extends StatefulWidget {
  final double size;
  final Color color;
  final double opacity;
  final Duration period;
  final bool reverse;
  const FeSigil({
    super.key,
    this.size = 300,
    this.color = FeColors.glow,
    this.opacity = .5,
    this.period = FeMotion.sigilSlow,
    this.reverse = false,
  });
  @override
  State<FeSigil> createState() => _FeSigilState();
}

class _FeSigilState extends State<FeSigil> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.period,
  )..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RotationTransition(
    turns: widget.reverse ? ReverseAnimation(_c) : _c,
    child: CustomPaint(
      size: Size.square(widget.size),
      painter: FeSigilPainter(color: widget.color, opacity: widget.opacity),
    ),
  );
}

/// 붉은 한자 도장 (-6° 회전)
class FeSeal extends StatelessWidget {
  final String text;
  final double size;
  final Color color;
  const FeSeal(
    this.text, {
    super.key,
    this.size = 44,
    this.color = FeColors.accent,
  });
  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: -6 * math.pi / 180,
    child: Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(FeRadius.seal),
        border: Border.all(color: Colors.black.withValues(alpha: .15)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: .53),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: FeFonts.display,
          fontWeight: FontWeight.w900,
          fontSize: size * .55,
          color: FeColors.sealText,
        ),
      ),
    ),
  );
}

/// 섹션 헤더: [한자 금박 태그] MONO 라벨 / 타이틀 / 서브카피
class FeSectionHead extends StatelessWidget {
  final String hanja, mono;
  final Widget title;
  final String? sub;
  const FeSectionHead({
    super.key,
    required this.hanja,
    required this.mono,
    required this.title,
    this.sub,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Transform.rotate(
              angle: -4 * math.pi / 180,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                decoration: BoxDecoration(
                  color: FeColors.glow,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: FeShadow.glow(FeColors.glow, blur: 14),
                ),
                child: Text(
                  hanja,
                  style: const TextStyle(
                    fontFamily: FeFonts.display,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: FeColors.ink,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                mono.toUpperCase(),
                style: FeText.mono,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DefaultTextStyle(style: FeText.sectionTitle, child: title),
        if (sub != null) ...[
          const SizedBox(height: 8),
          Text(sub!, style: FeText.bodyMuted),
        ],
      ],
    ),
  );
}

/// 카드 (기본) / altar=true 이면 상단 금빛 radial glow
class FeGlowCard extends StatelessWidget {
  final Widget child;
  final bool altar;
  final EdgeInsets padding;
  final Color? borderColor;
  const FeGlowCard({
    super.key,
    required this.child,
    this.altar = false,
    this.padding = const EdgeInsets.all(16),
    this.borderColor,
  });
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(FeRadius.altar),
    child: Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: FeColors.card,
              borderRadius: BorderRadius.circular(FeRadius.altar),
              border: Border.all(color: borderColor ?? FeColors.line),
            ),
          ),
        ),
        if (altar)
          Positioned(
            left: 0,
            right: 0,
            top: -40,
            height: 80,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      FeColors.glowShadow,
                      FeColors.glowShadow.withValues(alpha: 0),
                    ],
                    stops: const [0, .7],
                  ),
                ),
              ),
            ),
          ),
        Padding(padding: padding, child: child),
      ],
    ),
  );
}

/// 스크롤 진입 시 fade + 상승 (1회만)
class FeReveal extends StatefulWidget {
  final Widget child;
  final Duration delay;
  const FeReveal({super.key, required this.child, this.delay = Duration.zero});
  @override
  State<FeReveal> createState() => _FeRevealState();
}

class _FeRevealState extends State<FeReveal> {
  bool _in = false;
  final _k = UniqueKey();
  @override
  Widget build(BuildContext context) => VisibilityDetector(
    key: _k,
    onVisibilityChanged: (i) {
      if (!_in && i.visibleFraction > .1) {
        Future.delayed(widget.delay, () {
          if (mounted) setState(() => _in = true);
        });
      }
    },
    child: AnimatedSlide(
      offset: _in ? Offset.zero : const Offset(0, .04),
      duration: FeMotion.reveal,
      curve: FeMotion.revealCurve,
      child: AnimatedOpacity(
        opacity: _in ? 1 : 0,
        duration: FeMotion.reveal,
        child: widget.child,
      ),
    ),
  );
}

/// 별 가루 배경 (고정 좌표 11개, 1400px 반복)
class FeStarField extends StatelessWidget {
  const FeStarField({super.key});
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(painter: _FeStarPainter(), size: Size.infinite),
  );
}

class _FeStarPainter extends CustomPainter {
  static const pts = [
    [.12, .08, 1.0],
    [.78, .04, 1.0],
    [.44, .14, 1.5],
    [.90, .22, 1.0],
    [.22, .31, 1.0],
    [.66, .38, 1.0],
    [.08, .52, 1.5],
    [.85, .60, 1.0],
    [.35, .70, 1.0],
    [.72, .82, 1.0],
    [.15, .92, 1.0],
  ];
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()..color = Colors.white.withValues(alpha: .55);
    for (var y0 = 0.0; y0 < s.height; y0 += 1400) {
      for (final q in pts) {
        c.drawCircle(Offset(q[0] * s.width, y0 + q[1] * 1400), q[2] / 2, p);
      }
    }
  }

  @override
  bool shouldRepaint(_FeStarPainter old) => false;
}

/// 3개의 radial wash 오버레이 — engine.css .page 배경 그라디언트 재현.
class FeRadialWashes extends StatelessWidget {
  const FeRadialWashes({super.key});
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-1, -1),
                radius: 1.2,
                colors: [
                  const Color(0xFF5A3CAA).withValues(alpha: 0.35),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(1, -0.1),
                radius: 1.0,
                colors: [
                  FeColors.glow.withValues(alpha: 0.10),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-1, 0.6),
                radius: 1.0,
                colors: [
                  FeColors.crystal.withValues(alpha: 0.10),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// 상태 배지 (일치/보완/긴장/단일 관찰)
class FeStatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const FeStatusBadge(this.label, this.color, {super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontFamily: FeFonts.ui,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    ),
  );
}

/// 금색 Primary 버튼 (높이 44, radius 14, 눌림 96%)
class FePrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const FePrimaryButton(this.label, {super.key, required this.onTap});
  @override
  State<FePrimaryButton> createState() => _FePrimaryButtonState();
}

class _FePrimaryButtonState extends State<FePrimaryButton> {
  bool _d = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => setState(() => _d = true),
    onTapCancel: () => setState(() => _d = false),
    onTapUp: (_) {
      setState(() => _d = false);
      widget.onTap();
    },
    child: AnimatedScale(
      scale: _d ? .96 : 1,
      duration: const Duration(milliseconds: 120),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: FeColors.glow,
          borderRadius: BorderRadius.circular(FeRadius.button),
          boxShadow: FeShadow.primaryButton,
        ),
        child: Text(
          widget.label,
          style: const TextStyle(
            fontFamily: FeFonts.body,
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: FeColors.ink,
          ),
        ),
      ),
    ),
  );
}

/// 먼지 입자 (상승 파티클) — Hero/Closing 배경 장식. sigils.jsx <Dust> 포팅.
class FeDust extends StatefulWidget {
  final int count;
  final Color color;
  const FeDust({super.key, this.count = 10, this.color = FeColors.glow});
  @override
  State<FeDust> createState() => _FeDustState();
}

class _FeDustState extends State<FeDust> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  )..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Stack(
          children: List.generate(widget.count, (i) {
            final leftPct = (i * 13 + 7) % 100 / 100.0;
            final delay = (i * 0.7) % 8 / 8.0;
            final dur = (6 + (i % 4)) / 8.0;
            final size = (2 + (i % 3)).toDouble();
            var t = (_c.value - delay) / dur;
            t = t - t.floorToDouble();
            if (t < 0) t += 1;
            final opacity = t < 0.2
                ? (t / 0.2)
                : (1 - (t - 0.2) / 0.8).clamp(0.0, 1.0);
            return Positioned(
              left: leftPct * 300,
              bottom: t * 260 - 10,
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0) * 0.9,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [widget.color, widget.color.withValues(alpha: 0)],
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    ),
  );
}

/// 상단 흘러가는 문구 띠 (무한 가로 스크롤)
class FeMarquee extends StatefulWidget {
  final List<String> items;
  const FeMarquee({super.key, required this.items});
  @override
  State<FeMarquee> createState() => _FeMarqueeState();
}

class _FeMarqueeState extends State<FeMarquee>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: FeMotion.marquee,
  )..repeat();

  Widget _row() => Row(
    mainAxisSize: MainAxisSize.min,
    children: widget.items
        .map(
          (t) => Padding(
            padding: const EdgeInsets.only(left: 18),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t,
                  style: const TextStyle(
                    fontFamily: FeFonts.body,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: FeColors.glow,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 18),
                  child: Text(
                    '✦',
                    style: TextStyle(color: FeColors.glow, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        )
        .toList(),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        color: FeColors.glow.withValues(alpha: 0.06),
        border: Border(
          top: BorderSide(color: FeColors.glow.withValues(alpha: 0.25)),
          bottom: BorderSide(color: FeColors.glow.withValues(alpha: 0.25)),
        ),
      ),
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            return OverflowBox(
              maxWidth: double.infinity,
              alignment: Alignment.centerLeft,
              child: Transform.translate(
                offset: Offset(-_c.value * 800, 0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [_row(), _row(), _row()],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 한지 두루마리 (해설 섹션 전용) — sigils.jsx <Scroll> 포팅.
class FeScroll extends StatelessWidget {
  final Widget child;
  final EdgeInsets margin;
  const FeScroll({
    super.key,
    required this.child,
    this.margin = EdgeInsets.zero,
  });
  @override
  Widget build(BuildContext context) => Container(
    margin: margin,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: -6,
          left: -8,
          right: -8,
          height: 12,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [FeColors.scrollBarLight, FeColors.scrollBarDark],
              ),
              borderRadius: BorderRadius.circular(6),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x4D000000),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [FeColors.scrollTop, FeColors.scrollBottom],
            ),
            borderRadius: BorderRadius.circular(4),
            boxShadow: const [
              BoxShadow(
                color: Color(0x4D000000),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: DefaultTextStyle(
            style: const TextStyle(
              fontFamily: FeFonts.body,
              color: FeColors.scrollInk,
            ),
            child: child,
          ),
        ),
        Positioned(
          bottom: -6,
          left: -8,
          right: -8,
          height: 12,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [FeColors.scrollBarDark, FeColors.scrollBarLight],
              ),
              borderRadius: BorderRadius.circular(6),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x4D000000),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
