// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';

/// [귀인지도 결과카드 "이미지 저장" 버그수정 — 2026-11] Web 전용 구현.
/// `gal` 패키지는 Web 플랫폼을 지원하지 않으므로(pub.dev platforms 목록에
/// web 없음), 브라우저 표준 방식(Blob URL + 임시 `<a download>` 클릭)으로
/// PNG 파일 다운로드를 트리거한다. 사용자의 브라우저 "다운로드" 폴더에
/// 저장되며, 이는 웹에서 "갤러리 저장"에 대응하는 가장 표준적인 동작이다.
Future<bool> saveImageBytesToGallery(Uint8List bytes, {required String name}) async {
  try {
    final blob = html.Blob([bytes], 'image/png');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', name)
      ..click();
    html.Url.revokeObjectUrl(url);
    return true;
  } catch (_) {
    return false;
  }
}
