import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'pinch_zoom_boundary_controller.dart';
import 'pinch_zoom_exclusion.dart';
import 'pinch_zoom_gesture_controller.dart';
import 'pinch_zoom_render_controller.dart';
import 'pinch_zoom_transform_controller.dart';

/// [신통방통 전역 핀치 확대 시스템 — 통합 매니저]
///
/// `MaterialApp.builder`에 한 번만 끼워 넣으면, 그 아래 전체 화면(모든
/// 라우트, 팝업, 모달 포함)에서 "두 손가락을 벌리면 확대, 모으면 축소,
/// 기본 1배/최대 3배"가 동일하게 동작한다. 개별 화면이나 위젯은 이
/// 매니저의 존재를 전혀 몰라도 되며, 어떤 화면에도 `InteractiveViewer`를
/// 중복으로 추가할 필요가 없다(지시서 §7 "모든 화면에 무조건
/// InteractiveViewer를 중복 적용하는 방식은 금지한다" 요구사항).
///
/// ## 동작 방식 요약(상세 이유는 각 컨트롤러 파일의 문서 참고)
/// 1. [PinchGestureListener]가 전역에서 포인터 개수만 조용히 관찰한다
///    (제스처 아레나 비참여 — 1손가락 스크롤/탭은 100% 그대로 유지).
/// 2. 2번째 손가락이 닿는 순간 [PinchZoomRenderController]가 현재 화면을
///    고해상도로 캡처한다.
/// 3. 캡처된 이미지를 전체화면 오버레이로 띄우고, 두 손가락 거리/중점
///    변화를 [PinchZoomTransformController]로 scale/translation으로
///    변환해 [Transform]에 적용한다.
/// 4. [PinchZoomBoundaryController]가 이동값을 화면 경계 안으로 제한한다.
/// 5. 손가락을 하나라도 떼면 오버레이가 즉시 사라지고 원래 화면으로
///    복귀하며, 캡처 리소스는 즉시 dispose된다.
///
/// 결제/광고(AdMob WebView 등 네이티브 플랫폼 뷰)나 귀인지도 그래프처럼
/// 이미 독자적인 2손가락 의미를 가진 영역은 [PinchZoomDisabled]로 감싸
/// 이 매니저의 감시 대상에서 제외한다(지시서 §6 "광고 및 결제 기능과
/// 확대 엔진 분리" 요구사항).
class GlobalPinchZoomOverlay extends StatefulWidget {
  const GlobalPinchZoomOverlay({
    super.key,
    required this.child,
    this.minScale = 1.0,
    this.maxScale = 3.0,
  });

  final Widget child;
  final double minScale;
  final double maxScale;

  @override
  State<GlobalPinchZoomOverlay> createState() =>
      _GlobalPinchZoomOverlayState();
}

class _GlobalPinchZoomOverlayState extends State<GlobalPinchZoomOverlay> {
  final GlobalKey _boundaryKey = GlobalKey();
  late final PinchZoomTransformController _transformController;
  final _boundaryController = const PinchZoomBoundaryController();
  late final PinchZoomRenderController _renderController;

  ui.Image? _capturedImage;
  PinchZoomTransform _transform = PinchZoomTransform.identity;
  bool _zooming = false;
  Size _viewportSize = Size.zero;

  // [버그 수정 — "확대 후 손을 떼면 제자리로 돌아가는" 문제의 핵심 상태]
  // 과거엔 손가락을 떼는 순간(onPinchEnd) 무조건 1배로 애니메이션
  // 복귀시켰다. 이제는 손을 뗀 뒤에도 확대된 상태를 그대로 "유지"하고,
  // 아래 두 가지 방법으로만 닫히도록 바꾼다:
  //   1) 유지된 확대 화면을 다시 탭(짧게 눌렀다 뗌) → 원본으로 복귀
  //   2) 유지된 상태에서 다시 두 손가락으로 모아 배율을 1배 근처까지
  //      줄인 뒤 손을 뗌 → 원본으로 복귀
  // [_held]는 "핀치는 끝났지만 확대 상태가 화면에 유지 중"임을 뜻한다.
  bool _held = false;

  // 유지 상태에서 한 손가락 드래그로 화면을 이동(pan)하기 위한 직전 좌표.
  Offset? _panLastPos;
  // 탭(제자리 터치)인지 드래그(이동)인지 구분하기 위한 시작 좌표/이동 플래그.
  Offset? _singleStartPos;
  bool _singleMoved = false;
  // [핵심 버그 수정] 지금 추적 중인 단일 손가락이 "방금 핀치가 끝나며
  // 남은 손가락"인지 여부. true인 동안에는 그 손가락이 곧바로 떨어져도
  // "탭"으로 간주해 닫지 않는다 — 실기기에서 두 손가락을 거의 동시에
  // 떼면 한쪽이 몇 ms 먼저 이벤트가 들어와 "핀치 종료 직후 남은 손가락이
  // 즉시 탭으로 오인되어 확대가 도로 닫히는" 버그가 있었다.
  bool _singleIsPinchLeftover = false;

  // 이 값보다 이동 거리가 작으면 "탭"으로 간주해 확대를 닫는다.
  static const double _tapSlop = 12.0;
  // 핀치를 끝냈을 때 이 배율 이하이면 "사실상 확대 안 한 것"으로 보고
  // 자동으로 원본에 닫는다(살짝 모았다 뗀 경우 어정쩡하게 유지되는
  // 어색함 방지).
  static const double _autoCloseScaleThreshold = 1.04;

  @override
  void initState() {
    super.initState();
    _transformController = PinchZoomTransformController(
      minScale: widget.minScale,
      maxScale: widget.maxScale,
    );
    _renderController = PinchZoomRenderController();
  }

  @override
  void dispose() {
    _renderController.dispose();
    super.dispose();
  }

  Future<void> _onPinchStart(Offset posA, Offset posB) async {
    // [안정성] 2손가락이 광고/웹뷰/귀인지도 그래프 등 제외 구역 위에서
    // 시작되면 전역 확대를 아예 켜지 않는다 — "광고 및 결제 기능과 확대
    // 엔진 분리" + "화면별 제스처 충돌" 요구사항.
    // (단, 이미 확대가 유지 중(_held)인 상태에서 다시 핀치하는 경우는
    // 제외 구역 판정을 다시 하지 않는다 — 이미 전역 확대가 활성화된
    // 세션을 이어가는 것이므로.)
    if (!_held) {
      final midpoint = Offset.lerp(posA, posB, 0.5)!;
      if (PinchZoomExclusionRegistry.instance.isExcluded(midpoint)) {
        return;
      }
    }

    final renderBox =
        _boundaryKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;
    _viewportSize = renderBox.size;

    // 유지 상태에서 다시 핀치할 때는 한 손가락 팬(pan) 상태를 종료한다.
    _panLastPos = null;
    _singleStartPos = null;
    _singleMoved = false;
    _singleIsPinchLeftover = false;

    final dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1.0;
    final image = await _renderController.capture(
      _boundaryKey,
      devicePixelRatio: dpr,
    );
    if (image == null || !mounted) return;

    _transformController.start(posA, posB);
    setState(() {
      _capturedImage = image;
      _zooming = true;
      _held = false;
      _transform = _transformController.value;
    });
  }

  void _onPinchUpdate(Offset posA, Offset posB) {
    if (!_zooming) return;
    _transformController.update(posA, posB);
    final clampedOffset = _boundaryController.clamp(
      translation: _transformController.translation,
      viewportSize: _viewportSize,
      scale: _transformController.scale,
    );
    _transformController.setTranslation(clampedOffset);
    setState(() {
      _transform = PinchZoomTransform(
        scale: _transformController.scale,
        offset: clampedOffset,
      );
    });
  }

  void _onPinchEnd() {
    if (!_zooming) return;
    if (_transformController.scale <= _autoCloseScaleThreshold) {
      // 사실상 확대하지 않고 손을 뗀 경우 — 바로 원본으로 복귀.
      _animateReset();
      return;
    }
    // [핵심 수정] 더 이상 자동으로 1배로 되돌리지 않는다 — 확대된 상태
    // 그대로 화면에 유지한다("_held"). 오버레이와 캡처 이미지는 계속
    // 떠 있고, 사용자가 한 손가락으로 이동하거나 탭해서 닫을 때까지
    // 유지된다.
    setState(() {
      _held = true;
    });
  }

  // 유지된 확대 상태에서 한 손가락 입력이 시작될 때.
  void _onSingleDown(Offset pos, {required bool isPinchContinuation}) {
    if (!_zooming || !_held) return;
    _panLastPos = pos;
    _singleStartPos = pos;
    _singleMoved = false;
    _singleIsPinchLeftover = isPinchContinuation;
  }

  // 유지된 확대 상태에서 한 손가락을 이동할 때 — 화면 이동(pan).
  void _onSingleMove(Offset pos) {
    if (!_zooming || !_held || _panLastPos == null) return;
    final delta = pos - _panLastPos!;
    if ((pos - (_singleStartPos ?? pos)).distance > _tapSlop) {
      _singleMoved = true;
    }
    _transformController.panBy(delta);
    final clampedOffset = _boundaryController.clamp(
      translation: _transformController.translation,
      viewportSize: _viewportSize,
      scale: _transformController.scale,
    );
    _transformController.setTranslation(clampedOffset);
    setState(() {
      _transform = PinchZoomTransform(
        scale: _transformController.scale,
        offset: clampedOffset,
      );
    });
    _panLastPos = pos;
  }

  // 유지된 확대 상태에서 손가락을 뗄 때 — 이동 없이 뗐다면(탭) 닫는다.
  // 단, 그 손가락이 "방금 핀치가 끝나며 남은 손가락"(_singleIsPinchLeftover)
  // 이었다면 탭으로 간주하지 않는다 — 실기기에서 두 손가락을 거의 동시에
  // 떼는 지극히 흔한 경우에 확대가 곧바로 닫혀버리는 버그를 막는다.
  void _onSingleUp() {
    if (!_zooming || !_held) return;
    final wasTap = !_singleMoved && !_singleIsPinchLeftover;
    _panLastPos = null;
    _singleStartPos = null;
    _singleMoved = false;
    _singleIsPinchLeftover = false;
    if (wasTap) {
      _animateReset();
    }
  }

  void _animateReset() {
    const duration = Duration(milliseconds: 180);
    final startTransform = _transform;
    final ticker = _ResetTicker(
      duration: duration,
      onTick: (t) {
        if (!mounted) return;
        setState(() {
          _transform = PinchZoomTransform(
            scale: ui.lerpDouble(startTransform.scale, 1.0, t)!,
            offset: Offset.lerp(startTransform.offset, Offset.zero, t)!,
          );
        });
      },
      onDone: () {
        if (!mounted) return;
        setState(() {
          _zooming = false;
          _held = false;
          _capturedImage = null;
          _transform = PinchZoomTransform.identity;
        });
        _transformController.reset();
      },
    );
    ticker.start();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 실제 앱 화면 — RepaintBoundary로 감싸 toImage() 캡처 대상이
        // 되도록 한다. 평상시에는 이 레이어만 보이며, 핀치 확대 중에는
        // 아래 오버레이가 그 위를 덮는다(원본 트리 자체는 계속 그대로
        // 존재하므로 스크롤 위치 등 상태가 전혀 영향받지 않는다).
        RepaintBoundary(key: _boundaryKey, child: widget.child),
        // [전역 감시] 평소(blockPassThrough=false)엔 모든 1손가락 입력이
        // 이 레이어를 그냥 투과해 아래 실제 화면으로 전달된다 — 스크롤/
        // 탭/버튼 완전히 그대로. 확대 중(blockPassThrough=true)에는 이
        // 레이어가 추가 터치를 흡수해 아래 버튼이 오작동하지 않게 막는다
        // ("확대 중 버튼 오작동 방지" 요구사항).
        Positioned.fill(
          child: PinchGestureListener(
            onPinchStart: _onPinchStart,
            onPinchUpdate: _onPinchUpdate,
            onPinchEnd: _onPinchEnd,
            onSingleDown: _onSingleDown,
            onSingleMove: _onSingleMove,
            onSingleUp: _onSingleUp,
            blockPassThrough: _zooming,
            child: const SizedBox.expand(),
          ),
        ),
        if (_zooming && _capturedImage != null)
          Positioned.fill(
            child: IgnorePointer(
              // 확대 오버레이 자체는 추가 입력을 받지 않는다(이미 위
              // PinchGestureListener가 같은 좌표계에서 포인터를
              // 추적하고 있다) — 순수 시각 레이어.
              ignoring: true,
              child: ClipRect(
                child: Transform(
                  transform: _transform.toMatrix4(),
                  alignment: Alignment.center,
                  child: RawImage(
                    image: _capturedImage,
                    fit: BoxFit.contain,
                    width: _viewportSize.width,
                    height: _viewportSize.height,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 손을 뗀 후 1.0배로 부드럽게 복귀하는 짧은 애니메이션 전용 경량 티커.
/// 별도 `AnimationController`(vsync 필요)를 매니저 State에 상시 두지
/// 않기 위해, 리셋이 필요한 순간에만 생성했다가 끝나면 바로 버리는
/// 일회용 [Ticker]를 사용한다.
class _ResetTicker {
  _ResetTicker({
    required this.duration,
    required this.onTick,
    required this.onDone,
  });

  final Duration duration;
  final void Function(double t) onTick;
  final VoidCallback onDone;

  Ticker? _ticker;

  void start() {
    _ticker = Ticker(_onFrame)..start();
  }

  void _onFrame(Duration elapsed) {
    final t = (elapsed.inMicroseconds / duration.inMicroseconds).clamp(
      0.0,
      1.0,
    );
    // easeOut 근사(3차) — 급정지 없이 자연스럽게 감속하며 복귀한다.
    final eased = 1 - (1 - t) * (1 - t) * (1 - t);
    onTick(eased);
    if (t >= 1.0) {
      _ticker?.stop();
      _ticker?.dispose();
      onDone();
    }
  }
}
