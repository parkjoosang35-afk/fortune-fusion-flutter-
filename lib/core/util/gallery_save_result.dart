/// [REQ-05 — 신통방통_저장기능_정상화_개발지시서_v1.0] 저장 실패 원인을
/// 구분하기 위한 결과 타입.
///
/// 기존 `saveImageBytesToGallery()`는 `catch (_) { return false; }`로
/// 모든 예외(권한 거부/저장 공간 부족/형식 오류/기타)를 동일하게 처리해,
/// 사용자에게는 항상 "권한을 확인해주세요"만 노출되었다(P-08-1). 특히
/// 저장 공간이 부족한 사용자가 권한 설정 화면을 뒤지게 되는 등 잘못된
/// 안내로 이어졌다.
///
/// `gal` 패키지는 [GalExceptionType](accessDenied/notEnoughSpace/
/// notSupportedFormat/unexpected)으로 실패 원인을 구분해 제공하므로, 이를
/// 그대로 보존해 호출부(화면)가 각 원인에 맞는 안내 문구를 보여줄 수
/// 있게 한다.
///
/// 기존 `bool` 반환 API(`saveImageBytesToGallery`)는 호출부 변경 비용을
/// 줄이기 위해 그대로 유지한다. 원인별 안내가 필요한 화면은 이 타입을
/// 반환하는 `saveImageBytesToGalleryDetailed()`를 사용하도록 점진적으로
/// 전환한다(REQ-03 — 저장 단일 경로 유지 원칙에 따라 내부적으로는 동일한
/// `gal` 호출 경로를 공유한다).
enum GallerySaveFailureReason {
  /// bytes.isEmpty — 캡처 자체가 실패해 저장할 이미지가 없음.
  emptyBytes,

  /// 사진(갤러리) 접근 권한이 거부됨. GalExceptionType.accessDenied.
  accessDenied,

  /// 기기 저장 공간 부족. GalExceptionType.notEnoughSpace.
  notEnoughSpace,

  /// 지원하지 않는 이미지 형식. GalExceptionType.notSupportedFormat.
  notSupportedFormat,

  /// 그 외 원인을 특정할 수 없는 오류. GalExceptionType.unexpected 및
  /// 웹 플랫폼의 모든 실패(브라우저는 원인 구분 API를 제공하지 않음)도
  /// 여기 포함된다.
  unexpected;

  /// 사용자에게 보여줄 안내 문구. REQ-05 요구사항 표와 1:1 대응.
  String get userMessage => switch (this) {
    GallerySaveFailureReason.emptyBytes => '결과 이미지를 만들지 못했어요. 다시 시도해주세요.',
    GallerySaveFailureReason.accessDenied =>
      '사진 권한이 꺼져 있어요. 설정 → 사진 → 신통방통에서 허용해주세요.',
    GallerySaveFailureReason.notEnoughSpace =>
      '기기 저장 공간이 부족해요. 공간을 확보한 뒤 다시 시도해주세요.',
    GallerySaveFailureReason.notSupportedFormat => '이 이미지 형식은 저장할 수 없어요.',
    GallerySaveFailureReason.unexpected => '저장에 실패했어요. 잠시 후 다시 시도해주세요.',
  };
}

/// 저장 성공/실패와 실패 시 원인을 함께 담는 결과 타입(sealed 유사 패턴).
/// `enum` + `bool success`로 단순화했다 — Dart 3.9 sealed class도 가능하나
/// 호출부에서 `result.isSuccess` / `result.failureReason?.userMessage`로
/// 충분히 다루기 쉬우므로 과설계를 피했다.
class GallerySaveResult {
  const GallerySaveResult._({required this.isSuccess, this.failureReason});

  const GallerySaveResult.success() : this._(isSuccess: true);

  const GallerySaveResult.failure(GallerySaveFailureReason reason)
    : this._(isSuccess: false, failureReason: reason);

  final bool isSuccess;
  final GallerySaveFailureReason? failureReason;

  /// 실패 시 사용자 안내 문구. 성공이면 null.
  String? get failureMessage => failureReason?.userMessage;
}
