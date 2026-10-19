// [2026-09, 초대 랜딩 페이지 웹 전환 — 공용 URL 상수] 신통방통은 원래
// 앱이지만, 현재 `https://sintong.kr/app/`에 Flutter Web 빌드가 배포되어
// 있어 앱 설치 없이 브라우저에서 바로 신통방통 메인의 각 화면을 열 수
// 있다(nginx `location /app/ { alias /var/www/flutter_app_web/; }` 확인됨).
//
// [URL 전략] Flutter 앱의 `lib/app.dart`에 `usePathUrlStrategy()` 호출이
// 없으므로 Flutter Web은 기본 hash 기반 라우팅을 사용한다
// (`https://sintong.kr/app/#/경로`). 각 경로는 `lib/core/router/
// app_router.dart`의 `case '/경로':`와 정확히 일치해야 한다.
//
// 이 페이지(귀인지도 초대 랜딩)는 웹이므로, 여기서 신통방통 메인의 다른
// 서비스로 이동할 때는 커스텀 URI 스킴(`fortunefusion://`) 딥링크가 아니라
// 이 웹 URL을 직접 사용한다 — 앱 설치를 요구하지 않는다.
const SINTONG_WEB_BASE = "https://sintong.kr/app/#";

export const SINTONG_WEB_URLS = {
  /** 신통방통 메인 귀인지도 — "내 지도 만들기" 버튼의 이동 목적지. */
  guinji: `${SINTONG_WEB_BASE}/guinji`,
  /** 소원방. */
  wishRoom: `${SINTONG_WEB_BASE}/wish-room`,
  /** 타로 — 5초 로딩 인트로를 거쳐 타로 홈으로 진입하는 정식 입구. */
  tarot: `${SINTONG_WEB_BASE}/tarot/intro`,
  /** 정통사주 — 생년월일 입력 화면. */
  jeontong: `${SINTONG_WEB_BASE}/jeontong/input`,
  /** 오늘의 운세 — 인트로 화면. */
  todayFortune: `${SINTONG_WEB_BASE}/fortune/today/intro`,
  /** 신통방통 메인 홈(하단바 "홈" 탭). */
  home: `${SINTONG_WEB_BASE}/home`,
} as const;
