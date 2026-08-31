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
}
