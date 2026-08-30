/// [STEP9 §7 QA 전용] 비-웹(Android 등) 플랫폼에서는 URL 쿼리 파라미터라는
/// 개념이 없으므로 항상 null(=시스템 기본 textScale 사용)을 반환한다.
/// 프로덕션 동작에 어떤 영향도 주지 않는 순수 QA 테스트 훅이다.
double? readQaTextScaleOverride() => null;
