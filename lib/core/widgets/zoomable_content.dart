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
/// 전체화면 뷰는 [InteractiveViewer]로 감싸 핀치줌/더블탭 확대까지
/// 지원하며, 바깥 영역을 탭하거나 우상단 닫기 버튼으로 돌아갈 수 있다.
/// 기존 위젯 트리나 상태 관리 로직은 전혀 건드리지 않고, 결과페이지의
/// 이미지/도식을 이 위젯으로 감싸기만 하면 된다.
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
  /// [버그 수정 — 실기기 신고 "핑거로 확대하면 확대한 상태에서 그대로
  /// 있어야 하는데 바로 원상태로 돌아간다"]
  ///
  /// 원인은 스케일 초기화가 아니라 **확대 화면 자체가 닫히던 것**이었다.
  /// 기존 구현은 배경 전체를 `GestureDetector(behavior: opaque,
  /// onTap: maybePop)`로 덮고 있었다. 핀치(두 손가락)로 확대한 뒤 손가락을
  /// 하나씩 떼는 과정에서 남은 손가락이 배경 탭으로 인식되어 `maybePop()`이
  /// 실행되고, 전체화면 뷰가 사라지면서 사용자에게는 "확대가 원래대로
  /// 되돌아갔다"로 보였다.
  ///
  /// 그래서 다음 세 가지를 지킨다.
  /// 1) [TransformationController]로 변환 행렬을 **상태로 보관**한다.
  ///    핀치가 끝나도(손을 떼도) 배율/위치가 그대로 유지된다. (요구사항:
  ///    "손으로 조절한 확대 크기가 그대로 머물러야 한다")
  /// 2) 핀치 직후 발생하는 오탭은 무시한다. 확대 화면은 **명시적인 동작**
  ///    (닫기 버튼 / 확대 상태에서의 배경 탭 / 더블탭)으로만 원래대로
  ///    돌아간다. (요구사항: "어떤 행동을 취하면 원상으로 돌아와야 한다")
  /// 3) 확대 중에는 "원래대로" 버튼을 노출해 한 번에 100%로 복귀할 수 있게
  ///    한다.
  static const double _minScale = 1.0;
  static const double _maxScale = 5.0;
  static const double _doubleTapScale = 2.5;

  final TransformationController _controller = TransformationController();

  /// 핀치(2손가락 이상) 제스처가 진행 중인지.
  bool _pinching = false;

  /// 현재 화면에 닿아 있는 손가락 수. 2개 이상이면 핀치로 판정한다.
  int _activePointers = 0;

  /// 방금 끝난 제스처가 핀치였는지. 손가락을 하나씩 떼며 발생하는 탭
  /// 이벤트를 배경 탭(닫기)으로 오인하지 않기 위한 플래그.
  bool _gestureWasPinch = false;

  /// 확대 상태 여부의 캐시 — 매 프레임 setState 하는 것을 피하기 위해
  /// 값이 바뀔 때만 리빌드한다.
  bool _zoomed = false;

  double get _currentScale => _controller.value.getMaxScaleOnAxis();

  bool get _isZoomed => _currentScale > 1.02;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTransformChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTransformChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    final zoomed = _isZoomed;
    if (zoomed == _zoomed) return;
    if (!mounted) return;
    setState(() => _zoomed = zoomed);
  }

  /// 배율/위치를 100%(원본)로 되돌린다.
  void _resetZoom() {
    _controller.value = Matrix4.identity();
  }

  /// 더블탭 — 탭한 지점을 기준으로 확대/원복 토글.
  void _handleDoubleTap(Offset localPosition) {
    if (_isZoomed) {
      _resetZoom();
      return;
    }
    final scale = _doubleTapScale.clamp(_minScale, _maxScale);
    // p 를 중심으로 scale 배 확대: T(p) · S · T(-p)
    final matrix = Matrix4.identity()
      ..setEntry(0, 0, scale)
      ..setEntry(1, 1, scale)
      ..setEntry(0, 3, localPosition.dx * (1 - scale))
      ..setEntry(1, 3, localPosition.dy * (1 - scale));
    _controller.value = matrix;
  }

  /// 배경 탭 — 확대 중이면 먼저 원복하고, 원본 상태에서만 화면을 닫는다.
  void _handleBackgroundTap() {
    if (_pinching || _gestureWasPinch) return;
    if (_isZoomed) {
      _resetZoom();
      return;
    }
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _handleBackgroundTap,
            ),
          ),
          Center(
            child: Hero(
              tag: widget.heroTag,
              // [버그 수정 — APK 실기기 5차 신고 "결과 페이지에서
              // 확대기능 조금밖에 안됨"] InteractiveViewer의 기본
              // boundaryMargin은 EdgeInsets.zero다 — 콘텐츠를 원본 크기
              // (이미 화면에 꽉 맞게 패딩된 상태) 밖으로는 전혀 팬(이동)
              // 할 수 없다는 뜻이다. 그 결과 손가락으로 확대(스케일 자체는
              // 5배까지 걸림)는 되지만, 확대된 상태에서 좌우/상하로 이동해
              // 다른 부분을 보려고 하면 경계에 막혀 거의 움직이지 않아
              // "확대가 조금밖에 안 되는 것"처럼 체감된다. boundaryMargin을
              // 넉넉하게 주어 확대 후 이미지/도식의 가장자리까지 자유롭게
              // 이동해서 볼 수 있도록 한다(minScale/maxScale 범위는 기존과
              // 동일하게 유지 — 이미 충분히 넓은 0.8~5배였다).
              child: Listener(
                // [중요] 제스처 인식기(GestureDetector)가 아니라 Listener를 쓴다.
                // GestureDetector로 감싸면 바깥쪽이 핀치(scale) 제스처를
                // 제스처 아레나에서 먼저 가로채 InteractiveViewer에 전달되지
                // 않아 확대 자체가 동작하지 않는다(실기기 신고로 확인된 회귀).
                // Listener는 로우레벨 포인터 이벤트만 관찰하고 아레나에
                // 참여하지 않으므로 InteractiveViewer의 핀치/팬을 전혀
                // 방해하지 않는다.
                onPointerDown: (_) {
                  _activePointers++;
                  if (_activePointers >= 2) {
                    _pinching = true;
                    _gestureWasPinch = true;
                  }
                },
                onPointerUp: (_) {
                  _activePointers = (_activePointers - 1).clamp(0, 10);
                  if (_activePointers == 0) {
                    _pinching = false;
                    // 핀치 후 손가락을 모두 뗀 직후 뒤따르는 탭 이벤트를
                    // 흡수해 배경 탭(닫기)으로 오인하지 않게 한다.
                    if (_gestureWasPinch) {
                      Future<void>.delayed(
                        const Duration(milliseconds: 300),
                        () {
                          _gestureWasPinch = false;
                        },
                      );
                    }
                  }
                },
                onPointerCancel: (_) {
                  _activePointers = (_activePointers - 1).clamp(0, 10);
                  if (_activePointers == 0) _pinching = false;
                },
                child: InteractiveViewer(
                  transformationController: _controller,
                  minScale: _minScale,
                  maxScale: _maxScale,
                  // [이전 버그 수정 유지 — APK 실기기 5차 신고 "확대기능
                  // 조금밖에 안됨"] boundaryMargin 기본값(EdgeInsets.zero)이면
                  // 확대 후 팬(이동)이 경계에 막힌다. 넉넉하게 준다.
                  boundaryMargin: const EdgeInsets.all(400),
                  // 핀치가 끝나도 변환 상태를 그대로 유지한다(리셋 금지).
                  // TransformationController가 상태를 보관하므로 손을 떼도
                  // 배율/위치가 유지된다.
                  panEnabled: true,
                  scaleEnabled: true,
                  child: GestureDetector(
                    // [더블탭 — 확대/원복 토글]
                    // Tab 인식기만 등록한다(scale 인식기를 등록하면
                    // InteractiveViewer의 핀치와 아레나에서 충돌하므로 금지).
                    // onDoubleTapDown 위치를 기준으로 그 지점을 중심으로
                    // 확대하고, 이미 확대 상태면 100%로 되돌린다.
                    behavior: HitTestBehavior.translucent,
                    onDoubleTapDown: (details) {
                      _handleDoubleTap(details.localPosition);
                    },
                    onDoubleTap: () {},
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: widget.builder(context),
                    ),
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // [추가] 확대 상태일 때만 "원래대로" 버튼 노출.
                    // 확대 배율은 손을 떼도 유지되므로, 사용자가 원할 때
                    // 명시적으로 100%로 되돌릴 수단을 제공한다.
                    AnimatedOpacity(
                      opacity: _zoomed ? 1 : 0,
                      duration: const Duration(milliseconds: 160),
                      child: IgnorePointer(
                        ignoring: !_zoomed,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TextButton.icon(
                            onPressed: _resetZoom,
                            icon: const Icon(
                              Icons.zoom_out_map_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                            label: const Text(
                              '원래대로',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.black.withValues(
                                alpha: 0.45,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Text(
                      _zoomed
                          ? '두 손가락으로 이동 · 더블탭으로 원래대로'
                          : '두 손가락으로 확대/축소할 수 있어요',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 12,
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
