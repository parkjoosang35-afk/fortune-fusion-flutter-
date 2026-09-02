import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/guinji_map_theme.dart';

/// [2026-09 새 디자인 리스킨] `/guinji-map/*` 8화면 전용 공용 위젯 모음.
/// 새 디자인 zip `lib/guiindo/widgets/*`의 구조를 그대로 이식했다. 기존
/// `guinji_ui_kit.dart`(다크·라벤더 톤)와는 완전히 분리된 새 컴포넌트다.

/// ─────────────────────────────────────────────────────────────
/// 상단 바 — 새 디자인 `GuiindoTopBar`.
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
      decoration: const BoxDecoration(
        color: Color(0xD9FBF7EF),
        border: Border(bottom: BorderSide(color: GmColors.line)),
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
                      color: GmColors.ink,
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
                            colors: [GmColors.rose300, GmColors.rose600],
                          ),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          '신',
                          style: TextStyle(
                            color: Colors.white,
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
                          fontFamily: GmFonts.serif,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: GmColors.ink,
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
                  fontFamily: GmFonts.serif,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: GmColors.ink,
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
                      color: GmColors.ink,
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
/// 로즈골드 chip — 새 디자인 `ChipPill`/`LabelMini`.
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
        color: background ?? GmColors.bgCream,
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
              color: foreground ?? GmColors.inkSoft,
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
        color: color ?? GmColors.rose700,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class GmDot extends StatelessWidget {
  const GmDot({super.key, this.color = GmColors.rose500, this.size = 6});

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
/// 은은한 별 배경 — 새 디자인 `StarsBackground`.
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
      color: i.isEven ? GmColors.gold : GmColors.blush,
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
/// 다크 그라디언트 CTA 카드(별배경 포함) — L의 UpsellCTA, M/N의
/// ResultAppHandoff에서 공용으로 사용하는 컨테이너 셸.
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
            decoration: const BoxDecoration(gradient: GmColors.gradientDark),
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
/// 입력 필드(라벨 + 컨테이너) — I 화면에서 사용.
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
      color: GmColors.inkSoft,
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
        color: Colors.white.withValues(alpha: 0.8),
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
          backgroundColor: GmColors.ink,
          foregroundColor: GmColors.ivory,
          disabledBackgroundColor: GmColors.ink.withValues(alpha: 0.4),
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
                  color: GmColors.ivory,
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
          gradient: GmColors.gradientRose,
          borderRadius: BorderRadius.circular(16),
        ),
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            foregroundColor: Colors.white,
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
                  color: Colors.white,
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 6),
                Icon(icon, size: 16, color: Colors.white),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
