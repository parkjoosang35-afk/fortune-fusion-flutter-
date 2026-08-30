/// [STEP9 §7 QA 전용] 텍스트 크기 배율(textScale) 검증을 위한 조건부 임포트
/// 진입점. 웹에서만 URL 쿼리 파라미터(`?ts=1.3`)를 읽고, 그 외 플랫폼에서는
/// 항상 null을 반환해 시스템 기본 textScale을 그대로 사용한다.
/// 기본값(파라미터 없음)에서는 기존 프로덕션 동작과 완전히 동일하다.
export 'qa_text_scale_io.dart' if (dart.library.html) 'qa_text_scale_web.dart';
