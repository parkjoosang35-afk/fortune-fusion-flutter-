import 'package:flutter/widgets.dart';

/// [신통방통 전역 핀치 확대 시스템 — Boundary Controller]
///
/// 확대된 콘텐츠가 화면 경계 밖으로 과도하게 벗어나지 않도록 이동값을
/// 제한한다. 지시서 §3 "화면 경계 제한", §6 "무한 이동 방지" 요구사항에
/// 대응하는 순수 계산 로직(상태 없음, 입력→출력만 있는 함수형 클래스).
///
/// 확대된 콘텐츠의 크기가 [viewportSize] * [scale]이므로, 화면 중앙을
/// 기준으로 콘텐츠가 뷰포트보다 커진 만큼만(초과분의 절반) 이동을
/// 허용하고, 그 이상은 하드 클램프한다. 이렇게 하면:
/// - scale == 1.0 (확대 안 함)일 때는 이동 허용 범위가 0이 되어 항상
///   원점에 고정된다(의도된 동작 — 평상시 화면은 움직이지 않는다).
/// - scale이 커질수록 이동 허용 범위도 비례해서 커진다(더 확대했을수록
///   더 멀리 구석구석을 볼 수 있다 — 자연스러운 체감).
class PinchZoomBoundaryController {
  const PinchZoomBoundaryController();

  /// [translation]을 [viewportSize]와 [scale] 기준으로 허용 범위 안으로
  /// 제한한 새 Offset을 반환한다. 원본 [translation]을 변경하지 않는다.
  Offset clamp({
    required Offset translation,
    required Size viewportSize,
    required double scale,
  }) {
    if (scale <= 1.0 || viewportSize.isEmpty) return Offset.zero;

    final overflowX = viewportSize.width * (scale - 1.0) / 2.0;
    final overflowY = viewportSize.height * (scale - 1.0) / 2.0;

    final clampedX = translation.dx.clamp(-overflowX, overflowX);
    final clampedY = translation.dy.clamp(-overflowY, overflowY);
    return Offset(clampedX, clampedY);
  }
}
