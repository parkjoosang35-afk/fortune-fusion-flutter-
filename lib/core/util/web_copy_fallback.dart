/// [PC 웹 결과 공유 버그 수정 — 2027-03]
///
/// [배경] PC(데스크톱) 브라우저에는 `navigator.share`(Web Share API)가
/// 존재하지 않아(`web_native_share_web.dart`의 `tryNativeWebShare`가
/// `unavailable`을 반환) `safeShareText()`가 곧바로 `Clipboard.setData()`
/// (= `navigator.clipboard.writeText()`)로 폴백한다. 그런데 이 앱은
/// `sintong.kr`(랜딩 페이지)이 `sintong.kr/app/`을 **동일 출처 iframe**으로
/// 품고 있는 구조라(`allow="clipboard-write"` 지정됨), 랜딩 페이지를 통해
/// PC로 접속한 사용자의 클릭에서는 `navigator.clipboard.writeText()`가
/// `NotAllowedError`로 실패하는 경우가 있다(Playwright로 실제 iframe 안에서
/// 신뢰된 클릭 이벤트를 재현해 확인 — 권한을 사전 승인하지 않은 상태에서는
/// 매번 거부됨, 직접 `/app/`으로 들어간 최상위 문서에서는 동일 코드가
/// 정상 동작함). 결과적으로 PC에서 "결과 공유하기"를 눌러도 클립보드에
/// 아무것도 복사되지 않거나(안내 토스트만 뜨고 실제로는 실패) 수동 복사
/// 다이얼로그로만 빠지는 문제가 있었다("PC버젼에서 결과페이지 공유하게
/// 해줘" — 사용자 요청).
///
/// [해결] 최신 비동기 Clipboard API(`navigator.clipboard.writeText`)가
/// 권한 문제로 실패하면, 브라우저가 수십 년간 지원해온 동기식 레거시 API
/// `document.execCommand('copy')`(숨겨진 textarea에 값을 넣고 선택한 뒤
/// 복사)로 즉시 재시도한다. 이 레거시 API는 Permissions Policy의 영향을
/// 받지 않고 사용자 제스처(클릭) 핸들러 내부에서 동기적으로 호출되기만
/// 하면 iframe 안에서도 항상 동작한다(Playwright로 동일 iframe 안에서
/// 재현 테스트 완료 — 비동기 Clipboard API가 거부된 바로 그 상황에서도
/// `execCommand('copy')`는 성공함).
library;

export 'web_copy_fallback_io.dart'
    if (dart.library.html) 'web_copy_fallback_web.dart';
