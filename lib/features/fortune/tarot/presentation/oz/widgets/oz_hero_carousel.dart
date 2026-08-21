import 'dart:async';
import 'package:flutter/material.dart';
import '../oz_category_illustrations.dart';
import '../oz_theme.dart';
import 'oz_primary_button.dart';

/// [타로 오즈 리스킨 · 화면01 HOME] 히어로 캐러셀. CSS 대응: .oz-hero-card.
///
/// 5초 간격 자동 스와이프(매핑표.md 애니메이션 스펙 표 준수) + 하단 dot
/// 인디케이터. 슬라이드 데이터는 [OzCategoryIllustrations.heroSlides]
/// (3장, 실제 앱 카테고리 id와 연결됨)에서 가져온다.
class OzHeroCarousel extends StatefulWidget {
  final ValueChanged<String> onSlideTap;
  const OzHeroCarousel({super.key, required this.onSlideTap});

  @override
  State<OzHeroCarousel> createState() => _OzHeroCarouselState();
}

class _OzHeroCarouselState extends State<OzHeroCarousel> {
  final _controller = PageController();
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      final next = (_index + 1) % OzCategoryIllustrations.heroSlides.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slides = OzCategoryIllustrations.heroSlides;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        OzTokens.spaceLg,
        OzTokens.spaceSm,
        OzTokens.spaceLg,
        0,
      ),
      child: SizedBox(
        height: 260,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(OzTokens.radiusXxl),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: OzColors.borderStrong),
                  boxShadow: OzColors.cardElevation(),
                ),
                child: PageView.builder(
                  controller: _controller,
                  itemCount: slides.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) {
                    final slide = slides[i];
                    return _HeroSlide(
                      slide: slide,
                      onCtaTap: () => widget.onSlideTap(slide.categoryId),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 14,
              right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: OzColors.bgDeep.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(OzTokens.radiusPill),
                ),
                child: Row(
                  children: List.generate(slides.length, (i) {
                    final active = i == _index;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 2.5),
                      width: active ? 16 : 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: active
                            ? OzColors.gold
                            : OzColors.fg.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(OzTokens.radiusPill),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroSlide extends StatelessWidget {
  final OzHeroSlide slide;
  final VoidCallback onCtaTap;
  const _HeroSlide({required this.slide, required this.onCtaTap});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(slide.image, fit: BoxFit.cover),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                OzColors.bgMid.withValues(alpha: 0),
                OzColors.bgMid.withValues(alpha: 0.55),
                OzColors.bgDeep.withValues(alpha: 0.92),
              ],
              stops: const [0.3, 0.65, 1.0],
            ),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(slide.tag, style: OzTypography.monoLabel(letterSpacing: 3)),
              const SizedBox(height: 6),
              Text(
                slide.title,
                style: OzTypography.hero(fontSize: 22, color: Colors.white),
              ),
              const SizedBox(height: 14),
              OzPillButton(label: slide.cta, onPressed: onCtaTap),
            ],
          ),
        ),
      ],
    );
  }
}
