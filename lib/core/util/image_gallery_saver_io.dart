import 'dart:typed_data';

import 'package:gal/gal.dart';

import 'gallery_save_result.dart';

/// [귀인지도 결과카드 "이미지 저장" 버그수정 — 2026-11] 네이티브(Android
/// 등) 전용 구현. [Gal.putImageBytes]로 갤러리(사진 앱)에 직접 저장한다.
/// 저장 성공 여부를 bool로 반환해 호출부가 사용자에게 정확한 안내 문구를
/// 보여줄 수 있게 한다(권한 거부/공간 부족 등은 false로 폴백).
///
/// [REQ-05 참고] 이 함수는 기존 호출부(8개 화면) 호환을 위해 bool 반환을
/// 유지한다. 원인별 분기가 필요한 신규/개선 화면은 아래
/// [saveImageBytesToGalleryDetailed]를 사용할 것.
Future<bool> saveImageBytesToGallery(Uint8List bytes, {required String name}) async {
  final result = await saveImageBytesToGalleryDetailed(bytes, name: name);
  return result.isSuccess;
}

/// [REQ-05 — 신통방통_저장기능_정상화_개발지시서_v1.0] 실패 원인별 분기를
/// 제공하는 상세 버전. `catch (_) { return false; }`로 모든 예외를
/// 뭉개던 기존 구조(P-08-1)를 개선해, `GalException.type`을 구분하고
/// [GallerySaveFailureReason]으로 매핑한다.
Future<GallerySaveResult> saveImageBytesToGalleryDetailed(
  Uint8List bytes, {
  required String name,
}) async {
  if (bytes.isEmpty) {
    return const GallerySaveResult.failure(GallerySaveFailureReason.emptyBytes);
  }
  try {
    if (!await Gal.hasAccess()) {
      final granted = await Gal.requestAccess();
      if (!granted) {
        return const GallerySaveResult.failure(GallerySaveFailureReason.accessDenied);
      }
    }
    await Gal.putImageBytes(bytes, name: name);
    return const GallerySaveResult.success();
  } on GalException catch (e) {
    return GallerySaveResult.failure(_mapGalExceptionType(e.type));
  } catch (_) {
    return const GallerySaveResult.failure(GallerySaveFailureReason.unexpected);
  }
}

GallerySaveFailureReason _mapGalExceptionType(GalExceptionType type) {
  switch (type) {
    case GalExceptionType.accessDenied:
      return GallerySaveFailureReason.accessDenied;
    case GalExceptionType.notEnoughSpace:
      return GallerySaveFailureReason.notEnoughSpace;
    case GalExceptionType.notSupportedFormat:
      return GallerySaveFailureReason.notSupportedFormat;
    case GalExceptionType.unexpected:
      return GallerySaveFailureReason.unexpected;
  }
}
