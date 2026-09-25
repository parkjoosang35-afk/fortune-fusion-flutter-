/// CMS 제휴광고(배너) 조회를 위한 관리자 웹(admin_web) 백엔드 API 기본 주소.
///
/// [배경] Flutter 앱은 10단계(Mock 우선 개발) 단계라 지금까지 실제 HTTP 통신이 전혀
/// 없었다. 이번에 admin_web에 신설한 공개 배너 조회 API(`GET /api/public/banners`)를
/// 처음으로 호출하기 위해, 그 서버의 base URL을 이 파일에서 관리한다.
///
/// --dart-define=ADMIN_API_BASE_URL=https://... 로 실행 시 값을 덮어쓸 수 있어,
/// 샌드박스마다 달라지는 프리뷰 URL이나 운영 배포 시 실제 도메인으로 쉽게 교체 가능하다.
class EnvConfig {
  EnvConfig._();

  static const String adminApiBaseUrl = String.fromEnvironment(
    'ADMIN_API_BASE_URL',
    // [Phase C] 가비아 운영 서버(sintong.kr) 도메인으로 전환.
    // 이전 샌드박스 임시 프리뷰 주소는 세션 종료 시 무효화되는 문제가 있어
    // 영구 운영 도메인으로 고정한다.
    defaultValue: 'https://sintong.kr',
  );

  /// [정통사주 v3 - 4차 지시서 항목③ 인증 연결] saju_v3 엔진 서버 전용
  /// X-Free-Pass 토큰. img2_인증연결가이드.png의 의도대로 앱의 표준 인증
  /// (`AuthTokenStore.authHeader()` → `Authorization: Bearer <JWT>`, admin
  /// API용)은 그대로 유지하고, saju_v3 엔진 요청에만 이 별도 헤더를 얹는다
  /// — 두 인증 체계가 서로 충돌하지 않는다(엔진 코드 변경 없이 해결).
  ///
  /// 하드코딩 금지: 값은 항상 `--dart-define=SAJU_FREEPASS=<발급된_토큰>`
  /// (빌드/런타임 주입)으로만 전달한다. 빈 문자열이면 SajuV3Api가 헤더를
  /// 생략하고, 엔진 서버는 402(FREE_PASS_REQUIRED)로 안내한다 — 별도의
  /// "임시 우회" 분기를 두지 않는다(4차 지시서 원칙 그대로).
  static const String sajuFreePassToken = String.fromEnvironment(
    'SAJU_FREEPASS',
    defaultValue: '',
  );
}
