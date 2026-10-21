import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'gallery_save_result.dart';

/// [REQ-04 — 신통방통_저장기능_정상화_개발지시서_v1.0] Web 전용 구현.
/// `gal` 패키지는 Web 플랫폼을 지원하지 않으므로(pub.dev platforms 목록에
/// web 없음), 브라우저 표준 방식(Blob URL + 임시 `<a download>` 클릭)으로
/// PNG 파일 다운로드를 트리거한다. 사용자의 브라우저 "다운로드" 폴더에
/// 저장되며, 이는 웹에서 "갤러리 저장"에 대응하는 가장 표준적인 동작이다.
///
/// [2026-10 변경 — dart:html → package:web] 과거 구현은 `dart:html`
/// (`html.Blob`, `html.Url`, `html.AnchorElement`)을 직접 사용했다.
/// `dart:html`은 dart2js(JavaScript) 컴파일 전용 라이브러리로, 이 파일로의
/// 분기 자체가 `if (dart.library.html)` 조건부 export에 의존하고 있었다
/// (→ image_gallery_saver.dart 참고, REQ-04). 이 조건은 dart2js에서만
/// 참이 되므로, Flutter Web을 `--wasm`으로 빌드하면 조건이 거짓이 되어
/// 이 파일 자체가 선택되지 않고 io 구현(gal 기반)이 선택되어 웹 저장이
/// 전면 실패하는 위험이 있었다(P-03).
///
/// `package:web`은 `dart:js_interop` 기반으로 dart2js·Wasm(dart2wasm)
/// 양쪽 컴파일 타겟 모두에서 동작하도록 설계된 공식 SDK 패키지이므로,
/// 이 파일의 구현 자체를 플랫폼 독립적으로 만든다. 다만 "이 파일이
/// 선택되는 조건"(분기 자체)은 image_gallery_saver.dart에서 별도로
/// kIsWeb 런타임 판정으로 교체했다 — 이 파일의 package:web 전환은
/// 그 교체가 안전하게 동작하기 위한 전제 조건이다.
Future<bool> saveImageBytesToGallery(
  Uint8List bytes, {
  required String name,
}) async {
  final result = await saveImageBytesToGalleryDetailed(bytes, name: name);
  return result.isSuccess;
}

/// [REQ-05] 웹 플랫폼은 브라우저 다운로드 API가 실패 원인을 세분화해
/// 제공하지 않으므로(권한/용량 구분 불가), 빈 바이트(emptyBytes)만
/// 구분하고 나머지 실패는 unexpected로 묶는다. 호출부 분기 형태를
/// 앱(io)과 동일하게 맞춰 화면 쪽 코드를 플랫폼 무관하게 유지하기
/// 위한 목적이 더 크다.
Future<GallerySaveResult> saveImageBytesToGalleryDetailed(
  Uint8List bytes, {
  required String name,
}) async {
  if (bytes.isEmpty) {
    return const GallerySaveResult.failure(GallerySaveFailureReason.emptyBytes);
  }
  try {
    final fileName = name.endsWith('.png') ? name : '$name.png';
    final blobParts = <JSAny>[bytes.toJS].toJS;
    final blob = web.Blob(
      blobParts,
      web.BlobPropertyBag(type: 'image/png'),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = fileName
      ..style.display = 'none';
    web.document.body?.appendChild(anchor);
    anchor.click();
    anchor.remove();
    // 다운로드가 Blob을 읽기 전에 URL을 해제하지 않도록 지연 후 해제한다.
    Future<void>.delayed(
      const Duration(seconds: 30),
      () => web.URL.revokeObjectURL(url),
    );
    return const GallerySaveResult.success();
  } catch (_) {
    return const GallerySaveResult.failure(GallerySaveFailureReason.unexpected);
  }
}
