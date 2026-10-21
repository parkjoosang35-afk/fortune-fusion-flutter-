// [귀인지도 결과카드 "이미지 저장" 버그수정 — 2026-11] 플랫폼별 구현을
// 연결하는 진입점. Web에서는 브라우저 다운로드
// (`image_gallery_saver_web.dart`)를, 그 외(Android 등)에서는 `gal`
// 패키지로 실제 갤러리 저장(`image_gallery_saver_io.dart`)을 사용한다.
//
// [배경] 기존 "이미지 저장" 버튼은 실제로는 공유하기와 동일한
// `Share.shareXFiles()`만 호출해서, 눌러도 OS 공유 시트가 뜰 뿐 갤러리에
// 곧바로 저장되지 않았다("이미지 저장 버튼이 뭘 하는지 모르겠다"는 사용자
// 불만의 원인 중 하나). 이제 "이미지 저장"과 "공유하기"가 실제로 서로
// 다른 동작을 하도록 분리한다.
//
// [REQ-04 — 신통방통_저장기능_정상화_개발지시서_v1.0] 플랫폼 분기를
// `if (dart.library.html)` 조건부 export에서 `kIsWeb` 런타임 판정으로
// 교체했다.
//
// 기존 조건부 export 방식의 문제(P-03):
//   export 'image_gallery_saver_io.dart'
//       if (dart.library.html) 'image_gallery_saver_web.dart';
// `dart.library.html` 조건은 **컴파일 타임**에 평가되며, dart2js
// 컴파일에서만 참이 된다. Flutter Web을 `--wasm`(dart2wasm)으로 빌드하면
// 이 조건이 거짓으로 평가되어 io 구현(gal 기반)이 선택되는데, `gal`은
// 웹 플랫폼을 지원하지 않으므로(pub.dev platforms 목록에 web 없음) 웹
// 저장이 전면 실패한다. 즉 "조건부 export가 컴파일 방식에 의존한다"는
// 것 자체가 구조적 위험이었다.
//
// kIsWeb 런타임 판정으로 바꾸면 두 구현 파일 모두가 항상 컴파일되고
// (export가 아닌 일반 import이므로), 실행 시점에 실제 실행 플랫폼을
// 보고 분기하므로 dart2js·Wasm 빌드 방식과 무관하게 항상 올바른 구현이
// 선택된다. 두 구현 파일 모두 플랫폼별 심벌(dart:js_interop 등은 웹
// 전용 패키지인 package:web으로 이미 교체됨 — image_gallery_saver_web.dart
// 참고)만 사용하므로 조건부 import 없이도 양쪽 플랫폼에서 안전하게
// 컴파일된다.
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;

import 'gallery_save_result.dart';
import 'image_gallery_saver_io.dart' as io_impl;
import 'image_gallery_saver_web.dart' as web_impl;

export 'gallery_save_result.dart';

Future<bool> saveImageBytesToGallery(
  Uint8List bytes, {
  required String name,
}) {
  if (kIsWeb) {
    return web_impl.saveImageBytesToGallery(bytes, name: name);
  }
  return io_impl.saveImageBytesToGallery(bytes, name: name);
}

/// [REQ-05] 실패 원인별 안내가 필요한 화면에서 사용하는 상세 버전.
/// 내부적으로 플랫폼별 구현(gal 또는 브라우저 다운로드)을 호출하는
/// 단일 경로는 그대로 유지한다(REQ-03).
Future<GallerySaveResult> saveImageBytesToGalleryDetailed(
  Uint8List bytes, {
  required String name,
}) {
  if (kIsWeb) {
    return web_impl.saveImageBytesToGalleryDetailed(bytes, name: name);
  }
  return io_impl.saveImageBytesToGalleryDetailed(bytes, name: name);
}
