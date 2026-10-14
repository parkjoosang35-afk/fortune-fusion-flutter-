import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'web_share_outcome.dart';
import 'package:web/web.dart' as web;

/// 웹 링크 공유는 share_plus의 텍스트 공유 대신 브라우저 API를 사용한다.
/// canShare 지원 여부를 확인하고 제목·본문·URL을 전달한다.
/// 공유창 종료·취소·미지원을 구분하며 취소에는 자동 복사를 하지 않는다.
/// 앱 결과 이미지 전송과 초대 링크 생성은 각각 별도 경로에서 담당한다.
Future<NativeWebShareOutcome> tryNativeWebShare(
  String text, {
  String? subject,
}) async {
  try {
    final navigator = web.window.navigator;
    // 웹 공유는 URL 필드를 명시해 브라우저가 홈페이지/결과페이지로 인식한다.
    final candidate = RegExp(r'https?://[^\s]+').firstMatch(text)?.group(0);
    final data = web.ShareData(text: text);
    if (subject != null && subject.isNotEmpty) data.title = subject;
    if (candidate != null) data.url = candidate;

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
