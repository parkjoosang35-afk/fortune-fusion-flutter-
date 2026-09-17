import 'dart:typed_data';

import 'package:gal/gal.dart';

/// [귀인지도 결과카드 "이미지 저장" 버그수정 — 2026-11] 네이티브(Android
/// 등) 전용 구현. [Gal.putImageBytes]로 갤러리(사진 앱)에 직접 저장한다.
/// 저장 성공 여부를 bool로 반환해 호출부가 사용자에게 정확한 안내 문구를
/// 보여줄 수 있게 한다(권한 거부/공간 부족 등은 false로 폴백).
Future<bool> saveImageBytesToGallery(Uint8List bytes, {required String name}) async {
  try {
    await Gal.putImageBytes(bytes, name: name);
    return true;
  } catch (_) {
    return false;
  }
}
