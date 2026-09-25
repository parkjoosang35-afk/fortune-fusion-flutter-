import 'dart:js_interop';
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
/// 재발하지 않는다. 성공하면 true, 실패(canShare 미지원/false/사용자
/// 취소/기타 예외)하면 false를 돌려주어 호출부(`safe_share.dart`)가
/// 안전하게 클립보드 폴백을 이어가게 한다.
Future<bool> tryNativeWebShare(String text, {String? subject}) async {
  try {
    final navigator = web.window.navigator;
    final data = (subject != null && subject.isNotEmpty)
        ? web.ShareData(title: subject, text: text)
        : web.ShareData(text: text);

    final canShare = navigator.canShare(data);
    if (!canShare) return false;

    await navigator.share(data).toDart;
    return true;
  } catch (_) {
    // canShare/share가 아예 없는 구형 브라우저(NoSuchMethodError)나
    // 사용자가 공유 시트를 취소한 경우(AbortError) 모두 여기로 온다 —
    // 두 경우 모두 호출부가 클립보드로 안전하게 폴백해야 하므로 false.
    return false;
  }
}
