// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// [STEP9 §7 QA 전용] 웹 프리뷰에서 `?ts=1.3` 같은 URL 쿼리 파라미터로
/// textScale을 강제 오버라이드할 수 있게 하는 테스트 전용 훅이다.
/// 쿼리 파라미터가 없으면 null을 반환해 시스템 기본값을 그대로 사용하므로,
/// 실제 사용자 화면 동작에는 아무 영향이 없다(QA 캡처 자동화 목적 한정).
double? readQaTextScaleOverride() {
  try {
    final uri = Uri.parse(html.window.location.href);
    final raw = uri.queryParameters['ts'];
    if (raw == null) return null;
    final v = double.tryParse(raw);
    if (v == null || v <= 0) return null;
    return v;
  } catch (_) {
    return null;
  }
}
