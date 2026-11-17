import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/guinji_map_theme.dart';

/// [2026 디자인 핸드오프] `/guinji-map/*` 전체 화면 공용 위젯 모음.
/// 핸드오프 최종(v2) 검정(#0B0B0D) 테마에 맞춰 전면 재작성했다. 위젯
/// 클래스 이름/생성자 파라미터(API)는 기존과 동일하게 유지해, 이 파일을
/// import하는 모든 화면이 수정 없이 새 테마 색을 그대로 받도록 한다.

/// ─────────────────────────────────────────────────────────────
/// 상단 바 — 검정 배경 + 흐린 하단 선.
/// ─────────────────────────────────────────────────────────────
class GmTopBar extends StatelessWidget implements PreferredSizeWidget {
  const GmTopBar({
    super.key,
    this.back = false,
    this.title,
    this.meta,
    this.onShare,
    this.onBack,
    this.trailing,
  });

  final bool back;
  final String? title;

  /// [SPEC §6 H2 "상단바 (← · 제목 · `STEP 1/1`)"] 제목 오른쪽에 붙는
  /// 짧은 보조 라벨(예: `STEP 1/1`). 지정하지 않으면 기존 화면과 동일하게
  /// 중앙 제목만 그린다 — 호출부 20여 곳은 하위 호환.
  final String? meta;
  final VoidCallback? onShare;
  final VoidCallback? onBack;

  /// [귀인지도 핸드오프 v4 — A12 초대 시트 "⋯" 링크 관리] 우측 슬롯에
  /// 공유 아이콘([onShare]) 대신 임의의 액션(예: 더보기 "⋯" 버튼)을
  /// 넣고 싶은 화면을 위한 범용 오버라이드. 지정하면 [onShare] 기반
  /// 기본 아이콘 대신 이 위젯을 그린다 — 기존 호출부(6곳, 전부 이
  /// 파라미터를 넘기지 않음)는 동작 변화가 전혀 없다(하위 호환).
  final Widget? trailing;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: GmColors.bg.withValues(alpha: 0.92),
        border: const Border(bottom: BorderSide(color: GmColors.hair)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: back
                ? IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.arrow_back,
                      color: GmColors.fg,
                      size: 20,
                    ),
                    onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [GmColors.goldTop, GmColors.gold],
                          ),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          '신',
                          style: TextStyle(
                            color: GmColors.onFg,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            height: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        '신통방통',
                        style: TextStyle(
                          fontFamily: GmText.display,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: GmColors.fg,
                        ),
                      ),
                    ],
                  ),
          ),
          Expanded(
            child: Center(
              child: meta == null
                  ? Text(
                      title ?? '',
                      style: const TextStyle(
                        fontFamily: GmText.display,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: GmColors.fg,
                      ),
                      overflow: TextOverflow.ellipsis,
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            title ?? '',
                            style: const TextStyle(
                              fontFamily: GmText.display,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: GmColors.fg,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          meta!,
                          style: const TextStyle(
                            fontFamily: GmText.mono,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.6,
                            color: GmColors.muted,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          SizedBox(
            width: 40,
            child:
                trailing ??
                (onShare != null
                    ? IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          Icons.ios_share,
                          color: GmColors.fg,
                          size: 18,
                        ),
                        onPressed: onShare,
                      )
                    : null),
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────
/// 금색 chip — `ChipPill`/`LabelMini`.
/// ─────────────────────────────────────────────────────────────
class GmChip extends StatelessWidget {
  const GmChip({
    super.key,
    required this.label,
    this.background,
    this.foreground,
    this.borderColor,
    this.leading,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    this.fontSize = 12,
  });

  final String label;
  final Color? background;
  final Color? foreground;
  final Color? borderColor;
  final Widget? leading;
  final EdgeInsets padding;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: background ?? GmColors.card,
        border: Border.all(color: borderColor ?? GmColors.line),
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 4)],
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              color: foreground ?? GmColors.muted,
              height: 1.2,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class GmLabelMini extends StatelessWidget {
  const GmLabelMini(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 10,
        height: 1,
        letterSpacing: 1.2,
        color: color ?? GmColors.gold,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class GmDot extends StatelessWidget {
  const GmDot({super.key, this.color = GmColors.gold, this.size = 6});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// ─────────────────────────────────────────────────────────────
/// [2026-12 보강 — SPEC §2 `bgGlow` 전역 배경] "심야의 신전" 공통 배경.
///
/// `design_files/guinji-temple.jsx`의 `TpBg()` 함수(63~71줄)를 1:1 이식한
/// 것이다. 원본은 H2(`TpInput`)·H4(`TpMain`, 2회)뿐 아니라 `guinji-guest.jsx`
/// 의 `GsShell`(G1·W1·G2·W2·W3 공유 셸)·`guinji-loop.jsx`의 `LpGift`(G3)에서도
/// 똑같이 쓰이는 **전 화면 공통 배경 컴포넌트**다 — H1(자체 시네마틱
/// 배경)과 H7/H8(의도적으로 다른 단색 `DK.bg`)만 예외다.
///
/// SPEC §2 `bgGlow` 토큰 그대로:
///   ① 타원 90%×45% at 12% 0%:  rgba(140,80,200,.30)
///   ② 타원 70%×40% at 100% 70%: rgba(201,74,59,.13)
///   ③ 타원 60%×30% at 50% 100%: rgba(245,207,106,.08)
/// 위에 `bgTop→bgBottom` 기본 그라데이션, 그리고 §2 `stars`(1~1.6px 흰 점
/// 44개, 불투명도 .55, 2~6s 반짝임 — jsx `tp-tw` keyframe)를 겹친다.
///
/// 이 화면들은 지금까지 [GmColors.bgGradient](2색 선형)만 쓰고 있었다 —
/// 이 위젯으로 교체하면 글로우·별이 추가로 한 번에 적용된다. 교체 전
/// `Container(decoration: BoxDecoration(gradient: GmColors.bgGradient))`와
/// 레이아웃 계약(화면을 꽉 채우는 배경 1장)이 동일하므로 drop-in 교체가
/// 가능하다.
class GmTempleBg extends StatefulWidget {
  const GmTempleBg({super.key, this.child});

  /// 배경 위에 얹을 실제 화면 내용(선택) — 지정하지 않으면 배경 레이어만
  /// 그리고, 호출부가 `Stack`으로 직접 내용을 겹치는 용도로 쓸 수 있다.
  final Widget? child;

  @override
  State<GmTempleBg> createState() => _GmTempleBgState();
}

class _GmTempleBgState extends State<GmTempleBg>
    with SingleTickerProviderStateMixin {
  // jsx: `Array.from({length:44},(_,i)=>({x:(i*37+11)%100, y:(i*61+7)%100,
  // r: i%6===0?1.6:1, t: 2+(i%5)*.8}))` — 44개 별의 결정적 배치를 그대로
  // 재현한다(화면마다 동일한 별자리가 보여야 하므로 랜덤이 아니라 i 기반
  // 해시 공식을 그대로 옮긴다).
  static final List<_TpStarSpec> _stars = List.generate(44, (i) {
    return _TpStarSpec(
      x: (i * 37 + 11) % 100 / 100,
      y: (i * 61 + 7) % 100 / 100,
      r: i % 6 == 0 ? 1.6 : 1.0,
      period: Duration(milliseconds: ((2 + (i % 5) * 0.8) * 1000).round()),
      delayFraction: (i * .17) / (2 + (i % 5) * 0.8),
    );
  });

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // 개별 별마다 주기가 다르므로(2~4.2s), 공통 긴 주기 컨트롤러 하나를
    // 0→1로 무한 반복시키고 각 별이 자기 주기·지연을 적용해 위상을
    // 계산한다(`guinji_animated_graph.dart`의 `elapsedSeconds` 패턴과 동일).
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Stack(
      fit: StackFit.expand,
      children: [
        // 기본 그라데이션 + ①②③ 라디얼 글로우 3겹(정적 — 시간에 따라
        // 변하지 않으므로 애니메이션 리빌드 비용과 무관).
        const DecoratedBox(
          decoration: BoxDecoration(gradient: GmColors.bgGradient),
        ),
        Positioned.fill(child: CustomPaint(painter: _TempleGlowPainter())),
        // 별 44개 — "동작 줄이기"가 켜져 있으면 반짝임 없이 고정 밝기로.
        Positioned.fill(
          child: IgnorePointer(
            child: reduceMotion
                ? CustomPaint(painter: _TempleStarsPainter(phase: 0))
                : AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      return CustomPaint(
                        painter: _TempleStarsPainter(
                          phase: _controller.value * 60,
                        ),
                      );
                    },
                  ),
          ),
        ),
        if (widget.child != null) widget.child!,
      ],
    );
  }
}

class _TpStarSpec {
  const _TpStarSpec({
    required this.x,
    required this.y,
    required this.r,
    required this.period,
    required this.delayFraction,
  });

  final double x; // 0~1
  final double y; // 0~1
  final double r;
  final Duration period;

  /// 60초 공통 주기 기준 지연 비율(초 단위 delay를 별도 period로 정규화해
  /// 둔 값 — 실제 위상 계산은 Painter에서 `elapsedSeconds`로 수행).
  final double delayFraction;
}

/// SPEC §2 `bgGlow` 3겹 라디얼 — `RadialGradient`의 `center`/`radius`는
/// CSS `radial-gradient(ellipse W% H% at X% Y%, ...)`를 타원 비율 그대로
/// 옮기기 번거로워, `Rect`를 타원 크기로 직접 그려 1:1 재현한다.
class _TempleGlowPainter extends CustomPainter {
  const _TempleGlowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    void drawGlow(
      double cxFrac,
      double cyFrac,
      double wFrac,
      double hFrac,
      Color color,
    ) {
      final center = Offset(size.width * cxFrac, size.height * cyFrac);
      final radius = Offset(size.width * wFrac / 2, size.height * hFrac / 2);
      final rect = Rect.fromCenter(
        center: center,
        width: radius.dx * 2,
        height: radius.dy * 2,
      );
      final paint = Paint()..shader = templeGlowShader(rect, color);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.scale(1, radius.dy / (radius.dx == 0 ? 1 : radius.dx));
      canvas.translate(-center.dx, -center.dy);
      canvas.drawCircle(center, radius.dx, paint);
      canvas.restore();
    }

    // ① 타원 90%×45% at 12% 0%: rgba(140,80,200,.30)
    drawGlow(0.12, 0.0, 0.9, 0.45, const Color(0x4D8C50C8));
    // ② 타원 70%×40% at 100% 70%: rgba(201,74,59,.13)
    drawGlow(1.0, 0.7, 0.7, 0.4, const Color(0x21C94A3B));
    // ③ 타원 60%×30% at 50% 100%: rgba(245,207,106,.08)
    drawGlow(0.5, 1.0, 0.6, 0.3, const Color(0x14F5CF6A));
  }

  @override
  bool shouldRepaint(covariant _TempleGlowPainter oldDelegate) => false;
}

/// [dart:ui] `Gradient.radial`의 중심/반지름을 받아 중심 색 → 투명 쉐이더를
/// 만드는 짧은 헬퍼(파일 내부 전용 — `RadialGradient`(painting.dart)가 아닌
/// `dart:ui`의 저수준 `Gradient.radial` 팩토리를 직접 써야 타원 스케일
/// 변환(`canvas.scale`)과 함께 써도 반지름이 뒤틀리지 않는다).
Shader templeGlowShader(Rect rect, Color color) {
  return ui.Gradient.radial(
    rect.center,
    rect.width / 2,
    [color, color.withValues(alpha: 0)],
    const [0.0, 1.0],
  );
}

/// SPEC §2 `stars` — 1~1.6px 흰 점 44개, 불투명도 .55, 2~6s 반짝임.
/// jsx `@keyframes tp-tw { 0%,100%{opacity:.25} 50%{opacity:1} }`를
/// `sin` 곡선으로 근사한다(0.25~1 범위 — 최종 표시 불투명도는 여기에
/// 베이스 .55를 곱해 CSS와 동일한 체감 밝기를 낸다).
class _TempleStarsPainter extends CustomPainter {
  const _TempleStarsPainter({required this.phase});

  /// 공통 60초 컨트롤러의 `value * 60`(초 단위 경과시간, 0→60 반복).
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in _GmTempleBgState._stars) {
      final periodSec = s.period.inMilliseconds / 1000;
      final delaySec = s.delayFraction * periodSec;
      final t = ((phase - delaySec) % periodSec) / periodSec;
      // 0→1→0 삼각파를 0.25~1 범위로 매핑(= CSS keyframe 0%/50%/100%).
      final wave = (math.sin(t * math.pi * 2 - math.pi / 2) + 1) / 2;
      final twinkle = 0.25 + wave * 0.75;
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: 0.55 * twinkle);
      canvas.drawCircle(
        Offset(s.x * size.width, s.y * size.height),
        s.r,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TempleStarsPainter oldDelegate) =>
      oldDelegate.phase != phase;
}

/// ─────────────────────────────────────────────────────────────
/// 은은한 별 배경 — 금색/골드톱 2색 혼합 점.
/// ─────────────────────────────────────────────────────────────
class GmStarsBackground extends StatelessWidget {
  const GmStarsBackground({super.key, this.opacity = 0.7});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: CustomPaint(painter: _GmStarsPainter(), size: Size.infinite),
    );
  }
}

class _GmStarsPainter extends CustomPainter {
  static final _rand = math.Random(42);
  static final _dots = List.generate(24, (i) {
    return _GmDotSpec(
      dx: _rand.nextDouble(),
      dy: _rand.nextDouble(),
      r: 0.7 + _rand.nextDouble() * 0.9,
      color: i.isEven ? GmColors.gold : GmColors.goldTop,
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final d in _dots) {
      final p = Paint()..color = d.color.withValues(alpha: 0.55);
      canvas.drawCircle(Offset(d.dx * size.width, d.dy * size.height), d.r, p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GmDotSpec {
  const _GmDotSpec({
    required this.dx,
    required this.dy,
    required this.r,
    required this.color,
  });

  final double dx, dy, r;
  final Color color;
}

/// ─────────────────────────────────────────────────────────────
/// 다크 그라디언트 CTA 카드(별배경 포함) — 업셀 / 핸드오프 류 공용 셸.
/// ─────────────────────────────────────────────────────────────
class GmDarkCtaShell extends StatelessWidget {
  const GmDarkCtaShell({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [GmColors.card, GmColors.bg],
              ),
            ),
            padding: padding,
            width: double.infinity,
            child: child,
          ),
          const Positioned.fill(
            child: IgnorePointer(child: GmStarsBackground(opacity: 0.4)),
          ),
        ],
      ),
    );
  }
}

class GmFreeBadge extends StatelessWidget {
  const GmFreeBadge({super.key, this.label = '100% 무료'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: GmColors.gold.withValues(alpha: 0.2),
        border: Border.all(color: GmColors.gold.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.circle, size: 4, color: GmColors.gold),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: GmColors.gold,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────
/// 입력 필드(라벨 + 컨테이너) — 02 정보입력 화면에서 사용.
/// ─────────────────────────────────────────────────────────────
class GmFieldLabel extends StatelessWidget {
  const GmFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: GmColors.muted,
    ),
  );
}

class GmFieldShell extends StatelessWidget {
  const GmFieldShell({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: GmColors.card,
        border: Border.all(color: GmColors.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

/// [2026 디자인 핸드오프 v5 — SPEC.md §2] 모든 주요 CTA(Primary 버튼)는
/// 카카오 노랑(#FEE500) 단색 하나만 사용한다. 기존 흰색 배경은
/// QA_CHECKLIST.md §1 "흰색 버튼 0곳" 요구에 따라 폐기했다.
class GmPrimaryButton extends StatelessWidget {
  const GmPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: GmColors.primary,
          foregroundColor: GmColors.onPrimary,
          disabledBackgroundColor: GmColors.disabledBg,
          disabledForegroundColor: GmColors.dim,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GmRadius.button),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: GmColors.onPrimary,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontFamily: GmText.ui,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

/// [2026 디자인 핸드오프 v5 — SPEC.md §2] 기존 "금 그라데이션" 보조 CTA도
/// QA_CHECKLIST.md §1 "로즈골드 · 금색 버튼 0곳" 요구에 따라 Primary와
/// 동일한 카카오 노랑 단색으로 통일한다(위젯 이름은 호출부 20여 곳 호환을
/// 위해 유지, 시각적으로는 [GmPrimaryButton]과 동일해짐).
class GmRoseButton extends StatelessWidget {
  const GmRoseButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: GmColors.primary,
          borderRadius: BorderRadius.circular(GmRadius.button),
        ),
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            foregroundColor: GmColors.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(GmRadius.button),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontFamily: GmText.ui,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: GmColors.onPrimary,
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 6),
                Icon(icon, size: 16, color: GmColors.onPrimary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// [SPEC §6 H2 "약관 박스"] 전체 동의 + 개별 항목(필수/선택) 공용 체크
/// 행. 선택 시 금색 원 + 체크 아이콘, 미선택 시 `line` 테두리만. `보기`
/// 링크는 [onViewDetail]이 있을 때만 그린다.
class GmAgreeRow extends StatelessWidget {
  const GmAgreeRow({
    super.key,
    required this.checked,
    required this.label,
    required this.onChanged,
    this.badge,
    this.emphasize = false,
    this.onViewDetail,
  });

  final bool checked;
  final String label;
  final ValueChanged<bool> onChanged;

  /// `[필수]` / `[선택]` 배지 텍스트(없으면 표시하지 않음 — 전체 동의 행용).
  final String? badge;
  final bool emphasize;
  final VoidCallback? onViewDetail;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!checked),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: checked ? GmColors.gold : Colors.transparent,
                border: Border.all(
                  color: checked ? GmColors.gold : GmColors.line,
                  width: 1.4,
                ),
              ),
              child: checked
                  ? const Icon(Icons.check, size: 13, color: GmColors.onFg)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: RichText(
                text: TextSpan(
                  children: [
                    if (badge != null)
                      TextSpan(
                        text: '$badge ',
                        style: TextStyle(
                          fontFamily: GmText.ui,
                          fontSize: emphasize ? 13 : 12,
                          fontWeight: FontWeight.w700,
                          color: badge == '[필수]'
                              ? GmColors.gold
                              : GmColors.muted,
                        ),
                      ),
                    TextSpan(
                      text: label,
                      style: TextStyle(
                        fontFamily: GmText.ui,
                        fontSize: emphasize ? 13.5 : 12,
                        fontWeight: emphasize
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: GmColors.fg,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (onViewDetail != null)
              GestureDetector(
                onTap: onViewDetail,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Text(
                    '보기',
                    style: TextStyle(
                      fontFamily: GmText.ui,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: GmColors.muted,
                      decoration: TextDecoration.underline,
                      decorationColor: GmColors.muted,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────
/// [QA_CHECKLIST.md §1 전역 7 "바텀시트 공통 스타일(딤+블러6)"] 공용
/// 바텀시트 딤+블러 래퍼.
///
/// `showModalBottomSheet`의 `barrierColor`는 단색만 지원하고 블러는
/// 직접 지원하지 않는다. SPEC §2 바텀시트 토큰("딤 `rgba(6,3,14,.68)` +
/// blur 6")을 충족하려면 barrier 뒤의 화면(지도/리스트 등)에 블러를
/// 추가로 입혀야 한다 — 이 함수는 `builder`가 반환하는 시트 위젯을
/// 풀스크린 `Stack`으로 감싸고, 그 밑에 `BackdropFilter(blur 6)` 레이어를
/// 깔아 해결한다. 블러 레이어는 `IgnorePointer`로 감싸 탭 이벤트가 그대로
/// 프레임워크의 `ModalBarrier`(바깥 탭 시 닫기)로 전달되게 한다 — 기존
/// 바깥 탭 닫기 동작은 그대로 유지된다.
///
/// 기존 `showModalBottomSheet(... barrierColor: const Color(0xAD06030E))`
/// 호출부를 이 함수로 교체하면 된다. [절대 원칙] 반환 타입·파라미터
/// 이름은 `showModalBottomSheet`와 최대한 동일하게 유지해 교체 시 호출부
/// 수정을 최소화한다.
Future<T?> showGmBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color barrierColor = const Color(0xAD06030E),
  double blurSigma = 6,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: barrierColor,
    builder: (sheetContext) => Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        builder(sheetContext),
      ],
    ),
  );
}
