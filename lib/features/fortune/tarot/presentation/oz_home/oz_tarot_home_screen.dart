// ============================================================
//  oz_tarot_home_screen.dart
//
//  신통방통 타로 · 메인 페이지(홈) · 오즈 스타일 완전한 위젯
//  (handoff-home.zip 04_oz_tarot_home_screen.dart 이식본)
//
//  구조:
//    - 상단바 (타로 + 스피커/히스토리 아이콘)
//    - 히어로 배너 (자동 스와이프 3장, 5초 간격)
//    - 인기 카테고리 배너 (골드 액센트, 탭 시 서브카테고리 허브②로)
//    - NEW 카테고리 배너 (로즈 액센트, 탭 시 서브카테고리 허브②로)
//    - 테마별로 둘러보기 (6개 · 2열 그리드, 탭 시 서브카테고리 허브②로)
//
//  [이식 시 실제 연동으로 채운 부분 - 원본 TODO들]
//    - 스피커 아이콘: 원본은 TODO 스텁 → 기존 [TarotAudioController]
//      (Provider, `app.dart`에 전역 등록됨, 다른 6개 오즈 리스킨 화면과
//      완전히 동일한 컨트롤러)의 `toggleMute()`/`muted`에 실제 연결.
//    - 히스토리 아이콘: 원본은 TODO 스텁 → 기존 라우팅 방식
//      (`Navigator.pushNamed`, 이 프로젝트는 go_router/auto_route가 아닌
//      Navigator 1.0 onGenerateRoute 기반)으로 `/ai-fortune/tarot/history`
//      이동(다른 오즈 리스킨 화면들과 동일 라우트, 화면 자체는 무수정).
//    - `_navigateTo(context, route)` 문자열 스텁: 제거하고, 카드 종류별로
//      실제 타입 안전한 네비게이션 콜백으로 교체했다(히어로→카테고리 상세,
//      배너/테마→서브카테고리 허브). 상세 근거는 oz_home_data.dart 상단
//      주석 참고.
//    - `.withOpacity()` → 이 프로젝트 표준(`flutter analyze` 경고 방지)에
//      맞춰 전부 `.withValues(alpha:)`로 교체.
//
//  ⚠️ 다른 화면(카테고리 상세·질문·카드뽑기·로딩·결과, 즉 화면03~07)은
//     이 작업에서 절대 건드리지 않았다. 이 홈 화면(화면01) 하나만 이
//     새 위젯(OzTarotHomeScreen)으로 교체됐다(app_router.dart의
//     tarotHomeRoute 케이스 1줄만 수정).
// ============================================================

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/router/app_router.dart' show AppRouter;
import '../../application/tarot_audio_controller.dart';
import '../../domain/tarot_category_model.dart';
import '../tarot_home_screen.dart' show enterTarotCategory;
import 'oz_home_data.dart';
import 'oz_home_theme.dart';

// ============================================================
//  Root Widget · OzTarotHomeScreen
// ============================================================
class OzTarotHomeScreen extends StatelessWidget {
  const OzTarotHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<TarotAudioController>();

    return Scaffold(
      backgroundColor: OzHomeColors.bgDeep,
      body: Stack(
        children: [
          // 1. Background layers
          const _OzHomeBackground(),

          // 2. Content
          SafeArea(
            child: CustomScrollView(
              slivers: [
                // ─ Topbar ─
                SliverToBoxAdapter(
                  child: _OzHomeTopbar(
                    muted: audio.muted,
                    onSpeakerTap: () => audio.toggleMute(),
                    onHistoryTap: () {
                      audio.playUiTap();
                      Navigator.of(
                        context,
                      ).pushNamed('/ai-fortune/tarot/history');
                    },
                  ),
                ),

                // ─ Hero carousel (auto-swipe 3 slides) ─
                const SliverToBoxAdapter(
                  child: SizedBox(height: OzHomeSpacing.md),
                ),
                const SliverToBoxAdapter(child: _OzHomeHeroCarousel()),

                // ─ Category banners (인기 · NEW) ─
                const SliverToBoxAdapter(
                  child: SizedBox(height: OzHomeSpacing.xxl),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: OzHomeSpacing.lg,
                    ),
                    child: Column(
                      children: [
                        for (int i = 0; i < kOzCategoryBanners.length; i++) ...[
                          if (i > 0) const SizedBox(height: 14),
                          _OzHomeCategoryBanner(data: kOzCategoryBanners[i]),
                        ],
                      ],
                    ),
                  ),
                ),

                // ─ Theme cards (2-col grid) ─
                const SliverToBoxAdapter(
                  child: SizedBox(height: OzHomeSpacing.xxl),
                ),
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: OzHomeSpacing.lg),
                    child: _OzHomeSectionTitle(text: '✦  테마별로 둘러보기'),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 14)),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: OzHomeSpacing.lg,
                  ),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 0.94,
                        ),
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _OzHomeThemeCard(data: kOzThemeCards[i]),
                      childCount: kOzThemeCards.length,
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
//  Background · 그라디언트 + 별 필드
// ============================================================
class _OzHomeBackground extends StatelessWidget {
  const _OzHomeBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 3-stop 그라디언트
        Positioned.fill(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  OzHomeColors.bgTop,
                  OzHomeColors.bgMid,
                  OzHomeColors.bgDeep,
                ],
                stops: [0.0, 0.45, 1.0],
              ),
            ),
          ),
        ),
        // 라디얼 글로우 (좌상단 라벤더)
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.7, -0.9),
                radius: 1.4,
                colors: [
                  const Color(0xFFB48CDC).withValues(alpha: 0.15),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // 라디얼 글로우 (우중단 골드)
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.85, 0.1),
                radius: 1.2,
                colors: [
                  OzHomeColors.gold.withValues(alpha: 0.05),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // 별 필드
        const Positioned.fill(child: IgnorePointer(child: _OzHomeStarField())),
      ],
    );
  }
}

// ─── Star field (deterministic seed) ────────────────
class _OzHomeStarField extends StatelessWidget {
  const _OzHomeStarField();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _StarFieldPainter());
  }
}

class _StarFieldPainter extends CustomPainter {
  // (x%, y%, radius, opacity) · deterministic
  static const _stars = <(double, double, double, double)>[
    (0.12, 0.22, 1.2, 0.7),
    (0.78, 0.14, 1.0, 0.5),
    (0.62, 0.28, 1.4, 0.6),
    (0.34, 0.08, 1.0, 0.5),
    (0.88, 0.46, 1.2, 0.55),
    (0.08, 0.66, 1.0, 0.4),
    (0.46, 0.06, 1.4, 0.5),
    (0.22, 0.44, 1.0, 0.45),
    (0.92, 0.82, 1.2, 0.5),
    (0.58, 0.32, 1.0, 0.4),
    (0.15, 0.90, 0.8, 0.35),
    (0.72, 0.62, 1.1, 0.5),
    (0.42, 0.72, 0.9, 0.4),
    (0.95, 0.30, 0.8, 0.5),
    (0.05, 0.42, 1.0, 0.45),
    (0.68, 0.86, 1.3, 0.55),
    (0.28, 0.58, 0.9, 0.4),
    (0.52, 0.15, 1.0, 0.5),
    (0.82, 0.72, 0.8, 0.4),
    (0.18, 0.35, 1.1, 0.5),
  ];

  @override
  void paint(Canvas c, Size s) {
    final paint = Paint();
    for (final star in _stars) {
      final (xPct, yPct, r, o) = star;
      // 별은 상단 70% 영역에만 (구름/콘텐츠와 겹치지 않게)
      if (yPct > 0.85) continue;
      paint.color = OzHomeColors.fg.withValues(alpha: o * 0.55);
      c.drawCircle(Offset(xPct * s.width, yPct * s.height), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarFieldPainter oldDelegate) => false;
}

// ============================================================
//  Topbar (타로 · 스피커 · 히스토리)
// ============================================================
class _OzHomeTopbar extends StatelessWidget {
  final bool muted;
  final VoidCallback? onSpeakerTap;
  final VoidCallback? onHistoryTap;

  const _OzHomeTopbar({
    required this.muted,
    this.onSpeakerTap,
    this.onHistoryTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        OzHomeSpacing.lg,
        OzHomeSpacing.xs,
        OzHomeSpacing.lg,
        OzHomeSpacing.sm,
      ),
      child: Row(
        children: [
          Text('타로', style: OzHomeTypography.topbarTitle()),
          const Spacer(),
          _iconButton(
            onTap: onSpeakerTap,
            tooltip: muted ? '타로 소리 켜기' : '타로 소리 끄기',
            child: _SpeakerIcon(muted: muted),
          ),
          const SizedBox(width: 10),
          _iconButton(
            onTap: onHistoryTap,
            tooltip: '타로 히스토리 보기',
            child: const _HistoryIcon(),
          ),
        ],
      ),
    );
  }

  Widget _iconButton({
    VoidCallback? onTap,
    required Widget child,
    String? tooltip,
  }) {
    final button = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(width: 32, height: 32, child: Center(child: child)),
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }
}

class _SpeakerIcon extends StatelessWidget {
  final bool muted;
  const _SpeakerIcon({required this.muted});
  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(20, 20),
    painter: _SpeakerIconPainter(muted: muted),
  );
}

class _SpeakerIconPainter extends CustomPainter {
  final bool muted;
  _SpeakerIconPainter({required this.muted});

  @override
  void paint(Canvas c, Size s) {
    final paint = Paint()
      ..color = OzHomeColors.fg
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = OzHomeColors.fg
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.5;

    // 스피커 몸통 (사다리꼴 + 사각형)
    final path = Path()
      ..moveTo(11 / 24 * s.width, 5 / 24 * s.height)
      ..lineTo(6 / 24 * s.width, 9 / 24 * s.height)
      ..lineTo(3 / 24 * s.width, 9 / 24 * s.height)
      ..lineTo(3 / 24 * s.width, 15 / 24 * s.height)
      ..lineTo(6 / 24 * s.width, 15 / 24 * s.height)
      ..lineTo(11 / 24 * s.width, 19 / 24 * s.height)
      ..close();
    c.drawPath(path, paint);

    if (muted) {
      // 음소거: X 표시
      final xStroke = Paint()
        ..color = OzHomeColors.fg
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.6;
      c.drawLine(
        Offset(14.5 / 24 * s.width, 9 / 24 * s.height),
        Offset(20 / 24 * s.width, 15 / 24 * s.height),
        xStroke,
      );
      c.drawLine(
        Offset(20 / 24 * s.width, 9 / 24 * s.height),
        Offset(14.5 / 24 * s.width, 15 / 24 * s.height),
        xStroke,
      );
    } else {
      // 음파 곡선 2개
      c.drawArc(
        Rect.fromCircle(
          center: Offset(15 / 24 * s.width, 12 / 24 * s.height),
          radius: 3 / 24 * s.width,
        ),
        -math.pi / 2.5,
        math.pi / 1.25,
        false,
        stroke,
      );
      c.drawArc(
        Rect.fromCircle(
          center: Offset(18 / 24 * s.width, 12 / 24 * s.height),
          radius: 5 / 24 * s.width,
        ),
        -math.pi / 2.5,
        math.pi / 1.25,
        false,
        stroke,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpeakerIconPainter oldDelegate) =>
      oldDelegate.muted != muted;
}

class _HistoryIcon extends StatelessWidget {
  const _HistoryIcon();
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size(20, 20), painter: _HistoryIconPainter());
}

class _HistoryIconPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final stroke = Paint()
      ..color = OzHomeColors.fg
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.5;
    c.drawCircle(Offset(s.width / 2, s.height / 2), s.width * 9 / 24, stroke);
    // 시계 바늘 (7 → 12 → 3.5)
    final path = Path()
      ..moveTo(s.width / 2, s.height * 7 / 24)
      ..lineTo(s.width / 2, s.height / 2)
      ..lineTo(s.width * 15.5 / 24, s.height * 14 / 24);
    c.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _HistoryIconPainter oldDelegate) => false;
}

// ============================================================
//  Hero Carousel · 자동 스와이프 · 5초 간격
// ============================================================
class _OzHomeHeroCarousel extends StatefulWidget {
  const _OzHomeHeroCarousel();

  @override
  State<_OzHomeHeroCarousel> createState() => _OzHomeHeroCarouselState();
}

class _OzHomeHeroCarouselState extends State<_OzHomeHeroCarousel> {
  final _controller = PageController();
  Timer? _timer;
  int _idx = 0;

  @override
  void initState() {
    super.initState();
    _startAutoplay();
  }

  void _startAutoplay() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      final next = (_idx + 1) % kOzHeroSlides.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onHeroCtaTap(String categoryId) {
    final category = TarotCategoryData.byId(categoryId);
    if (category != null) enterTarotCategory(context, category);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: OzHomeSpacing.lg),
      height: 260,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(OzHomeRadii.hero),
        border: Border.all(color: OzHomeColors.gold.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            offset: const Offset(0, 8),
            blurRadius: 30,
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          // Pages
          PageView.builder(
            controller: _controller,
            itemCount: kOzHeroSlides.length,
            onPageChanged: (i) => setState(() => _idx = i),
            itemBuilder: (_, i) => _HeroSlideView(
              slide: kOzHeroSlides[i],
              onCtaTap: () => _onHeroCtaTap(kOzHeroSlides[i].categoryId),
            ),
          ),
          // Dots (top-right pill)
          Positioned(
            top: 14,
            right: 14,
            child: _HeroDots(current: _idx, total: kOzHeroSlides.length),
          ),
        ],
      ),
    );
  }
}

class _HeroSlideView extends StatelessWidget {
  final OzHeroSlide slide;
  final VoidCallback onCtaTap;
  const _HeroSlideView({required this.slide, required this.onCtaTap});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background
        Positioned.fill(
          child: Image.asset(slide.imageAsset, fit: BoxFit.cover),
        ),
        // Scrim (bottom gradient)
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    OzHomeColors.bgMid.withValues(alpha: 0.55),
                    OzHomeColors.bgDeep.withValues(alpha: 0.9),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Content
        Positioned(
          left: OzHomeSpacing.lg,
          right: OzHomeSpacing.lg,
          bottom: 22,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(slide.tag, style: OzHomeTypography.monoLabel(size: 10)),
              const SizedBox(height: 6),
              for (final line in slide.titleLines)
                Text(line, style: OzHomeTypography.heroTitle(size: 22)),
              const SizedBox(height: 14),
              _OzHomePrimaryButton(label: slide.cta, onTap: onCtaTap),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroDots extends StatelessWidget {
  final int current;
  final int total;
  const _HeroDots({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: OzHomeColors.bgDeep.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(OzHomeRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: 5),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: i == current ? 16 : 5,
              height: 5,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(OzHomeRadii.pill),
                color: i == current
                    ? OzHomeColors.gold
                    : OzHomeColors.fg.withValues(alpha: 0.4),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================
//  Category Banner · 인기 · NEW
//  탭 시 서브 카테고리 허브②([AppRouter.tarotHubRoute])로 이동한다.
// ============================================================
class _OzHomeCategoryBanner extends StatelessWidget {
  final OzCategoryBannerData data;
  const _OzHomeCategoryBanner({required this.data});

  Color get _accentColor => switch (data.accent) {
    OzBannerAccent.gold => OzHomeColors.gold,
    OzBannerAccent.rose => OzHomeColors.rose,
  };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pushNamed(AppRouter.tarotHubRoute),
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(OzHomeRadii.banner),
          border: Border.all(color: OzHomeColors.gold.withValues(alpha: 0.22)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              offset: const Offset(0, 8),
              blurRadius: 26,
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            // Background image
            Positioned.fill(
              child: Image.asset(data.imageAsset, fit: BoxFit.cover),
            ),
            // Scrim (left dark → right transparent, character sits on right)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        OzHomeColors.bgDeep.withValues(alpha: 0.88),
                        OzHomeColors.bgDeep.withValues(alpha: 0.62),
                        OzHomeColors.bgDeep.withValues(alpha: 0.15),
                        OzHomeColors.bgDeep.withValues(alpha: 0.0),
                      ],
                      stops: const [0.0, 0.45, 0.85, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            // Text content (left-aligned · max 62% width)
            Positioned(
              left: 24,
              top: 22,
              bottom: 22,
              right: 24,
              child: FractionallySizedBox(
                widthFactor: 0.62,
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Tagline (mono label)
                    Text(
                      data.tagline,
                      style: OzHomeTypography.monoLabel(
                        size: 9.5,
                        trackingEm: 0.35,
                        color: _accentColor.withValues(alpha: 0.75),
                      ),
                    ),
                    // Title (two lines, second line accent italic)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final line in data.titleLines)
                          Text(
                            line.text,
                            style: line.accent
                                ? OzHomeTypography.bannerAccent(
                                    size: 20,
                                    color: _accentColor,
                                  )
                                : OzHomeTypography.heroTitle(size: 22),
                          ),
                      ],
                    ),
                    // Meta row (count pill + arrow)
                    Row(
                      children: [
                        _CountPill(count: data.count, color: _accentColor),
                        const SizedBox(width: 12),
                        Text(
                          '전체 보기 →',
                          style: OzHomeTypography.monoLabel(
                            size: 10,
                            trackingEm: 0.15,
                            color: OzHomeColors.fg.withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  final int count;
  final Color color;
  const _CountPill({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(OzHomeRadii.pill),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text('$count', style: OzHomeTypography.countNumber(color: color)),
          const SizedBox(width: 4),
          Text(
            '개 카테고리',
            style: OzHomeTypography.countLabel(
              color: color.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
//  Section Title
// ============================================================
class _OzHomeSectionTitle extends StatelessWidget {
  final String text;
  const _OzHomeSectionTitle({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(children: [Text(text, style: OzHomeTypography.sectionTitle())]);
  }
}

// ============================================================
//  Theme Card · 2-col grid · 6개
//  탭 시 서브 카테고리 허브②로 이동하며 해당 그룹 칩이 선택된 상태로
//  시작한다(기존 홈이 항상 하던 것과 동일한 방식, arguments로 그룹 전달).
// ============================================================
class _OzHomeThemeCard extends StatelessWidget {
  final OzThemeCardData data;
  const _OzHomeThemeCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(
        context,
      ).pushNamed(AppRouter.tarotHubRoute, arguments: data.group),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: OzHomeColors.gold.withValues(alpha: 0.18)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              offset: const Offset(0, 4),
              blurRadius: 14,
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            // Background
            Positioned.fill(
              child: Image.asset(data.imageAsset, fit: BoxFit.cover),
            ),
            // Scrim (bottom gradient)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.center,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        OzHomeColors.bgMid.withValues(alpha: 0.65),
                        OzHomeColors.bgDeep.withValues(alpha: 0.95),
                      ],
                      stops: const [0.4, 0.75, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            // Lock icon (only for premium theme)
            if (data.premium)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: OzHomeColors.bgDeep.withValues(alpha: 0.6),
                    border: Border.all(
                      color: OzHomeColors.gold.withValues(alpha: 0.3),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Text('🔒', style: TextStyle(fontSize: 12)),
                ),
              ),
            // Text (bottom-left)
            Positioned(
              left: 12,
              right: 12,
              bottom: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    data.name,
                    style:
                        OzHomeTypography.cardName(
                          size: 15,
                          color: Colors.white,
                        ).copyWith(
                          shadows: const [
                            Shadow(
                              color: Color(0x80000000),
                              offset: Offset(0, 1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${data.count}개 카테고리',
                    style:
                        OzHomeTypography.monoLabel(
                          size: 10,
                          color: OzHomeColors.gold,
                        ).copyWith(
                          shadows: const [
                            Shadow(
                              color: Color(0x80000000),
                              offset: Offset(0, 1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
//  Primary Button (골드 pill)
// ============================================================
class _OzHomePrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _OzHomePrimaryButton({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(OzHomeRadii.pill),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [OzHomeColors.gold, OzHomeColors.goldDeep],
          ),
          boxShadow: [
            BoxShadow(
              color: OzHomeColors.gold.withValues(alpha: 0.45),
              offset: const Offset(0, 4),
              blurRadius: 14,
            ),
          ],
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: OzHomeTypography.cardName(
                size: 12.5,
              ).copyWith(color: const Color(0xFF2A1A08)),
            ),
            const SizedBox(width: 6),
            const Text(
              '→',
              style: TextStyle(color: Color(0xFF2A1A08), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
