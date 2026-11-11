import 'package:flutter/material.dart';

/// [확대 기능 — 결과페이지 전체 적용] 모든 결과 화면에서 공용으로 쓰는
/// "탭하면 전체화면으로 크게 보기" 위젯.
///
/// 사용 패턴은 두 가지다.
/// 1) 이미지 썸네일 등 [child]를 그대로 확대해도 되는 경우 → [child]만
///    넘기면 전체화면에서도 동일 위젯을 더 크게(화면 폭 기준) 그려준다.
/// 2) CustomPaint 기반 도식(사주 팔괘/기둥/오행 바 등)처럼 작은 썸네일을
///    그대로 키우면 좌표가 깨지는 경우 → [fullScreenBuilder]로 "더 큰
///    사이즈 파라미터로 다시 그린" 위젯을 별도로 전달한다.
///
/// [신통방통 전역 핀치 확대 시스템 통합 — 개별 확대 제거] 과거 이
/// 위젯은 전체화면 뷰를 자체 [InteractiveViewer](0.8~5배)로 감싸 "이
/// 화면에서만" 핀치줌을 지원했다. 지시서 §1 "개별 이미지/화면별 확대
/// 방식은 금지한다 — 어떤 화면에서도 동일한 핀치 확대가 작동해야 한다"
/// 에 따라 이 개별 InteractiveViewer를 제거했다. "탭하면 전체화면으로
/// 전환"되는 Hero 네비게이션 자체는 확대가 아니라 "더 큰 사이즈로 다시
/// 보여주는" 별개의 UX이므로 그대로 보존한다 — 전체화면에 진입한
/// 뒤에는 `app.dart`의 `MaterialApp.builder`에 전역 삽입된
/// `GlobalPinchZoomOverlay`가 다른 모든 화면과 동일하게 두 손가락 핀치
/// 확대/축소를 자동으로 제공한다(이 위젯이 별도로 구현할 필요가 없다).
class ZoomableContent extends StatelessWidget {
  const ZoomableContent({
    super.key,
    required this.child,
    this.heroTag,
    this.fullScreenBuilder,
    this.backgroundColor = Colors.black,
    this.borderRadius,
    this.enabled = true,
  });

  /// 화면에 보통 크기로 표시되는 위젯(썸네일/작은 카드 등).
  final Widget child;

  /// Hero 전환 태그. 지정하지 않으면 전환 애니메이션 없이 바로 전체화면으로
  /// 전환한다(동일 화면에 같은 heroTag를 가진 위젯이 여러 개 있을 때
  /// 충돌을 피하려면 null로 두고 호출부에서 고유 태그를 넘기는 쪽을
  /// 권장한다).
  final Object? heroTag;

  /// 전체화면에 표시할 "더 큰" 버전을 별도로 그리고 싶을 때 사용한다.
  /// null이면 [child]를 그대로 확대해서 보여준다.
  final WidgetBuilder? fullScreenBuilder;

  /// 전체화면 뒷배경 색.
  final Color backgroundColor;

  /// [child] 자체에 적용할 모서리 반경(탭 영역의 InkWell 리플에도 사용).
  final BorderRadius? borderRadius;

  /// false면 확대 기능을 끄고 [child]만 그대로 렌더링한다(예: 데이터가
  /// 아직 없을 때).
  final bool enabled;

  void _open(BuildContext context) {
    final tag = heroTag ?? UniqueKey();
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: backgroundColor.withValues(alpha: 0.94),
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: _ZoomableFullScreenView(
            heroTag: tag,
            backgroundColor: backgroundColor,
            builder: fullScreenBuilder ?? (_) => child,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    final tag = heroTag;
    final content = Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: () => _open(context),
        child: child,
      ),
    );
    if (tag == null) return content;
    // 원본 child에는 Hero를 바로 씌우지 않는다(탭 영역에 InkWell 리플이
    // 필요하므로 Hero는 content 전체를 감싼다).
    return Hero(
      tag: tag,
      flightShuttleBuilder: (_, animation, __, ___, toContext) =>
          FadeTransition(opacity: animation, child: toContext.widget),
      child: content,
    );
  }
}

class _ZoomableFullScreenView extends StatelessWidget {
  const _ZoomableFullScreenView({
    required this.heroTag,
    required this.backgroundColor,
    required this.builder,
  });

  final Object heroTag;
  final Color backgroundColor;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
          Center(
            child: Hero(
              tag: heroTag,
              // [전역 핀치 확대 시스템 통합] 과거 여기 있던 개별
              // InteractiveViewer(0.8~5배)는 제거했다. 이 화면도 전역
              // GlobalPinchZoomOverlay 아래에서 렌더링되므로, 두 손가락
              // 핀치로 똑같이 확대/축소할 수 있다 — 개별 구현 불필요.
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: builder(context),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: SafeArea(
              child: IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.35),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Center(
                child: Text(
                  '손가락으로 확대/축소할 수 있어요',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 12,
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

/// 이미지 전용 간편 래퍼. [assetPath]의 작은 썸네일을 [child]로 보여주고,
/// 탭하면 같은 에셋(또는 [fullAssetPath]로 지정한 고해상도 버전)을
/// 화면 폭 기준으로 더 크게 그려 핀치줌 가능한 전체화면으로 연다.
class ZoomableAssetImage extends StatelessWidget {
  const ZoomableAssetImage({
    super.key,
    required this.assetPath,
    required this.child,
    this.fullAssetPath,
    this.heroTag,
    this.borderRadius,
    this.enabled = true,
  });

  final String assetPath;
  final String? fullAssetPath;
  final Widget child;
  final Object? heroTag;
  final BorderRadius? borderRadius;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ZoomableContent(
      heroTag: heroTag,
      borderRadius: borderRadius,
      enabled: enabled,
      fullScreenBuilder: (_) => Image.asset(
        fullAssetPath ?? assetPath,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => child,
      ),
      child: child,
    );
  }
}
