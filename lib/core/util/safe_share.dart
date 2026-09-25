import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../widgets/app_toast.dart';
import 'web_native_share.dart';

/// [공유 페이지 net::ERR_UNKNOWN_URL_SCHEME 버그 근본 수정 — 2026-12]
///
/// [배경] `sms:` 커스텀 스킴 버그(2026-09, `guinji_map_share_screen.dart`
/// 참고)를 고친 뒤에도 사용자가 동일한 에러 화면("페이지 로드에
/// 실패했습니다 / net::ERR_UNKNOWN_URL_SCHEME")을 다시 리포트했다
/// ("공유 페이지가 다 이렇게 나오네"). 원인을 추적하기 위해
/// `share_plus` 패키지의 웹 구현(`share_plus_web.dart`)을 직접 읽어보니,
/// `Share.share(text)`가 다음과 같이 동작한다:
///
/// ```dart
/// try {
///   canShare = _navigator.canShare(data);
/// } on NoSuchMethodError catch (e) {
///   // Navigator is not available or the webPage is not served on https
///   final uri = Uri(scheme: 'mailto', query: ...);
///   final launchResult = await urlLauncher.launchUrl(uri.toString(), ...);
///   ...
/// }
/// ```
///
/// 즉 브라우저가 `navigator.canShare`를 구현하지 않은 경우(카카오톡/
/// 삼성인터넷 등 인앱 브라우저에서 실제로 발생) `share_plus`가 **자체적으로**
/// `mailto:` 스킴을 열려고 시도한다. 그런데 `url_launcher_web.dart`의
/// `launchUrl`은 `LaunchMode`와 무관하게 항상 `window.open(url, ...)`으로
/// **새 탭**을 연다 — 그 새 탭이 인앱 브라우저 컨텍스트에서 `mailto:`
/// 스킴을 처리하지 못해 정확히 이 에러 화면이 뜬다. `sms:` 버그와
/// 완전히 동일한 메커니즘이 `share_plus` 패키지 내부에 숨어 있었던
/// 것이다(이미지 첨부용 `Share.shareXFiles()`는 동일 상황에서 파일
/// 다운로드로 안전하게 폴백하므로 이 버그와 무관 — 텍스트 전용
/// `Share.share()`만 위험하다).
///
/// [해결 원칙 — 2026-12 수정, 2027-01 UX 불일치 버그 재수정]
/// 웹에서는 `share_plus`의 `Share.share()`(텍스트)를 절대 호출하지
/// 않는다 — 그 구현이 `navigator.canShare()`가 없는 브라우저를 만나면
/// `mailto:` 스킴을 새 탭에 열려다 실패하는 버그가 있었기 때문이다.
/// 그렇다고 웹에서 무조건 클립보드로만 보내면, 같은 결과 화면의
/// "이미지로 공유하기"(`Share.shareXFiles()` 경로는 네이티브 Web Share
/// API를 실제로 시도해 카카오톡 등 공유 대상 목록이 뜬다)와 달리
/// "링크로 공유하기"만 아무 시트도 없이 조용히 끝나 사용자가 "왜 하나만
/// 안 되냐"고 혼란스러워하는 일관성 버그가 생긴다. 그래서 웹에서도
/// `web_native_share.dart`(이 파일이 직접 `navigator.canShare()`를 먼저
/// 확인한 뒤에만 `navigator.share()`를 시도 — `share_plus`를 거치지
/// 않으므로 `mailto:` 버그와 무관)로 네이티브 공유 시트를 먼저 시도하고,
/// 그것이 지원되지 않거나 실패한 경우에만 클립보드로 폴백한다. 네이티브
/// (Android/iOS)에서는 기존처럼 `Share.share()`를 먼저 시도하고, 실패
/// 시에만 클립보드로 폴백한다.
Future<void> safeShareText(
  BuildContext context,
  String text, {
  String? subject,
  String copiedMessage = '메시지를 복사했어요. 원하는 앱에 붙여넣어 전달해 주세요.',
  String failedMessage = '공유하기를 지원하지 않는 환경입니다.',
}) async {
  Future<void> copyAndToast(String message) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    AppToast.show(context, message);
  }

  if (kIsWeb) {
    // [UX 일관성 수정] `share_plus`의 `Share.share()`는 여전히 호출하지
    // 않는다(mailto: 버그 재발 방지). 대신 이 프로젝트가 직접 구현한
    // `tryNativeWebShare()`로 `navigator.canShare()`를 먼저 확인해 안전한
    // 경우에만 네이티브 공유 시트를 띄운다.
    final shared = await tryNativeWebShare(text, subject: subject);
    if (shared) return;
    // 네이티브 공유가 지원되지 않거나(구형 브라우저) 사용자가 취소한
    // 경우에만 클립보드로 확정적으로 폴백한다.
    await copyAndToast(copiedMessage);
    return;
  }

  try {
    final result = await Share.share(text, subject: subject);
    if (result.status == ShareResultStatus.unavailable) {
      if (!context.mounted) return;
      await copyAndToast(copiedMessage);
    }
  } catch (_) {
    if (!context.mounted) return;
    await copyAndToast(failedMessage);
  }
}
