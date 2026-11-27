import 'package:flutter/foundation.dart' show kIsWeb;

/// [웹 공유 "가짜 페이지" 근본 재설계 — 대표 긴급 지시, 2027-02]
///
/// [배경] 과거 admin_web(Next.js)에 `/r/[id]`·`/web-result/[id]` 전용
/// 모방 렌더링 페이지(가짜 하단바 포함)가 따로 있었던 근본 원인은, 이
/// Flutter 웹앱(`https://sintong.kr/app/`)이 브라우저 URL을 전혀 읽지
/// 않는 구조였기 때문이다 — `MaterialApp.initialRoute`가 `/splash`로
/// 고정되어 있어, `sintong.kr/app/#/r/{shareId}`로 직접 접속해도 항상
/// 스플래시 → 홈으로만 갔다. 이미 완성되어 있는 [SharedResultScreen]
/// (`/r/{shareId}` named route, `app_router.dart`)은 실제로는 전혀
/// 도달할 방법이 없는 "죽은 입구"였던 셈이다.
///
/// 이 헬퍼는 그 구조적 한계를 해결한다 — 앱 부팅 시(스플래시) 브라우저
/// 주소의 해시(fragment)를 직접 읽어, 공유 링크 패턴(`/r/{shareId}`)이면
/// 그 경로를 돌려준다. 앱은 hash 기반 라우팅을 쓰므로(`lib/app.dart`에
/// `usePathUrlStrategy()` 호출이 없음 — path 전략으로 바꾸면 기존에
/// 이미 발급되어 유통 중인 모든 `#/...` 형태 내부 네비게이션 동작이
/// 전부 깨질 위험이 있어 이번 수정 범위에서 제외한다) `Uri.base.fragment`가
/// 곧 Flutter named route 경로와 동일하다
/// (`https://sintong.kr/app/#/r/{shareId}` → fragment == '/r/{shareId}').
///
/// [비웹 플랫폼 영향 없음] APK/iOS에서는 `Uri.base`가 공유 링크와 무관한
/// 값(파일 경로 등)이라 [kIsWeb] 가드로 완전히 분리해 항상 null을
/// 반환한다 — OS 레벨 딥링크(App Links/커스텀 스킴)는 기존과 동일하게
/// [GuinjiDeepLinkHandler]가 별도로 처리하며 이 헬퍼와 무관하다.
///
/// [공유 생성 로직 미변경] 이 파일은 오직 "URL을 읽어 초기 진입 경로를
/// 결정"하는 역할만 하며, 공유 링크를 만드는 쪽(`ShareService`,
/// `EnvConfig.webResultUrl`/`resultDeepLinkUrl`)은 전혀 건드리지 않는다.
String? webShareEntryRouteFromUrl() {
  if (!kIsWeb) return null;
  final fragment = Uri.base.fragment;
  if (fragment.isEmpty) return null;
  // fragment가 '/r/xxx'든 'r/xxx'든(선행 슬래시 유무는 브라우저/엔진 버전에
  // 따라 달라질 수 있음) 동일하게 인식한다.
  final normalized = fragment.startsWith('/') ? fragment : '/$fragment';
  if (normalized.startsWith('/r/') && normalized.length > '/r/'.length) {
    return normalized;
  }
  return null;
}
