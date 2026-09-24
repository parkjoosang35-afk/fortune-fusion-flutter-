// ============================================================
// [정통사주 결과 화면 개편 - Dawn Paper 디자인 핸드오프]
// 원본: design_handoff_saju_result.zip flutter_starter/animations.dart
//
// [수정사항]
// 1. deprecated `Color.withOpacity()` → 프로젝트 표준 `withValues(alpha:)`
//    로 교체(원본 232행 `widget.element.color.withOpacity(0.7)`).
// 2. 원본 264~266행의 `Positioned.fill(child: IgnorePointer(child:
//    Container()))`는 Column 자식 슬롯에 아무 효과 없이 빈 Container만
//    두는 죽은 코드라 이식 과정에서 제거했다(동작 변화 없음).
// 3. `saju_tokens.dart` 참조 → 이 프로젝트에서 이름을 격리한
//    `saju_dawn_tokens.dart`(SajuDawn* 접두)로 교체.
// ============================================================

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'saju_dawn_tokens.dart';

/// 붓글씨 등장 애니메이션 — 일간 한자용.
///
/// 사용 예:
/// ```dart
/// BrushInHanja(text: '甲', color: theme.main, fontSize: 52)
/// ```
class BrushInHanja extends StatefulWidget {
  final String text;
  final Color color;
  final double fontSize;
  final FontWeight fontWeight;
  final Duration delay;

  const BrushInHanja({
    super.key,
    required this.text,
    required this.color,
    this.fontSize = 52,
    this.fontWeight = FontWeight.w900,
    this.delay = SajuDawnMotion.brushInDelay,
  });

  @override
  State<BrushInHanja> createState() => _BrushInHanjaState();
}

class _BrushInHanjaState extends State<BrushInHanja>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;
  late final Animation<double> _rotation;
  late final Animation<double> _blur;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: SajuDawnMotion.brushInDuration,
    );

    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.6, end: 1.08), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0), weight: 40),
    ]).animate(CurvedAnimation(parent: _c, curve: SajuDawnMotion.easeMain));

    _rotation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: -0.104, end: 0.017),
        weight: 60,
      ), // -6deg → 1deg
      TweenSequenceItem(tween: Tween(begin: 0.017, end: 0.0), weight: 40),
    ]).animate(CurvedAnimation(parent: _c, curve: SajuDawnMotion.easeMain));

    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _c,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _blur = Tween<double>(begin: 4, end: 0).animate(
      CurvedAnimation(
        parent: _c,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );

    Future.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return ImageFiltered(
          imageFilter: ImageFilter.blur(
            sigmaX: _blur.value,
            sigmaY: _blur.value,
          ),
          child: Opacity(
            opacity: _opacity.value,
            child: Transform.rotate(
              angle: _rotation.value,
              child: Transform.scale(
                scale: _scale.value,
                child: Text(
                  widget.text,
                  style: TextStyle(
                    fontFamily: SajuDawnFonts.serif,
                    fontSize: widget.fontSize,
                    fontWeight: widget.fontWeight,
                    color: widget.color,
                    height: 1,
                    letterSpacing: -widget.fontSize * 0.02,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 스크롤 진입 시 페이드업(모든 섹션에 사용).
class RevealOnScroll extends StatefulWidget {
  final Widget child;
  final String uniqueKey; // VisibilityDetector 필수
  final Duration duration;
  final double offsetY;

  const RevealOnScroll({
    super.key,
    required this.child,
    required this.uniqueKey,
    this.duration = SajuDawnMotion.sectionRevealDuration,
    this.offsetY = 14,
  });

  @override
  State<RevealOnScroll> createState() => _RevealOnScrollState();
}

class _RevealOnScrollState extends State<RevealOnScroll> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key(widget.uniqueKey),
      onVisibilityChanged: (info) {
        if (info.visibleFraction >= 0.12 && !_revealed && mounted) {
          setState(() => _revealed = true);
        }
      },
      child: AnimatedSlide(
        offset: _revealed ? Offset.zero : Offset(0, widget.offsetY / 100),
        duration: widget.duration,
        curve: SajuDawnMotion.easeMain,
        child: AnimatedOpacity(
          opacity: _revealed ? 1 : 0,
          duration: widget.duration,
          curve: SajuDawnMotion.easeMain,
          child: widget.child,
        ),
      ),
    );
  }
}

/// 오행 막대(스크롤 진입 시 순차 grow).
class OhaengBar extends StatefulWidget {
  final SajuDawnElement element;
  final int value; // 실제 값(0..N)
  final double heightRatio; // 0.0 ~ 1.0(막대 최고점 대비)
  final int index; // 0..4(스태거용)
  final bool active; // 진입했는가

  const OhaengBar({
    super.key,
    required this.element,
    required this.value,
    required this.heightRatio,
    required this.index,
    required this.active,
  });

  @override
  State<OhaengBar> createState() => _OhaengBarState();
}

class _OhaengBarState extends State<OhaengBar> {
  bool _showValue = false;

  @override
  void didUpdateWidget(covariant OhaengBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      Future.delayed(
        SajuDawnMotion.barStartDelay +
            SajuDawnMotion.barStaggerGap * widget.index +
            const Duration(milliseconds: 800),
        () {
          if (mounted) setState(() => _showValue = true);
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const maxH = 100.0;
    final targetH = widget.active ? maxH * widget.heightRatio : 0.0;

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 30),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                widthFactor: 0.6,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: targetH),
                      duration: widget.active
                          ? SajuDawnMotion.barGrowDuration
                          : Duration.zero,
                      curve: SajuDawnMotion.easeMain,
                      builder: (_, h, __) => Container(
                        height: h,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              widget.element.color.withValues(alpha: 0.7),
                              widget.element.color,
                            ],
                          ),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: -22 + (widget.active ? 0 : 40),
                      child: AnimatedOpacity(
                        opacity: _showValue ? 1 : 0,
                        duration: const Duration(milliseconds: 400),
                        child: Text(
                          '${widget.value}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: SajuDawnColors.ink,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 32,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(
                widget.element.hanja,
                style: TextStyle(
                  fontFamily: SajuDawnFonts.serif,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: widget.element.color,
                  height: 1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                widget.element.hangul,
                style: const TextStyle(fontSize: 10, color: SajuDawnColors.ink3, height: 1),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 사주 원국 셀 순차 등장.
///
/// 사용:
/// ```dart
/// StaggeredCellReveal(index: 3, active: isVisible, child: WongookCell(...))
/// ```
class StaggeredCellReveal extends StatefulWidget {
  final Widget child;
  final int index;
  final bool active;

  const StaggeredCellReveal({
    super.key,
    required this.child,
    required this.index,
    required this.active,
  });

  @override
  State<StaggeredCellReveal> createState() => _StaggeredCellRevealState();
}

class _StaggeredCellRevealState extends State<StaggeredCellReveal> {
  bool _revealed = false;

  @override
  void didUpdateWidget(covariant StaggeredCellReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      Future.delayed(SajuDawnMotion.cellStaggerGap * widget.index, () {
        if (mounted) setState(() => _revealed = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: _revealed ? Offset.zero : const Offset(0, 0.08),
      duration: SajuDawnMotion.cellRevealDuration,
      curve: SajuDawnMotion.easeMain,
      child: AnimatedOpacity(
        opacity: _revealed ? 1 : 0,
        duration: SajuDawnMotion.cellRevealDuration,
        curve: SajuDawnMotion.easeMain,
        child: widget.child,
      ),
    );
  }
}
