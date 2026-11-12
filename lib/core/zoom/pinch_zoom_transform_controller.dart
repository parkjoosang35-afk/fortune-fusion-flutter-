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
///   1손가락 이동은 [GlobalPinchZoomOverlay]가 별도 [Listener]로 처리한다
///   (관심사 분리 — 이 파일은 "scale/translation 수학"에만 집중).
///
/// [버그 수정 — 2026-11-12: "확대 후 손을 떼면 제자리로 돌아가는" 문제]
/// 과거 [start]는 호출될 때마다 누적값을 무시하고 `_scale=1.0,
/// _translation=Offset.zero`로 완전히 초기화했다. 이 때문에 핀치가
/// "끝났다가 다시 시작"되는 모든 상황(손가락을 뗀 뒤 확대 상태를 유지한
/// 채로 다시 핀치해 추가 확대/이동하려는 경우)에서 이전 확대값이 통째로
/// 날아가는 구조였다. 지금은 [start]가 현재 누적된 [_scale]/[_translation]을
/// `_baseScale`/`_baseTranslation`으로 "저장"만 하고, [update]는 그 기준값
/// 위에 이번 핀치의 변화량을 "더하는" 방식으로 계산한다 — 따라서 확대
/// 상태를 유지한 채로 몇 번이고 추가로 확대/축소/이동할 수 있다.
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

  // [버그 수정용 핵심 상태] 이번 핀치가 "시작되기 직전"까지 누적되어
  // 있던 배율/이동값의 스냅샷. start()가 호출되는 순간의 _scale/
  // _translation을 그대로 저장해 두었다가, update()는 이 값 위에
  // "이번 핀치로 인한 변화량"을 곱/합산하는 방식으로 최종값을 계산한다.
  // 과거에는 이 스냅샷 없이 start()가 곧바로 _scale/_translation을
  // 1.0/zero로 덮어썼기 때문에, 핀치가 "끝났다가 다시 시작"되는 모든
  // 경우(손을 뗀 뒤 확대 상태를 유지한 채 이어서 더 확대/이동하려는
  // 경우)에 이전 확대 상태가 통째로 사라지는 구조였다.
  double _baseScale = 1.0;
  Offset _baseTranslation = Offset.zero;

  double _scale = 1.0;
  Offset _translation = Offset.zero;

  double get scale => _scale;
  Offset get translation => _translation;

  PinchZoomTransform get value =>
      PinchZoomTransform(scale: _scale, offset: _translation);

  /// 핀치 시작 — 두 포인터의 초기 위치를 기준점으로 저장한다.
  ///
  /// [버그 수정] 더 이상 _scale/_translation을 1.0/zero로 초기화하지
  /// 않는다 — 현재 누적된 값을 "기준점"으로만 보존해, 확대 상태를 유지한
  /// 채로 몇 번이고 추가 확대/축소/이동을 이어갈 수 있도록 한다.
  void start(Offset posA, Offset posB) {
    _startDistance = (posA - posB).distance;
    _startMidpoint = Offset.lerp(posA, posB, 0.5)!;
    _baseScale = _scale;
    _baseTranslation = _translation;
  }

  /// 두 포인터의 최신 위치로 다음 scale/translation을 계산한다.
  ///
  /// "손가락 위치 기준 확대"는 중점(focal point, 두 손가락 사이 중간점)을
  /// 고정축으로 삼아 확대되도록, 중점의 이동량만큼 translation에 반영하고
  /// scale 변화는 시작 거리 대비 현재 거리의 비율로 계산한다. 0으로
  /// 나누기(두 손가락이 완전히 겹치는 극단 입력)는 안전하게 무시한다.
  ///
  /// [버그 수정] rawScale/이동량을 [_baseScale]/[_baseTranslation](이번
  /// 핀치 시작 시점의 누적값) 위에 곱/합산한다 — 그래서 "이어서 확대"할
  /// 때 이전 배율이 그대로 보존된 채 추가로 커진다.
  void update(Offset posA, Offset posB) {
    if (_startDistance <= 1e-6) return; // 비정상 입력(겹친 시작점) 방어

    final currentDistance = (posA - posB).distance;
    final rawScaleDelta = currentDistance / _startDistance;
    // [어뷰징 방지] 여기서 바로 클램프하므로, 아무리 손가락을 빠르게
    // 벌리거나 비정상적인 속도로 움직여도 scale이 maxScale을 넘거나
    // minScale 밑으로 내려갈 수 없다 — "최대 배율 우회 방지" 요구사항을
    // 계산 단계에서 구조적으로 만족한다.
    _scale = (_baseScale * rawScaleDelta).clamp(minScale, maxScale);

    final currentMidpoint = Offset.lerp(posA, posB, 0.5)!;
    _translation = _baseTranslation + (currentMidpoint - _startMidpoint);
  }

  /// [확대 유지 기능] 정지 확대(held-zoom) 상태에서 한 손가락 드래그로
  /// 화면을 이동할 때 사용한다. 호출 후 경계 클램프는 호출부(매니저)가
  /// 적용한 뒤 [setTranslation]으로 보정값을 다시 반영해야, 다음 핀치의
  /// 기준값([_baseTranslation])도 화면 밖으로 새지 않는다.
  void panBy(Offset delta) {
    _translation += delta;
  }

  /// 경계 클램프 등 외부에서 보정한 최종 translation을 내부 상태에
  /// 반영한다(주로 [panBy] 직후 호출).
  void setTranslation(Offset translation) {
    _translation = translation;
  }

  void reset() {
    _scale = 1.0;
    _translation = Offset.zero;
    _baseScale = 1.0;
    _baseTranslation = Offset.zero;
  }
}
