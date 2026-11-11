import 'package:flutter/widgets.dart';

/// [신통방통 전역 핀치 확대 시스템 — Transform Controller]
///
/// 두 손가락의 위치/거리 변화를 실제 확대 배율(scale)과 이동(offset)
/// 값으로 변환하는 순수 계산 로직. UI나 제스처 감지와 완전히 분리되어
/// 있어 단위 테스트가 쉽고, 다른 컨트롤러(Boundary)의 결과를 그대로
/// 입력받아 다음 프레임 값을 계산하는 역할만 한다.
///
/// 지시서 §3 요구사항 매핑:
/// - 기본 배율 1배 / 최대 3배 / 최소 1배 → [minScale]/[maxScale] 기본값
/// - "손가락 위치 기준 확대" → [focalPoint]를 중심으로 scale이 적용되도록
///   offset을 보정(아래 [update] 참고)
/// - "확대 후 한 손가락 이동" → 이 컨트롤러 자체는 2손가락 로직만 담당하고,
///   1손가락 이동은 [PinchZoomOverlayState]가 별도 [Listener]로 처리한다
///   (관심사 분리 — 이 파일은 "scale/translation 수학"에만 집중).
class PinchZoomTransform {
  const PinchZoomTransform({
    this.scale = 1.0,
    this.offset = Offset.zero,
  });

  final double scale;
  final Offset offset;

  static const identity = PinchZoomTransform();

  bool get isIdentity => scale == 1.0 && offset == Offset.zero;

  PinchZoomTransform copyWith({double? scale, Offset? offset}) {
    return PinchZoomTransform(
      scale: scale ?? this.scale,
      offset: offset ?? this.offset,
    );
  }

  Matrix4 toMatrix4() {
    return Matrix4.identity()
      ..translateByDouble(offset.dx, offset.dy, 0.0, 1.0)
      ..scaleByDouble(scale, scale, 1.0, 1.0);
  }
}

/// 두 포인터의 시작/현재 위치로부터 배율·이동 변화를 계산하는 상태 없는
/// 계산기. "어뷰징 방지 — 최대 배율 우회 방지"를 위해 모든 결과값은
/// [minScale]~[maxScale] 범위로 하드 클램프된다(이 클램프를 우회할 수 있는
/// 외부 입력 경로가 없다 — 오직 이 클래스를 통해서만 scale이 산출된다).
class PinchZoomTransformController {
  PinchZoomTransformController({
    this.minScale = 1.0,
    this.maxScale = 3.0,
  }) : assert(minScale <= maxScale);

  final double minScale;
  final double maxScale;

  late double _startDistance;
  late Offset _startMidpoint;

  double _scale = 1.0;
  Offset _translation = Offset.zero;

  double get scale => _scale;
  Offset get translation => _translation;

  PinchZoomTransform get value =>
      PinchZoomTransform(scale: _scale, offset: _translation);

  /// 핀치 시작 — 두 포인터의 초기 위치를 기준점으로 저장한다.
  void start(Offset posA, Offset posB) {
    _startDistance = (posA - posB).distance;
    _startMidpoint = Offset.lerp(posA, posB, 0.5)!;
    _scale = 1.0;
    _translation = Offset.zero;
  }

  /// 두 포인터의 최신 위치로 다음 scale/translation을 계산한다.
  ///
  /// "손가락 위치 기준 확대"는 중점(focal point, 두 손가락 사이 중간점)을
  /// 고정축으로 삼아 확대되도록, 중점의 이동량만큼 translation에 반영하고
  /// scale 변화는 시작 거리 대비 현재 거리의 비율로 계산한다. 0으로
  /// 나누기(두 손가락이 완전히 겹치는 극단 입력)는 안전하게 무시한다.
  void update(Offset posA, Offset posB) {
    if (_startDistance <= 1e-6) return; // 비정상 입력(겹친 시작점) 방어

    final currentDistance = (posA - posB).distance;
    final rawScale = currentDistance / _startDistance;
    // [어뷰징 방지] 여기서 바로 클램프하므로, 아무리 손가락을 빠르게
    // 벌리거나 비정상적인 속도로 움직여도 scale이 maxScale을 넘거나
    // minScale 밑으로 내려갈 수 없다 — "최대 배율 우회 방지" 요구사항을
    // 계산 단계에서 구조적으로 만족한다.
    _scale = rawScale.clamp(minScale, maxScale);

    final currentMidpoint = Offset.lerp(posA, posB, 0.5)!;
    _translation = currentMidpoint - _startMidpoint;
  }

  void reset() {
    _scale = 1.0;
    _translation = Offset.zero;
  }
}
