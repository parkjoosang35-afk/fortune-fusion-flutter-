import 'dart:math' as math;

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
    this.onShare,
    this.onBack,
  });

  final bool back;
  final String? title;
  final VoidCallback? onShare;
  final VoidCallback? onBack;

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
                          fontWeight: FontWeight.w700,
                          color: GmColors.fg,
                        ),
                      ),
                    ],
                  ),
          ),
          Expanded(
            child: Center(
              child: Text(
                title ?? '',
                style: const TextStyle(
                  fontFamily: GmText.display,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: GmColors.fg,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: onShare != null
                ? IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.ios_share,
                      color: GmColors.fg,
                      size: 18,
                    ),
                    onPressed: onShare,
                  )
                : null,
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
          backgroundColor: GmColors.fg,
          foregroundColor: GmColors.onFg,
          disabledBackgroundColor: GmColors.fg.withValues(alpha: 0.4),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: GmColors.onFg,
                ),
              )
            : Text(
                label,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }
}

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
          gradient: const LinearGradient(
            colors: [GmColors.goldTop, GmColors.gold],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            foregroundColor: GmColors.onFg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: GmColors.onFg,
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 6),
                Icon(icon, size: 16, color: GmColors.onFg),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
