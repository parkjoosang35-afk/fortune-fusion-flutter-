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
  /**
   * 신당부적 — 앱 하단바 2번째 탭(`lib/core/router/app_router.dart`의
   * `case '/shrine':`에 대응하는 named route). 앱에서는 탭 자체가
   * 콘텐츠를 담지 않고 눌렀을 때 `ShrineEntryScreen`을 push하는 방식이라,
   * 웹에서도 동일하게 `/shrine` 경로로 직접 이동시킨다.
   */
  shrine: `${SINTONG_WEB_BASE}/shrine`,
  /**
   * 복주머니(행운상자) — 앱 하단바 3번째 탭. Flutter 쪽에 전용 named
   * route가 없고 `/home` 라우트에 `arguments: 1`(tab index)로만 진입
   * 가능해 해시 URL만으로는 해당 탭을 직접 지정할 수 없다. 기존 "마이"
   * 탭도 동일한 제약으로 `home`을 가리키던 선례를 따라, 일단 홈으로
   * 보내고 추후 전용 경로가 생기면 교체한다.
   */
  pouch: `${SINTONG_WEB_BASE}/home`,
  /**
   * [궁합지도 `/gh/[token]` 랜딩 신설] 궁합지도(Gunghap) 홈 화면
   * (`GunghapHomeScreen`)은 귀인지도(`/guinji`)와 달리 `app_router.dart`에
   * 전용 named route가 없다 — 오직 신통방통 메인 홈 화면의 "궁합지도"
   * 카드를 탭했을 때(`openCompatibilityMap()`)만 `MaterialPageRoute`로
   * 직접 push되며, 해시 딥링크(`#/gunghap` 등)로는 도달할 수 없다. 전용
   * 라우트가 생기기 전까지는 위 `pouch`와 동일한 전례(전용 경로 없음 →
   * 홈으로 폴백)를 따라 홈으로 보낸다 — 사용자가 홈에서 직접 궁합지도
   * 카드를 탭해 진입한다.
   */
  gunghap: `${SINTONG_WEB_BASE}/home`,
} as const;
