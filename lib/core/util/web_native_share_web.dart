import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'web_share_outcome.dart';
import 'package:web/web.dart' as web;

/// [결과 공유 UX 불일치 버그 수정]
///
/// [배경] `core/util/safe_share.dart`는 지금까지 웹에서는 `Share.share()`
/// (share_plus)를 절대 시도하지 않고 무조건 클립보드 복사로 폴백했다.
/// 그 이유(2026-12 커밋 사유)는 `share_plus`의 웹 구현이
/// `navigator.canShare()`가 없는 브라우저를 만나면 `mailto:` 스킴을 새
/// 탭에 열려다가 `net::ERR_UNKNOWN_URL_SCHEME` 에러 화면을 띄우는 버그가
/// 있었기 때문이다. 그런데 이 "무조건 회피" 전략 때문에 같은 화면의
/// "이미지로 공유하기"(`Share.shareXFiles()`를 통해 여전히 네이티브
/// Web Share API를 시도함)는 카카오톡 등 실제 공유 대상 목록이 뜨는데,
/// "링크로 공유하기"만 아무 시트도 없이 조용히 클립보드에 복사되어
/// 사용자가 "왜 하나는 되고 하나는 안 되냐"고 혼란스러워하는 일관성
/// 버그로 이어졌다.
///
/// [근본 수정] `share_plus`를 거치지 않고 이 파일에서 직접
/// `navigator.canShare()`로 지원 여부를 먼저 확인한 뒤에만
/// `navigator.share()`를 시도한다 — canShare()가 없거나 false인
/// 브라우저에서는 절대 시도하지 않으므로 기존에 고쳤던 `mailto:` 버그가
/// 재발하지 않는다. 성공·취소·미지원 결과를 구분하여 취소에는
/// 자동 복사가 발생하지 않도록 한다.
Future<NativeWebShareOutcome> tryNativeWebShare(
  String text, {
  String? subject,
}) async {
  try {
    final navigator = web.window.navigator;
    final data = (subject != null && subject.isNotEmpty)
        ? web.ShareData(title: subject, text: text)
        : web.ShareData(text: text);

    final canShare = navigator.canShare(data);
    if (!canShare) return NativeWebShareOutcome.unavailable;

    await navigator.share(data).toDart;
    return NativeWebShareOutcome.shared;
  } catch (error) {
    try {
      final name = (error as JSObject)
          .getProperty<JSAny?>('name'.toJS)
          ?.dartify();
      if (name == 'AbortError') return NativeWebShareOutcome.cancelled;
    } catch (_) {
      /* JS가 아닌 예외는 미지원 처리 */
    }
    return NativeWebShareOutcome.unavailable;
  }
}
