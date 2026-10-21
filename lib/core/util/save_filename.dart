import 'package:intl/intl.dart';

/// [REQ-09 — 신통방통_저장기능_정상화_개발지시서_v1.0] 저장 파일명 규칙 통일.
///
/// 규칙: `sintong_{서비스}_{결과ID}_{yyyyMMdd_HHmmss}`
/// (서비스: saju | tarot | face | palm | guinji | compat | wish | category 등)
///
/// 확장자(.png)는 포함하지 않는다 — 네이티브(Android/iOS) 경로는
/// [Gal.putImageBytes]가 바이트 포맷으로 확장자를 자체 결정하고, 웹 경로는
/// `image_gallery_saver_web.dart`가 `.png`가 없을 때만 자동으로 붙인다.
///
/// 파일명에 시각(초 단위)까지 포함해, 같은 결과를 여러 번 저장해도 매번
/// 새 파일로 생성되어 기존 파일을 덮어쓰거나 충돌하지 않도록 한다
/// (기존 규칙은 시각 미포함 — REQ-09 명시 요구사항, Q-06 연관).
String buildSaveFileName(String service, String resultId) {
  final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  return 'sintong_${service}_${resultId}_$timestamp';
}
