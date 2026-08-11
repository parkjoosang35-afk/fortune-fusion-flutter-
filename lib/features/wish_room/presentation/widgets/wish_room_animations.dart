/// [소원방 UI 전면 개선] 공용 애니메이션 헬퍼 위젯 모음.
///
/// 기존 정적 위젯(daily_message_card, fortune_pouch_status_card,
/// prayer_streak_badge, wish_card, wish_card_list, wish_room_header,
/// wish_guide_dialog, prayer_type_sheet)에 애니메이션을 "보강"하기 위한
/// 재사용 가능한 래퍼들이다. 기존 위젯의 내부 구조/로직은 건드리지 않고,
/// 겉을 감싸는 방식으로만 적용해 회귀 위험을 최소화한다.
///
/// 성능 원칙: 모든 반복 애니메이션은 로컬 AnimationController가 직접
/// 재생하며(Riverpod 상태를 프레임 단위로 갈아끼우지 않음), 반복 재생되는
/// 래퍼는 자체적으로 RepaintBoundary를 포함한다.
library;

import 'dart:async';

import 'package:flutter/material.dart';

/// 위젯이 처음 화면에 나타날 때 위에서 살짝 미끄러지며 페이드인되는
/// 1회성 진입 애니메이션. [delay]를 다르게 주면 리스트 아이템들을
/// 순차적으로(staggered) 등장시킬 수 있다.
///
/// 1회성 애니메이션이므로 부모가 rebuild되어도(데이터 갱신 등) 이 위젯의
/// State가 유지되는 한 재생되지 않는다 — 매번 재생되어 눈에 거슬리는 것을
/// 방지한다.
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offsetY;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 420),
    this.offsetY = 16,
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  Timer? _startTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _fade = curved;
    _slide = Tween<Offset>(
      begin: Offset(0, widget.offsetY / 100),
      end: Offset.zero,
    ).animate(curved);

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      _startTimer = Timer(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _fade.value,
          child: FractionalTranslation(
            translation: _slide.value,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// 탭했을 때 살짝 눌리는 듯한 스케일 피드백을 주는 공용 래퍼.
/// 기존 [GestureDetector] 단독 사용처를 이걸로 감싸기만 하면 되므로,
/// 내부 위젯 구조를 바꾸지 않고 촉각적 반응성만 추가할 수 있다.
class TapBounce extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleDown;

  const TapBounce({
    super.key,
    required this.child,
    this.onTap,
    this.scaleDown = 0.94,
  });

  @override
  State<TapBounce> createState() => _TapBounceState();
}

class _TapBounceState extends State<TapBounce> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onTap == null) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? widget.scaleDown : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// 카드류에 은은하게 숨쉬는 듯한 글로우를 반복 재생하는 공용 래퍼.
/// 메인 오브제(WishRoomObject)의 breathe 연출과 톤을 맞추기 위해 동일한
/// 3초 기본 주기를 사용한다.
class BreathingGlow extends StatefulWidget {
  final Widget child;
  final Color glowColor;
  final double minAlpha;
  final double maxAlpha;
  final Duration period;
  final double borderRadius;
  final double blurRadius;

  const BreathingGlow({
    super.key,
    required this.child,
    required this.glowColor,
    this.minAlpha = 0.05,
    this.maxAlpha = 0.22,
    this.period = const Duration(seconds: 3),
    this.borderRadius = 16,
    this.blurRadius = 18,
  });

  @override
  State<BreathingGlow> createState() => _BreathingGlowState();
}

class _BreathingGlowState extends State<BreathingGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.period)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final alpha =
              widget.minAlpha +
              (widget.maxAlpha - widget.minAlpha) * _controller.value;
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              boxShadow: [
                BoxShadow(
                  color: widget.glowColor.withValues(alpha: alpha),
                  blurRadius: widget.blurRadius,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// 숫자/텍스트 값이 바뀔 때(복주머니 개수, 연속 기도일수 등) 위로
/// 슬라이드되며 전환되는 공용 텍스트. [AnimatedSwitcher]의 key를 텍스트
/// 값 자체로 삼아, 값이 실제로 바뀔 때만 전환 애니메이션이 재생된다.
class AnimatedCountText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const AnimatedCountText({super.key, required this.text, this.style});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      transitionBuilder: (child, animation) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.4),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
      child: Text(text, key: ValueKey<String>(text), style: style),
    );
  }
}

/// [디자인 핸드오프 적용 — "마법진이 소환되는 신전"] `anim-dramatic` 화면
/// 진입 연출(`dramatic-appear`).
///
/// README/`wish-animations.css`: opacity 0→1, translateY(20px→0),
/// scale(0.98→1), 1s, `cubic-bezier(0.34, 1.56, 0.64, 1)`(spring), 1회.
/// 신규 8개 화면(Onboarding/Compose/Home/Detail/Feed/BoxOpening/
/// Celebration/Empty)이 처음 마운트될 때 이 래퍼로 콘텐츠를 감싸 "화면이
/// 살짝 튕기며 나타나는" V2 특유의 드라마틱한 등장감을 낸다.
class DramaticEntrance extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;

  const DramaticEntrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 1000),
  });

  @override
  State<DramaticEntrance> createState() => _DramaticEntranceState();
}

class _DramaticEntranceState extends State<DramaticEntrance>
    with SingleTickerProviderStateMixin {
  // CSS cubic-bezier(0.34, 1.56, 0.64, 1) — 오버슈트가 있는 스프링형
  // easing. Flutter의 Cubic 커브로 동일한 4개 제어점을 그대로 사용해
  // 1:1로 재현한다.
  static const Curve _springCurve = Cubic(0.34, 1.56, 0.64, 1.0);

  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _slideY;
  late final Animation<double> _scale;
  Timer? _startTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    final curved = CurvedAnimation(parent: _controller, curve: _springCurve);
    // fade는 spring 오버슈트에 영향받지 않도록 별도의 순수 선형 진행도로
    // 처리(오버슈트 구간에서 opacity가 1을 넘거나 음수가 되는 것을 방지).
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideY = Tween<double>(begin: 20, end: 0).animate(curved);
    _scale = Tween<double>(begin: 0.98, end: 1.0).animate(curved);

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      _startTimer = Timer(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _fade.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, _slideY.value),
            child: Transform.scale(scale: _scale.value, child: child),
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// 아이콘/이모지에 은은한 좌우 흔들림(sparkle wiggle)을 반복 재생하는
/// 공용 래퍼. 딱딱하게 고정된 이모지에 생기를 더하는 용도(예: 오늘의
/// 메시지 카드의 반짝임 아이콘).
class GentleWiggle extends StatefulWidget {
  final Widget child;
  final Duration period;
  final double maxAngle;

  const GentleWiggle({
    super.key,
    required this.child,
    this.period = const Duration(seconds: 2, milliseconds: 400),
    this.maxAngle = 0.12,
  });

  @override
  State<GentleWiggle> createState() => _GentleWiggleState();
}

class _GentleWiggleState extends State<GentleWiggle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.period)
      ..repeat(reverse: true);
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
      builder: (context, child) {
        final t = (_controller.value * 2) - 1; // -1 ~ 1
        return Transform.rotate(angle: t * widget.maxAngle, child: child);
      },
      child: widget.child,
    );
  }
}
