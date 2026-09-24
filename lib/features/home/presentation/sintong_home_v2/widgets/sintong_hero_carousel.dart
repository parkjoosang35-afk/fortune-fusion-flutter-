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
  SHomeV2Category.face,
  SHomeV2Category.palm,
];

/// [사진 잘림 방지 — 2026-09-24 사용자 리포트] 히어로 원본 이미지들의
/// 실제 가로:세로 비율(card-*.jpg 572×1024, hero.jpg 768×1376 — 둘 다
/// 약 9:16.1). 기존 고정 `height: 460` 박스는 이 비율보다 훨씬 넓적해
/// BoxFit.cover가 인물 얼굴을 크게 잘라내는 문제가 있었다(사용자
/// 스크린샷으로 확인: "귀인지도" 슬라이드 인물 머리가 통째로 잘림).
/// 화면 폭 기준 AspectRatio로 박스를 감싸 원본 비율 그대로 보여주고,
/// 그만큼 늘어난 높이는 아래 콘텐츠(전체보기 시트)가 자연스럽게 밀려
/// 내려가는 것으로 해결한다(사용자 확인: "밑에 전체보기 섹션을 좀더
/// 내려도 괜찮아").
const double sHeroAspectRatio = 572 / 1024;

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
      // [사진 잘림 방지] 실제 높이는 부모(sintong_home_v2_screen.dart)가
      // AspectRatio로 감싸 결정하므로, 여기서는 주어진 공간을 그대로
      // 채우기만 한다(StackFit.expand로 전달된 tight constraints 사용).
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
          // [2026-09-24 사용자 리포트] "오늘의 귀인/오늘의 운" 같은 큰
          // 타이틀(heroTitle, 30px)을 완전히 삭제하고, 작은 eyebrow +
          // 설명 문구만 남겨 균형 있게 배치한다. 히어로 박스가 이제
          // 원본 사진 비율(AspectRatio)만큼 세로로 길어졌으므로, 고정
          // 픽셀 top 대신 Align의 상대 비율로 배치해 어떤 화면 폭에서도
          // 이미지 상단부 여백에 자연스럽게 자리잡게 한다.
          //
          // [텍스트가 얼굴을 가림 — 2026-09-24 사용자 2차 리포트] 위
          // -0.62 값은 이미지 상단부(인물 얼굴이 시작되는 지점)와 겹쳐
          // 문구가 얼굴을 가렸다("글씨가 너무 위에 있으니 얼굴을
          // 가린다"). 6장 사진 모두 얼굴이 대체로 상단~중상단(-0.6~0
          // 구간)에 있으므로, 문구를 그 아래(칩 로우 위 여백)로 옮겨
          // 얼굴과 겹치지 않게 한다.
          Align(
            alignment: const Alignment(0, 0.42),
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.category.heroEyebrow,
                        textAlign: TextAlign.center,
                        style: SHomeV2Text.heroEyebrow(),
                      ),
                      const SizedBox(height: 10),
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
          ),
        ],
      ),
    );
  }
}
