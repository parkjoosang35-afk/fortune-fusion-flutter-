import 'package:flutter/material.dart';

/// [확대 기능 — 결과페이지 전체 적용] 모든 결과 화면에서 공용으로 쓰는
/// "탭하면 전체화면으로 확대 + 핀치줌" 위젯.
///
/// 사용 패턴은 두 가지다.
/// 1) 이미지 썸네일 등 [child]를 그대로 확대해도 되는 경우 → [child]만
///    넘기면 전체화면에서도 동일 위젯을 더 크게(화면 폭 기준) 그려준다.
/// 2) CustomPaint 기반 도식(사주 팔괘/기둥/오행 바 등)처럼 작은 썸네일을
///    그대로 키우면 좌표가 깨지는 경우 → [fullScreenBuilder]로 "더 큰
///    사이즈 파라미터로 다시 그린" 위젯을 별도로 전달한다.
///
/// 전체화면 뷰는 [InteractiveViewer]로 감싸 핀치줌을 지원하며, 우상단
/// 닫기 버튼 또는 확대 상태에서 나타나는 '원래대로' 버튼으로 조작한다.
///
/// ───────────────────────────────────────────────────────────────────
/// [중요 — 절대 되돌리지 말 것]
/// 이 파일의 전체화면 뷰에서 [InteractiveViewer]를 **어떤 제스처 위젯으로도
/// 감싸면 안 된다.** GestureDetector(onScale*) / GestureDetector(onDoubleTap) /
/// Listener+GestureDetector 조합을 씌우면 Flutter 제스처 아레나에서 바깥
/// 위젯이 승리해 핀치 이벤트가 InteractiveViewer에 도달하지 못하고
/// **확대가 아예 동작하지 않는다.** (실제로 이 방식으로 두 번 회귀를 냈다.)
/// 배경 탭으로 닫는 기능도 넣지 않는다 — 핀치 후 손가락을 하나씩 떼는
/// 과정의 잔여 탭이 배경 탭으로 인식되면 화면이 닫혀 사용자에게는
/// "확대가 원래대로 돌아갔다"로 보인다. 닫기는 X 버튼으로만.
/// ───────────────────────────────────────────────────────────────────
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
    return Hero(
      tag: tag,
      flightShuttleBuilder: (_, animation, __, ___, toContext) =>
          FadeTransition(opacity: animation, child: toContext.widget),
      child: content,
    );
  }
}

class _ZoomableFullScreenView extends StatefulWidget {
  const _ZoomableFullScreenView({
    required this.heroTag,
    required this.backgroundColor,
    required this.builder,
  });

  final Object heroTag;
  final Color backgroundColor;
  final WidgetBuilder builder;

  @override
  State<_ZoomableFullScreenView> createState() =>
      _ZoomableFullScreenViewState();
}

class _ZoomableFullScreenViewState extends State<_ZoomableFullScreenView> {
  /// 사용자가 직접 조절한 확대 배율을 그대로 유지하는 컨트롤러.
  /// (InteractiveViewer가 내부적으로 들고 있는 행렬을 우리가 읽기만 한다 —
  ///  이 컨트롤러를 넘기는 것 자체는 제스처 동작에 아무 영향이 없다.)
  final TransformationController _controller = TransformationController();

  bool _zoomed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 확대/이동이 "끝난 뒤"에만 배율을 확인한다(제스처 도중 setState 금지).
  void _onInteractionEnd(ScaleEndDetails _) {
    final scale = _controller.value.getMaxScaleOnAxis();
    final zoomed = scale > 1.01;
    if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
  }

  /// 명시적인 사용자 조작(버튼)으로만 원래대로 되돌린다.
  void _resetZoom() {
    setState(() => _controller.value = Matrix4.identity());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // [의도적으로 배경 탭 닫기 없음]
          // 원본에는 여기에 GestureDetector(behavior: opaque, onTap: pop)가
          // 있었는데, 핀치 확대 후 손가락을 하나씩 떼면 그 잔여 탭이 이
          // 배경 탭으로 인식되어 전체화면이 닫혀버렸다(= "확대가 원래대로
          // 돌아감"). 그래서 배경 닫기를 제거하고 X 버튼만 남겼다.
          //
          // [핵심 수정 2 — 실기기 신고 "확대가 아예 안 된다"의 진짜 원인]
          // 예전에는 InteractiveViewer가 Center 안에 있어 **콘텐츠 크기만큼만**
          // 차지했다. 실제 사용자는 두 손가락을 콘텐츠 픽셀 위에 정확히
          // 올리지 않고, 하나는 여백에 찍히는 경우가 흔하다. 그 순간 두 번째
          // 손가락이 InteractiveViewer의 hit-test 영역 밖이라 핀치가 성립하지
          // 않았다. Positioned.fill + SizedBox.expand 로 InteractiveViewer가
          // **화면 전체**를 덮게 해서 어디를 짚어도 핀치가 되게 한다.
          Positioned.fill(
            child: Hero(
              tag: widget.heroTag,
              child: InteractiveViewer(
                transformationController: _controller,
                minScale: 0.8,
                maxScale: 5,
                // [이전 버그 수정 유지 — APK 실기기 5차 신고 "확대기능
                // 조금밖에 안됨"] boundaryMargin 기본값(EdgeInsets.zero)이면
                // 확대 후 팬(이동)이 경계에 막힌다. 넉넉하게 준다.
                boundaryMargin: const EdgeInsets.all(400),
                panEnabled: true,
                scaleEnabled: true,
                onInteractionEnd: _onInteractionEnd,
                // InteractiveViewer를 화면 전체로 강제 확장하고,
                // 실제 콘텐츠는 가운데 정렬한다(보이는 모습은 동일).
                child: SizedBox.expand(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: widget.builder(context),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // 확대된 상태에서만 나타나는 '원래대로' 버튼.
          // 이 버튼은 Stack의 별도 레이어라 InteractiveViewer의 제스처와
          // 전혀 무관하다(겹치지도 않는다).
          if (_zoomed)
            Positioned(
              bottom: 64,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Center(
                  child: TextButton.icon(
                    onPressed: _resetZoom,
                    icon: const Icon(
                      Icons.zoom_out_map_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                    label: const Text(
                      '원래대로',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.5),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: const StadiumBorder(),
                    ),
                  ),
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
                child: IgnorePointer(
                  child: Text(
                    _zoomed
                        ? '두 손가락으로 이동 · X 버튼으로 닫기'
                        : '두 손가락으로 확대/축소할 수 있어요',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 12,
                    ),
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
