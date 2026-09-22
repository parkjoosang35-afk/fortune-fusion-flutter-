// ═══════════════════════════════════════════════════════════════
// FILE: sintong_hero_carousel.dart
// [신통방통 홈 v2] C-히어로 — README "히어로 캐러셀(메인)" 인터랙션
// 스펙 재현:
// - 6초 자동 순환, PageView 기반 좌우 스와이프
// - Ken Burns(활성 슬라이드 scale 1.05→1.0, 6s ease-out)
// - 캡션 페이드+슬라이드 인(0.9s, 0.3s delay)
// - 칩 로우 + 도트 인디케이터(부모 SintongHomeV2Screen이 currentIndex를
//   공유해 그리므로, 이 위젯은 PageController와 onPageChanged만 부모에게
//   노출한다)
// - 이미지/타이틀 탭 시 해당 카테고리 서브 화면으로 이동(더블탭 없이 —
//   히어로 자체 탭은 원본 스펙상 "현재 활성 카테고리 상세로 이동")
// ═══════════════════════════════════════════════════════════════
import 'dart:async';

import 'package:flutter/material.dart';

import '../sintong_home_v2_data.dart';
import '../sintong_home_v2_routing.dart';
import '../sintong_home_v2_tokens.dart';

const List<SHomeV2Category> sHeroOrder = [
  SHomeV2Category.guide,
  SHomeV2Category.saju,
  SHomeV2Category.tarot,
  SHomeV2Category.wish,
  SHomeV2Category.palm,
];

class SintongHeroCarousel extends StatefulWidget {
  const SintongHeroCarousel({super.key, required this.onIndexChanged});

  /// 현재 활성 슬라이드 인덱스를 부모(칩 로우/도트)에 알려주는 콜백.
  final ValueChanged<int> onIndexChanged;

  @override
  State<SintongHeroCarousel> createState() => SintongHeroCarouselState();
}

class SintongHeroCarouselState extends State<SintongHeroCarousel> {
  late final PageController _controller;
  Timer? _autoTimer;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _startAuto();
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startAuto() {
    _autoTimer?.cancel();
    _autoTimer = Timer.periodic(SHomeV2Motion.autoCycle, (_) {
      final next = (_current + 1) % sHeroOrder.length;
      goTo(next);
    });
  }

  void _stopAuto() {
    _autoTimer?.cancel();
    _autoTimer = null;
  }

  /// 칩 탭(부모)에서도 호출하는 공개 메서드 — 지정 인덱스로 캐러셀을
  /// 이동시키고 자동 순환을 리셋한다.
  void goTo(int index) {
    if (!_controller.hasClients) return;
    _controller.animateToPage(
      index,
      duration: SHomeV2Motion.heroTrackMove,
      curve: SHomeV2Motion.heroTrackCurve,
    );
  }

  void _onPageChanged(int index) {
    setState(() => _current = index);
    widget.onIndexChanged(index);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanDown: (_) => _stopAuto(),
      onPanEnd: (_) => _startAuto(),
      onPanCancel: _startAuto,
      child: SizedBox(
        height: 460,
        child: PageView.builder(
          controller: _controller,
          onPageChanged: _onPageChanged,
          itemCount: sHeroOrder.length,
          itemBuilder: (context, index) {
            final category = sHeroOrder[index];
            final isActive = index == _current;
            return _HeroSlide(
              category: category,
              isActive: isActive,
              onTap: () => openSubScreen(context, category),
            );
          },
        ),
      ),
    );
  }
}

class _HeroSlide extends StatefulWidget {
  const _HeroSlide({
    required this.category,
    required this.isActive,
    required this.onTap,
  });

  final SHomeV2Category category;
  final bool isActive;
  final VoidCallback onTap;

  @override
  State<_HeroSlide> createState() => _HeroSlideState();
}

class _HeroSlideState extends State<_HeroSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _kenBurns;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _kenBurns = AnimationController(
      vsync: this,
      duration: SHomeV2Motion.kenBurns,
    );
    _scale = Tween<double>(begin: 1.05, end: 1.0).animate(
      CurvedAnimation(parent: _kenBurns, curve: Curves.easeOut),
    );
    if (widget.isActive) _kenBurns.forward();
  }

  @override
  void didUpdateWidget(_HeroSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _kenBurns.forward(from: 0);
    } else if (!widget.isActive && oldWidget.isActive) {
      _kenBurns.value = 0;
    }
  }

  @override
  void dispose() {
    _kenBurns.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _scale,
            builder: (context, child) => Transform.scale(
              scale: _scale.value,
              child: child,
            ),
            child: Image.asset(widget.category.heroAsset, fit: BoxFit.cover),
          ),
          // Hero shade — README `.hero-shade` linear-gradient.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.4, 0.6, 1.0],
                colors: [
                  Color(0x8C000000),
                  Color(0x26000000),
                  Color(0x00000000),
                  Color(0x59000000),
                ],
              ),
            ),
          ),
          // Caption — fade+slide in when active.
          Positioned(
            left: 24,
            right: 24,
            top: 130,
            child: AnimatedOpacity(
              opacity: widget.isActive ? 1 : 0,
              duration: SHomeV2Motion.captionFade,
              curve: SHomeV2Motion.captionCurve,
              child: AnimatedSlide(
                offset: widget.isActive
                    ? Offset.zero
                    : const Offset(0, 0.02),
                duration: SHomeV2Motion.captionFade,
                curve: SHomeV2Motion.captionCurve,
                child: Column(
                  children: [
                    Text(
                      widget.category.heroEyebrow,
                      textAlign: TextAlign.center,
                      style: SHomeV2Text.heroEyebrow(),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      widget.category.heroTitle,
                      textAlign: TextAlign.center,
                      style: SHomeV2Text.heroTitle(),
                    ),
                    const SizedBox(height: 14),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 270),
                      child: Text(
                        widget.category.heroSub,
                        textAlign: TextAlign.center,
                        style: SHomeV2Text.heroSub().copyWith(
                          color: Colors.white.withValues(alpha: 0.88),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
