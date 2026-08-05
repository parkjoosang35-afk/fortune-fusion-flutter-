import 'package:flutter/material.dart';

/// [타로 섹션 전면 개편 §6-1] 단일 progress 타임라인 기법의 공통 유틸.
///
/// 기존 `tarot_result_screen.dart`의 `_lerpRange(t, start, end, from, to,
/// curve)` 프라이빗 헬퍼를 공통 유틸로 승격한 것. 하나의 [AnimationController]
/// 의 progress 값(0.0~1.0)을 구간별로 파생시켜, 여러 연출 단계(암전→빛수렴→
/// 카드확대→플립→플래시→파티클버스트→텍스트등장 등)를 하나의 타임라인으로
/// 관리할 수 있게 한다. 신규 화면(카드선택/셔플/카테고리 전환 등)에서도
/// 이 함수를 그대로 재사용한다.
///
/// - [t]: 전체 타임라인 진행도(0.0~1.0)
/// - [start]/[end]: 이 구간이 시작/종료되는 시점(0.0~1.0 사이)
/// - [from]/[to]: 구간 내에서 보간할 값의 시작/끝
/// - [curve]: 구간 내부에 적용할 easing 커브
double lerpRange(
  double t,
  double start,
  double end,
  double from,
  double to, [
  Curve curve = Curves.linear,
]) {
  if (t <= start) return from;
  if (t >= end) return to;
  final local = (t - start) / (end - start);
  return from + (to - from) * curve.transform(local);
}

/// [t]가 [start]~[end] 구간에 속하는 동안 0.0~1.0로 정규화된 로컬 진행도만
/// 필요할 때 사용하는 헬퍼(구간 내부에서 커브를 여러 번 다르게 적용해야 할 때).
double localProgress(double t, double start, double end) {
  if (t <= start) return 0.0;
  if (t >= end) return 1.0;
  return (t - start) / (end - start);
}

/// 여러 구간(steps)을 한 번에 관리해야 하는 시네마틱 시퀀스를 명시적으로
/// 정의하기 위한 값 객체. 화면마다 하드코딩된 매직넘버 구간을 문서화된
/// 이름으로 관리할 수 있게 한다(§6-2 트리거 지점 표와 1:1 대응 목적).
class TarotTimelineStep {
  final String name;
  final double start;
  final double end;
  final Curve curve;
  const TarotTimelineStep({
    required this.name,
    required this.start,
    required this.end,
    this.curve = Curves.linear,
  });

  double valueAt(double t, {double from = 0.0, double to = 1.0}) =>
      lerpRange(t, start, end, from, to, curve);

  double localAt(double t) => localProgress(t, start, end);

  bool isActive(double t) => t >= start && t <= end;
}
