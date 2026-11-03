// ═══════════════════════════════════════════════════════════════
// FILE: gh_screen.dart
// [궁합지도 Star Map 디자인 적용] `flutter_starter/.../gh_screen.dart`
// 포팅본 + gh-ui.jsx의 GHMono/GHChip/GHCard/GHSectionHead/GHSteps/
// GHTitle/GHCheck/GHToggle/GHField/GHInputBox/GHSegment/GHTier 등
// 공용 UI 프리미티브를 Dart로 이식해 함께 모아둔다(이번 작업 범위인
// 01/02/03 화면 구현에 필요한 만큼만 포팅).
// ═══════════════════════════════════════════════════════════════
import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/gh_tokens.dart';
import '../theme/gh_typography.dart';

class GHScreen extends StatelessWidget {
  const GHScreen({
    super.key,
    this.appBar,
    required this.child,
    this.footer,
    this.bottomNav,
    this.padded = true,
    this.controller,
  });
  final PreferredSizeWidget? appBar;
  final Widget child;
  final Widget? footer;
  final Widget? bottomNav;
  final bool padded;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GHColors.bg2,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          const Positioned.fill(child: GHBackdrop()),
          SafeArea(
            bottom: bottomNav == null && footer == null,
            child: Column(
              children: [
                if (appBar != null) appBar!,
                Expanded(
                  child: SingleChildScrollView(
                    controller: controller,
                    padding: padded
                        ? const EdgeInsets.fromLTRB(20, 4, 20, 28)
                        : EdgeInsets.zero,
                    child: child,
                  ),
                ),
                if (footer != null)
                  _Footer(hasNav: bottomNav != null, child: footer!),
                if (bottomNav != null) bottomNav!,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.child, required this.hasNav});
  final Widget child;
  final bool hasNav;
  @override
  Widget build(BuildContext context) {
    final bottom = hasNav
        ? 12.0
        : max(12.0, MediaQuery.of(context).padding.bottom + 8);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: -28,
          height: 28,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [GHColors.bg2.withValues(alpha: 0), GHColors.bg2],
                ),
              ),
            ),
          ),
        ),
        Container(
          color: GHColors.bg2,
          padding: EdgeInsets.fromLTRB(20, 12, 20, bottom),
          child: child,
        ),
      ],
    );
  }
}

class GHAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GHAppBar({
    super.key,
    this.title,
    this.onBack,
    this.leading,
    this.actions = const [],
  });
  final String? title;
  final VoidCallback? onBack;
  final Widget? leading;
  final List<Widget> actions;
  @override
  Size get preferredSize => const Size.fromHeight(GHSpace.appBar);
  @override
  Widget build(BuildContext context) => SizedBox(
    height: GHSpace.appBar,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child:
                  leading ??
                  (onBack != null
                      ? GHIconButton(glyph: '←', onTap: onBack!, label: '뒤로')
                      : const SizedBox()),
            ),
          ),
          if (title != null)
            Flexible(
              flex: 2,
              child: Text(
                title!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GHText.cardTitle(size: 16),
              ),
            ),
          Expanded(
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
          ),
        ],
      ),
    ),
  );
}

class GHIconButton extends StatelessWidget {
  const GHIconButton({
    super.key,
    required this.glyph,
    required this.onTap,
    required this.label,
  });
  final String glyph;
  final VoidCallback onTap;
  final String label;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: InkResponse(
      onTap: onTap,
      radius: 22,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: GHColors.cardSolid.withValues(alpha: .7),
          border: Border.all(color: GHColors.lineSoft),
        ),
        child: Text(glyph, style: GHText.ui(size: 16)),
      ),
    ),
  );
}

/// Never-flat background: navy gradient + 2 radial washes + star dust.
class GHBackdrop extends StatelessWidget {
  const GHBackdrop({super.key, this.intensity = 1});
  final double intensity;
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [GHColors.bg1, GHColors.bg2],
              stops: const [0, .55],
            ),
          ),
        ),
      ),
      Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-.7, -1),
              radius: 1.2,
              colors: [
                GHColors.violet.withValues(alpha: .16 * intensity),
                Colors.transparent,
              ],
              stops: const [0, .55],
            ),
          ),
        ),
      ),
      Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(1, 1),
              radius: .9,
              colors: [
                GHColors.gold.withValues(alpha: .08 * intensity),
                Colors.transparent,
              ],
              stops: const [0, .6],
            ),
          ),
        ),
      ),
      const Positioned.fill(child: _StarDust()),
    ],
  );
}

class _StarDust extends StatelessWidget {
  const _StarDust();
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _DustPainter());
}

class _DustPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    var seed = 3;
    double rnd() {
      seed = (seed * 9301 + 49297) % 233280;
      return seed / 233280;
    }

    final p = Paint()..color = GHColors.ivory;
    for (var i = 0; i < 46; i++) {
      final x = rnd() * s.width, y = rnd() * s.height;
      final r = .4 + rnd() * .9, o = .25 + rnd() * .6;
      rnd(); // twinkle duration (animate with AnimationController if desired)
      c.drawCircle(Offset(x, y), r, p..color = GHColors.ivory.withValues(alpha: o * .7));
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────────────────────
// Common primitives (gh-ui.jsx 이식)
// ─────────────────────────────────────────────────────────

class GHMono extends StatelessWidget {
  const GHMono(this.text, {super.key, this.color});
  final String text;
  final Color? color;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: GHText.mono(color: color ?? GHColors.gray),
  );
}

class GHChip extends StatelessWidget {
  const GHChip({
    super.key,
    required this.label,
    required this.active,
    this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(GHRadius.chip),
        color: active
            ? GHColors.gold.withValues(alpha: .12)
            : GHColors.cardSolid.withValues(alpha: .6),
        border: Border.all(color: active ? GHColors.gold : GHColors.lineSoft),
      ),
      child: Text(
        label,
        style: GHText.ui(
          size: 12,
          weight: FontWeight.w600,
          color: active ? GHColors.gold : GHColors.gray,
        ),
      ),
    ),
  );
}

class GHCard extends StatefulWidget {
  const GHCard({
    super.key,
    required this.child,
    this.onTap,
    this.selected = false,
    this.padding = const EdgeInsets.all(18),
    this.borderRadius = GHRadius.card,
    this.height,
    this.minHeight,
  });
  final Widget child;
  final VoidCallback? onTap;
  final bool selected;
  final EdgeInsets padding;
  final double borderRadius;
  final double? height;
  final double? minHeight;

  @override
  State<GHCard> createState() => _GHCardState();
}

class _GHCardState extends State<GHCard> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final card = AnimatedScale(
      scale: _down ? .98 : 1,
      duration: GHMotion.press,
      child: Container(
        height: widget.height,
        constraints: widget.minHeight != null
            ? BoxConstraints(minHeight: widget.minHeight!)
            : null,
        padding: widget.padding,
        decoration: BoxDecoration(
          color: GHColors.card,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(
            color: widget.selected ? GHColors.gold : GHColors.lineSoft,
          ),
          boxShadow: widget.selected ? GHShadow.selected : null,
        ),
        child: widget.child,
      ),
    );
    if (widget.onTap == null) return card;
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: card,
    );
  }
}

class GHSectionHead extends StatelessWidget {
  const GHSectionHead({super.key, this.mono, required this.title, this.trailing});
  final String? mono;
  final String title;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (mono != null) ...[
                GHMono(mono!, color: GHColors.gold),
                const SizedBox(height: 5),
              ],
              Text(title, style: GHText.cardTitle(size: 17)),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    ),
  );
}

class GHSteps extends StatelessWidget {
  const GHSteps({
    super.key,
    required this.step,
    this.total = 4,
    this.labels = const ['분야', '나', '상대', '분석'],
  });
  final int step;
  final int total;
  final List<String> labels;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 22),
    child: Row(
      children: List.generate(total, (i) {
        final on = i < step;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == total - 1 ? 0 : 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: on
                        ? GHColors.gold
                        : GHColors.gray.withValues(alpha: .18),
                    boxShadow: i == step - 1
                        ? [
                            BoxShadow(
                              color: GHColors.glowShadow,
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  i < labels.length ? labels[i] : '',
                  style: GHText.ui(
                    size: 11,
                    weight: FontWeight.w600,
                    color: on
                        ? GHColors.gold
                        : GHColors.gray.withValues(alpha: .7),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    ),
  );
}

class GHTitle extends StatelessWidget {
  const GHTitle({
    super.key,
    this.mono,
    required this.title,
    this.sub,
    this.center = false,
  });
  final String? mono;
  final String title;
  final String? sub;
  final bool center;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: Column(
      crossAxisAlignment: center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        if (mono != null) ...[
          GHMono(mono!, color: GHColors.gold),
          const SizedBox(height: 10),
        ],
        Text(
          title,
          textAlign: center ? TextAlign.center : TextAlign.start,
          style: GHText.title(size: 24).copyWith(height: 1.32),
        ),
        if (sub != null) ...[
          const SizedBox(height: 10),
          Text(
            sub!,
            textAlign: center ? TextAlign.center : TextAlign.start,
            style: GHText.ui(size: 14, height: 1.6, color: GHColors.gray),
          ),
        ],
      ],
    ),
  );
}
