import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// [신통방통 전역 핀치 확대 시스템 — Render Controller]
///
/// 전역 핀치 확대는 "그 순간 화면에 그려져 있는 실제 위젯 트리"를
/// 고해상도로 캡처해 확대 레이어에 표시하는 "돋보기(magnifier)" 방식을
/// 쓴다(아키텍처 선택 이유는 [PinchGestureListener] 문서 참고 — 상시
/// InteractiveViewer를 화면 전체에 거는 방식은 스크롤/버튼과의 제스처
/// 경합 위험이 있어 채택하지 않았다).
///
/// ## 화질 보호 원칙(지시서 §4)과 이 구현의 관계
/// - `toImage(pixelRatio: ...)`는 "그 순간 화면에 실제로 그려진 위젯"을
///   캡처한다 — 즉 화면에 이미 **원본 고해상도 이미지가 `BoxFit.contain`
///   등으로 선명하게 그려져 있다면**, 그 선명한 픽셀을 그대로 가져온다.
///   반대로 그 화면이 애초에 저해상도 썸네일을 키워서 보여주고 있었다면,
///   이 캡처도 그 저해상도 상태를 그대로 가져올 수밖에 없다 — "확대
///   엔진이 저화질 원본을 고화질로 바꿀 수 있다고 간주하지 않는다"는
///   지시서 원칙을 그대로 따른다(이 컨트롤러는 화질을 "보존"할 뿐
///   "향상"시키지 않는다).
/// - [captureRatio]를 기기 `devicePixelRatio`보다 높게(최대 3.0배 상한)
///   설정해, "그려진 상태"보다 더 세밀한 픽셀 격자로 캡처한다 — 이렇게
///   하면 핀치 확대로 3배까지 키웠을 때도 캡처 이미지 자체의 픽셀
///   밀도가 화면 표시 밀도를 상회해 추가 보간(블러) 없이 선명하게
///   보인다. 과도한 메모리 사용을 막기 위해 3.0배로 상한을 둔다(§6
///   "반복 확대 시 메모리 누수 방지"와 직결).
class PinchZoomRenderController {
  PinchZoomRenderController({this.captureRatioCap = 3.0});

  /// 캡처 해상도 배율 상한(기기 devicePixelRatio에 곱해지는 추가 배율이
  /// 아니라, 최종 pixelRatio 자체의 상한이다 — 저사양 기기에서 과도한
  /// 메모리 사용(4K 캡처 등)을 막기 위한 안전장치).
  final double captureRatioCap;

  ui.Image? _lastCapture;
  Completer<void>? _inFlight;

  ui.Image? get lastCapture => _lastCapture;

  /// [boundaryKey]가 가리키는 [RepaintBoundary]의 현재 화면을 캡처한다.
  /// 이미 캡처가 진행 중이면 그 작업이 끝날 때까지 기다렸다가 반환한다
  /// (연타로 여러 캡처가 겹쳐 메모리를 낭비하지 않도록).
  Future<ui.Image?> capture(GlobalKey boundaryKey, {double devicePixelRatio = 1.0}) async {
    if (_inFlight != null) {
      await _inFlight!.future;
    }
    final completer = Completer<void>();
    _inFlight = completer;
    try {
      final ctx = boundaryKey.currentContext;
      final renderObject = ctx?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) return null;

      final ratio = devicePixelRatio.clamp(1.0, captureRatioCap);
      final image = await renderObject.toImage(pixelRatio: ratio);

      // 이전 캡처를 명시적으로 dispose해 GPU/CPU 메모리를 즉시 해제한다
      // — "반복 확대 시 메모리 누수 방지" 요구사항. ui.Image는 Flutter의
      // 참조 카운트 리소스라 dispose를 호출하지 않으면 다음 GC까지
      // 네이티브 버퍼가 남아있어, 반복 확대 시 메모리가 계단식으로
      // 누적될 수 있다.
      _lastCapture?.dispose();
      _lastCapture = image;
      return image;
    } catch (_) {
      // 레이아웃 전환 중(화면 전환 애니메이션 등) 캡처가 실패할 수 있다
      // — 이 경우 확대를 조용히 취소하고 기존 화면을 그대로 유지한다
      // (크래시 대신 안전한 폴백).
      return null;
    } finally {
      completer.complete();
      _inFlight = null;
    }
  }

  /// 확대 세션이 끝나거나(손가락을 뗌) 화면이 전환될 때 캡처 리소스를
  /// 즉시 해제한다. "화면 전환 시 확대 상태 초기화" + "메모리 누수 방지"
  /// 요구사항에 대응.
  void dispose() {
    _lastCapture?.dispose();
    _lastCapture = null;
  }
}
