/// [결과 공유 UX 불일치 버그 수정 — "이미지로 공유하기"는 네이티브 공유
/// 시트가 뜨는데 "링크로 공유하기"는 조용히 클립보드 복사만 되는 문제]
/// 플랫폼별 구현을 조건부로 연결하는 진입점. 웹에서는 브라우저의
/// Web Share API(`navigator.share`)를 직접 시도하는 구현
/// (`web_native_share_web.dart`)을, 그 외(Android APK 등)에서는 항상
/// false를 반환하는 스텁(`web_native_share_io.dart`)을 사용한다 —
/// 네이티브 플랫폼은 이미 `share_plus`의 `Share.share()`가 정상 동작
/// 하므로 이 헬퍼가 개입할 필요가 없다.
export 'web_native_share_io.dart'
    if (dart.library.html) 'web_native_share_web.dart';
