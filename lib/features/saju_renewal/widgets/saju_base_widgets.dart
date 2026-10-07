import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/saju_dark_tokens.dart';
import '../utils/saju_motion_prefs.dart';

/// [신통방통 정통사주 리뉴얼 — 다크 핸드오프] 공용 베이스 위젯 모음.
/// `design_handoff_jeongtong_saju_v3/design_files/saju/screens-a.jsx`의
/// `DarkBase`/`StarField`/`SJTopBar`/`.sj-btn-*`을 1:1로 Flutter화.

/// 고정 시드 기반 별 필드(의사난수 — 매 빌드마다 동일한 별 배치).
class SajuStarField extends StatefulWidget {
  const SajuStarField({
    super.key,
    this.count = 40,
    this.seed = 3,
    this.opacity = 1,
  });

  final int count;
  final int seed;
  final double opacity;

  @override
  State<SajuStarField> createState() => _SajuStarFieldState();
}

class _SajuStarFieldState extends State<SajuStarField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_StarSpec> _stars;
  bool _reduceMotionApplied = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();
    _stars = List.generate(widget.count, (i) {
      double r(int n) {
        final v = math.sin((i + 1) * 12.9898 * (n + widget.seed)) * 43758.5453;
        return (v - v.floorToDouble());
      }

      return _StarSpec(
        x: r(1),
        y: r(2),
        size: r(3) * 1.6 + 0.4,
        delay: r(4) * 4,
        period: 3 + r(5) * 4,
      );
    });
  }

  // [E-Reduce Motion — docs/04_모션.md §2 "A-03 별 필드 opacity .25↔1" /
  // §5 "A-01~A-07 정지(정지 프레임 = 각 루프의 0% 상태)"] 기존에는
  // disableAnimations를 전혀 조회하지 않아 별 반짝임이 항상 돌았다.
  // Reduce Motion이면 컨트롤러를 0(= 각 루프의 0% 상태)에 고정한다.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = sajuReduceMotion(context);
    if (reduce && !_reduceMotionApplied) {
      _reduceMotionApplied = true;
      _controller.stop();
      _controller.value = 0;
    } else if (!reduce && _reduceMotionApplied) {
      _reduceMotionApplied = false;
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
    // [E-Semantics — docs/08_QA_체크리스트.md "장식(Bagua·별·장면
    // 오브제)은 접근성 트리에서 숨김"] 순수 장식 요소이므로 스크린
    // 리더 트리에서 완전히 제외한다.
    return ExcludeSemantics(
      child: IgnorePointer(
        child: Opacity(
          opacity: widget.opacity,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                size: Size.infinite,
                painter: _StarFieldPainter(_stars, _controller.value),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StarSpec {
  _StarSpec({
    required this.x,
    required this.y,
    required this.size,
    required this.delay,
    required this.period,
  });
  final double x, y, size, delay, period;
}

class _StarFieldPainter extends CustomPainter {
  _StarFieldPainter(this.stars, this.t);
  final List<_StarSpec> stars;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = SajuGold.g100;
    for (final s in stars) {
      // twinkle: opacity .25<->1 over `period` seconds, offset by delay.
      final elapsedSeconds = (t * 7) + s.delay;
      final phase = (elapsedSeconds % s.period) / s.period;
      final twinkle = 0.25 + 0.75 * (0.5 - 0.5 * math.cos(phase * 2 * math.pi));
      paint.color = SajuGold.g100.withValues(alpha: twinkle.clamp(0.0, 1.0));
      canvas.drawCircle(
        Offset(s.x * size.width, s.y * size.height),
        s.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StarFieldPainter oldDelegate) => true;
}

/// 다크 베이스 배경(ink.900 + 보라빛 radial glow + 별 필드).
class SajuDarkBase extends StatelessWidget {
  const SajuDarkBase({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: SajuInk.i900,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.3),
                radius: 0.9,
                colors: [Color(0xBF2A2640), Colors.transparent],
                stops: [0.0, 0.7],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, 1),
                radius: 0.7,
                colors: [Color(0x802A2640), Colors.transparent],
                stops: [0.0, 0.7],
              ),
            ),
          ),
          const SajuStarField(count: 36, seed: 7, opacity: 0.55),
          child,
        ],
      ),
    );
  }
}

/// 공통 상단바 — 좌측 아이콘버튼 / 중앙 모노 타이틀 / 우측 슬롯.
class SajuTopBar extends StatelessWidget {
  const SajuTopBar({super.key, this.left, this.right, required this.title});

  final Widget? left;
  final Widget? right;
  final String title;

  @override
  Widget build(BuildContext context) {
    // [E-44pt 대응 — 레이아웃 영향 없이 확장] SajuIconButton의 탭 가능
    // 영역은 44×44로 넓어졌지만 레이아웃 차지 크기는 36×36 그대로다
    // (OverflowBox로 시각적으로만 넘침). 따라서 이 슬롯 폭은 원래
    // 값(36)을 그대로 유지한다 — 44로 바꾸면 좁은 화면(320~375pt)에서
    // 가운데 타이틀의 가용폭이 줄어 "ANALYSIS · 05 / 09" 등이 2줄로
    // 꺾이는 회귀가 재현됨(saju_topbar_wrap_check_test.dart로 실측 확인).
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          SizedBox(width: 36, child: left),
          Expanded(
            child: Center(
              child: Text(
                title,
                style: SajuType.mono10,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          SizedBox(
            width: 36,
            child: Align(alignment: Alignment.centerRight, child: right),
          ),
        ],
      ),
    );
  }
}

/// 원형 아이콘 버튼(sj-icon-btn).
///
/// [버그 수정 — E-44pt(docs/08_QA_체크리스트.md "터치 영역 최소
/// 44pt(아이콘 버튼·용어 링크 포함)")] docs/02_컴포넌트.md §C-01은
/// "Icon 36×36 원"(비주얼 크기)과 "Icon 버튼 히트 영역 44×44"(탭 가능
/// 영역)를 별도로 규정한다. 기존 구현은 `Container(width: 36, height:
/// 36)`에 직접 `InkWell`을 씌워 비주얼과 히트 영역이 완전히 같았다
/// (36×36 — 44pt 미달, 실측 확인된 결함).
///
/// [레이아웃 영향 없이 확장 — docs/02 C-07 "히트 영역: 세로 최소 32pt
/// (레이아웃에 영향 없이 확장)"와 동일한 원칙을 Icon 버튼에도 적용]
/// 바깥 레이아웃 차지 크기는 36×36 그대로 유지하고(= `SajuTopBar`
/// 좌우 36pt 슬롯과 호환, 좁은 화면에서 타이틀이 밀려 줄바꿈되는 회귀
/// 방지), `OverflowBox`로 탭 가능 영역만 44×44로 "시각적으로 넘치게"
/// 넓힌다 — 인접 위젯의 배치/공간 계산에는 전혀 영향을 주지 않는다.
class SajuIconButton extends StatelessWidget {
  const SajuIconButton({super.key, required this.icon, required this.onTap});

  final String icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: OverflowBox(
        minWidth: 44,
        maxWidth: 44,
        minHeight: 44,
        maxHeight: 44,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Center(
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: SajuText.card,
                  border: Border.all(color: SajuText.line),
                ),
                child: Text(
                  icon,
                  style: const TextStyle(color: SajuText.fg, fontSize: 15),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum SajuButtonVariant { primary, secondary, ghost }

/// 공용 버튼(.sj-btn-primary/secondary/ghost). 눌림 시 scale(.96).
class SajuButton extends StatefulWidget {
  const SajuButton({
    super.key,
    required this.label,
    this.onTap,
    this.variant = SajuButtonVariant.primary,
    this.loading = false,
    this.leading,
    this.height = 56,
  });

  final String label;
  final VoidCallback? onTap;
  final SajuButtonVariant variant;
  final bool loading;
  final Widget? leading;
  final double height;

  @override
  State<SajuButton> createState() => _SajuButtonState();
}

class _SajuButtonState extends State<SajuButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null || widget.loading;
    Color bg;
    Color fg;
    Border? border;
    List<BoxShadow>? shadow;
    // B-1(docs/08_QA_체크리스트.md) / docs/01_디자인토큰.md §2-2 `T-cta`
    // ("Gowun Batang 700 16 −0.01em, 모든 CTA") · docs/02_컴포넌트.md
    // C-01(Primary/Secondary 텍스트 = T-cta) · 원본
    // `design_files/saju/saju-tokens.css` `.sj-btn`(font-family:
    // var(--font-body)=Gowun Batang) — Primary/Secondary는 Gowun
    // Batang 700 16을 쓴다. 단, Ghost는 원본
    // `design_files/saju/screens-b.jsx`(↻ 새로운 이야기 버튼)가
    // 인라인으로 `fontFamily: Pretendard, fontWeight: 500, fontSize:
    // 14`를 명시적으로 오버라이드하므로 Ghost만 Pretendard 500 14를
    // 쓴다(docs/02 C-01 Ghost 행: "Pretendard 500 14"와 일치).
    String labelFontFamily;
    FontWeight labelFontWeight;
    double labelFontSize;
    switch (widget.variant) {
      case SajuButtonVariant.primary:
        bg = SajuGold.g100;
        fg = SajuInk.i900;
        shadow = [
          BoxShadow(
            color: SajuGold.glow,
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ];
        labelFontFamily = SajuType.body;
        labelFontWeight = FontWeight.w700;
        labelFontSize = 16;
        break;
      case SajuButtonVariant.secondary:
        bg = SajuText.card;
        fg = SajuText.fg;
        border = Border.all(color: SajuText.lineGold);
        labelFontFamily = SajuType.body;
        labelFontWeight = FontWeight.w700;
        labelFontSize = 16;
        break;
      case SajuButtonVariant.ghost:
        bg = Colors.transparent;
        fg = SajuText.muted;
        border = Border.all(color: SajuText.line);
        labelFontFamily = SajuType.ui;
        labelFontWeight = FontWeight.w500;
        labelFontSize = 14;
        break;
    }
    return Opacity(
      opacity: disabled && widget.variant != SajuButtonVariant.primary
          ? 0.6
          : 1,
      child: GestureDetector(
        onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: disabled ? null : widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1,
          duration: SajuMotion.press,
          child: AnimatedContainer(
            duration: SajuMotion.press,
            width: double.infinity,
            height: widget.height,
            decoration: BoxDecoration(
              color: disabled && widget.variant == SajuButtonVariant.primary
                  ? bg.withValues(alpha: 0.5)
                  : bg,
              borderRadius: BorderRadius.circular(14),
              border: border,
              boxShadow: shadow,
            ),
            alignment: Alignment.center,
            child: widget.loading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: fg,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.leading != null) ...[
                        widget.leading!,
                        const SizedBox(width: 10),
                      ],
                      Text(
                        widget.label,
                        style: TextStyle(
                          fontFamily: labelFontFamily,
                          fontWeight: labelFontWeight,
                          fontSize: labelFontSize,
                          letterSpacing:
                              widget.variant == SajuButtonVariant.ghost
                              ? 0
                              : -0.16, // T-cta 자간 −0.01em(16px 기준)
                          color: fg,
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
