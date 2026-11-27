import 'package:web/web.dart' as web;

/// [PC 웹 결과 공유 버그 수정 — 2027-03] `document.execCommand('copy')`
/// (레거시 동기식 복사 API)로 클립보드 복사를 강제 시도한다.
///
/// [동작 원리] 화면 밖(off-screen)에 숨겨둔 `<textarea>`에 [text]를 채운
/// 뒤 `select()`로 전체 선택하고 `execCommand('copy')`를 호출한다. 이
/// 레거시 API는 Permissions Policy(`clipboard-write`)나 비동기 Clipboard
/// API 권한 프롬프트와 무관하게, 사용자 제스처(클릭) 이벤트 핸들러 안에서
/// **동기적으로** 호출되기만 하면 항상 동작한다 — 동일 출처 iframe
/// 안에서도 마찬가지다(Playwright로 `navigator.clipboard.writeText()`가
/// `NotAllowedError`로 실패하는 바로 그 iframe 컨텍스트에서
/// `execCommand('copy')`는 성공하는 것을 확인했다).
///
/// [반환값] 성공 여부(`execCommand`의 반환값을 그대로 전달). 호출부
/// (`safe_share.dart`)는 이 함수가 false를 반환할 때만 최종적으로 수동
/// 복사 다이얼로그로 폴백한다.
bool tryLegacyExecCommandCopy(String text) {
  try {
    final textarea = web.document.createElement('textarea') as web.HTMLTextAreaElement
      ..value = text
      // 화면에 보이지 않게 밀어내되, display:none은 일부 브라우저에서
      // select()가 동작하지 않을 수 있어 position/opacity로 숨긴다.
      ..style.position = 'fixed'
      ..style.top = '0'
      ..style.left = '0'
      ..style.width = '2em'
      ..style.height = '2em'
      ..style.padding = '0'
      ..style.border = 'none'
      ..style.outline = 'none'
      ..style.boxShadow = 'none'
      ..style.background = 'transparent'
      ..style.opacity = '0';
    web.document.body?.appendChild(textarea);
    textarea.focus();
    textarea.select();
    final ok = web.document.execCommand('copy');
    textarea.remove();
    return ok;
  } catch (_) {
    return false;
  }
}
