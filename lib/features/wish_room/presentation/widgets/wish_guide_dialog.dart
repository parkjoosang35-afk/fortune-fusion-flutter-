import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/guide_slide_model.dart';
import '../providers/wish_room_providers.dart';
import '../theme/wish_room_theme.dart';
import 'wish_room_animations.dart';

/// [소원방 가이드] 사용 방법 안내 — 풀스크린 슬라이드형.
///
/// [전면 재구현 배경] 기존 구현은 `Dialog` 안에 5단계 문구를 하드코딩한
/// 세로 목록이었다(§ "관리자 설정값 하드코딩 금지" 원칙 위반 소지 —
/// 문구를 CMS가 아니라 클라이언트 코드에 직접 박아둔 상태). 이제는
/// [guideSlidesProvider]를 통해 관리자 CMS가 편집한 슬라이드 목록
/// (`GET /api/wish-room/guide`)을 받아, 온보딩과 동일한 풀스크린
/// PageView(페이지 인디케이터 + 스킵 + 마지막 페이지 "시작하기") 형태로
/// 보여준다. 슬라이드 이미지(`imageUrl`)가 있으면 상단에 표시하고, 없으면
/// 카테고리 이모지 대신 심플한 별 아이콘으로 대체한다(placeholder 없이
/// 항상 완결된 화면을 보여줘야 하므로).
class WishGuideDialog extends ConsumerStatefulWidget {
  const WishGuideDialog({super.key});

  /// 기존 호출부(`WishGuideDialog.show(context)`)와 100% 동일한 시그니처를
  /// 유지한다 — Dialog 대신 풀스크린 모달 라우트로 띄우도록 내부만
  /// 바꿨으므로 wish_room_screen.dart 등 호출측 코드는 변경할 필요가 없다.
  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push<void>(
      PageRouteBuilder(
        opaque: false,
        barrierColor: WishRoomColors.backgroundDeep,
        transitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, __, ___) => const WishGuideDialog(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  ConsumerState<WishGuideDialog> createState() => _WishGuideDialogState();
}

class _WishGuideDialogState extends ConsumerState<WishGuideDialog> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  void _next(int slideCount) {
    if (_index >= slideCount - 1) {
      _close();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncSlides = ref.watch(guideSlidesProvider);

    return Scaffold(
      backgroundColor: WishRoomColors.backgroundDeep,
      body: SafeArea(
        child: asyncSlides.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: WishRoomColors.gold),
          ),
          // [네트워크 오류 방어] 서버에서 가이드를 못 받아와도 화면이
          // 완전히 막히지 않도록 최소한의 안내와 닫기 버튼을 제공한다
          // (§ "placeholder/TODO/coming soon 없이 완전 동작" 원칙 —
          // 빈 화면이 아니라 재시도 가능한 정상 화면을 보여준다).
          error: (err, st) => _ErrorState(onClose: _close, onRetry: () {
            ref.invalidate(guideSlidesProvider);
          }),
          data: (slides) {
            if (slides.isEmpty) {
              return _ErrorState(
                onClose: _close,
                onRetry: () => ref.invalidate(guideSlidesProvider),
              );
            }
            return _SlideBody(
              slides: slides,
              controller: _controller,
              index: _index,
              onIndexChanged: (i) => setState(() => _index = i),
              onSkip: _close,
              onNext: () => _next(slides.length),
            );
          },
        ),
      ),
    );
  }
}

class _SlideBody extends StatelessWidget {
  const _SlideBody({
    required this.slides,
    required this.controller,
    required this.index,
    required this.onIndexChanged,
    required this.onSkip,
    required this.onNext,
  });

  final List<GuideSlide> slides;
  final PageController controller;
  final int index;
  final ValueChanged<int> onIndexChanged;
  final VoidCallback onSkip;
  final VoidCallback onNext;

  bool get _isLast => index == slides.length - 1;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: WishRoomSpacing.sm,
            ),
            child: TextButton(
              onPressed: onSkip,
              child: Text(
                '건너뛰기',
                style: WishRoomTextStyles.bodySm.copyWith(
                  color: WishRoomColors.textTertiary,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: PageView.builder(
            controller: controller,
            itemCount: slides.length,
            onPageChanged: onIndexChanged,
            itemBuilder: (context, i) => _SlidePage(slide: slides[i]),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            slides.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: index == i ? 22 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: index == i
                    ? WishRoomColors.gold
                    : WishRoomColors.surfaceCardBorder,
                borderRadius: BorderRadius.circular(WishRoomRadius.pill),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(WishRoomSpacing.lg),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: WishRoomColors.gold,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(WishRoomRadius.pill),
                ),
              ),
              onPressed: onNext,
              child: Text(
                _isLast ? '시작하기' : '다음',
                style: WishRoomTextStyles.ctaLabel,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SlidePage extends StatelessWidget {
  const _SlidePage({required this.slide});

  final GuideSlide slide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: WishRoomSpacing.xl,
        vertical: WishRoomSpacing.lg,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FadeSlideIn(
            duration: const Duration(milliseconds: 500),
            child: slide.imageUrl != null && slide.imageUrl!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(WishRoomRadius.lg),
                    child: Image.network(
                      slide.imageUrl!,
                      height: 220,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const _SlideIconFallback(),
                    ),
                  )
                : const _SlideIconFallback(),
          ),
          const SizedBox(height: WishRoomSpacing.xl),
          FadeSlideIn(
            delay: const Duration(milliseconds: 100),
            duration: const Duration(milliseconds: 450),
            child: Text(
              slide.title,
              style: WishRoomTextStyles.titleLg,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: WishRoomSpacing.md),
          FadeSlideIn(
            delay: const Duration(milliseconds: 180),
            duration: const Duration(milliseconds: 450),
            child: Text(
              slide.body,
              style: WishRoomTextStyles.bodyMd,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _SlideIconFallback extends StatelessWidget {
  const _SlideIconFallback();

  @override
  Widget build(BuildContext context) {
    return BreathingGlow(
      glowColor: WishRoomColors.gold,
      borderRadius: 60,
      minAlpha: 0.1,
      maxAlpha: 0.3,
      blurRadius: 30,
      child: Container(
        width: 120,
        height: 120,
        decoration: const BoxDecoration(
          gradient: WishRoomColors.objectGlowGradient,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.auto_awesome_rounded,
          color: WishRoomColors.gold,
          size: 48,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onClose, required this.onRetry});

  final VoidCallback onClose;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(WishRoomSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: WishRoomColors.textTertiary,
              size: 40,
            ),
            const SizedBox(height: WishRoomSpacing.md),
            Text(
              '가이드를 불러오지 못했어요',
              style: WishRoomTextStyles.bodyMd,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: WishRoomSpacing.lg),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: onClose,
                  child: Text(
                    '닫기',
                    style: WishRoomTextStyles.bodySm.copyWith(
                      color: WishRoomColors.textTertiary,
                    ),
                  ),
                ),
                const SizedBox(width: WishRoomSpacing.sm),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: WishRoomColors.gold,
                  ),
                  onPressed: onRetry,
                  child: Text('다시 시도', style: WishRoomTextStyles.ctaLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
