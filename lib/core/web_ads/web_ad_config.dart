/// [웹 AdSense 광고 시스템 — STEP B] 광고 설정 중앙화 모델.
///
/// [배경 — 「신통방통 정통사주 진행과 동시에 웹 AdSense 광고 시스템 구축
/// 지시서」] 이 파일은 그 지시서 §4 "광고 설정을 중앙화한다"를 구현한다.
/// 각 화면이 광고 노출 여부를 직접 판단하지 않고, 이 [WebAdConfig] 하나만
/// 참조한다 — 나중에 "광고 전체 ON/OFF", "특정 서비스 광고 ON/OFF",
/// "특정 페이지 제외" 등을 서버(admin_web)에서 원격으로 끄고 켤 수 있도록
/// 확장 가능한 구조로 설계되었다(지금 당장 서버 연동까지 구현하지는
/// 않지만, 나중에 `WebAdConfig.fromJson(...)`을 추가하기만 하면 된다 —
/// 이 파일을 쓰는 화면 쪽 코드는 전혀 바뀌지 않는다).
///
/// [절대 원칙] 이 설정은 **Web 전용**이다. AdMob(Android/iOS, `AdmobAdIds`
/// 클래스)과는 완전히 분리된 별도 축이며, 이 파일이 AdMob 관련 코드를
/// 참조하거나 수정하는 일은 없다(지시서 §2 "절대로 하지 말 것 — 기존
/// Flutter AdMob 코드 수정 금지").
library;

/// 서비스(페이지) 식별자 — WebAdService가 광고 노출 여부를 조회할 때
/// 쓰는 키. 지시서 §6 "적용 대상" 6개 서비스 + 홈을 포함한다.
enum WebAdSurface { home, sajuRenewal, tarot, wishRoom, guinji, face, palm }

/// AdSense가 지원하는 광고 포맷 중, 지시서 §1/§3이 언급하는 4종류.
/// Auto ads(anchor/vignette/inPage)는 보통 Google이 자동으로 배치를
/// 결정하지만, 수동 배치형(banner/inPage)을 특정 화면에 직접 심을 수 있게
/// 포맷을 구분해 둔다.
enum WebAdFormat { banner, inPage, anchor, vignette }

/// [중앙 설정] 전체 ON/OFF + 서비스별 ON/OFF + 포맷별 ON/OFF를 모두 한
/// 곳에서 관리한다. 현재는 코드 상수(compile-time 안전 기본값)로 시작하되,
/// 추후 admin_web 원격 설정과 연결할 때는 이 클래스의 정적 getter들을
/// "원격 설정을 반영한 값"으로 바꾸기만 하면 된다 — 호출부(위젯들)는
/// 전혀 수정할 필요가 없다.
class WebAdConfig {
  WebAdConfig._();

  /// [전체 스위치] false면 어떤 화면에서도 광고를 그리지 않는다.
  /// AdSense 사이트 승인 전(지시서 §12 "AdSense 승인 전에는 실제 광고가
  /// 바로 나오는 것으로 가정해서 개발하면 안 된다")에는 기본값 false로
  /// 두어, 승인/퍼블리셔 ID 발급이 끝난 뒤 명시적으로 true로 전환한다.
  static const bool enabled = bool.fromEnvironment(
    'WEB_ADS_ENABLED',
    defaultValue: false,
  );

  /// AdSense 퍼블리셔 ID(ca-pub-XXXXXXXXXXXXXXXX). 승인 전에는 빈 문자열
  /// — [WebAdService]가 이 값이 비어 있으면 스크립트 자체를 주입하지
  /// 않는다(§12 안전장치, 빈 publisher ID로 AdSense 스크립트를 로드하면
  /// 콘솔 오류만 쌓인다).
  static const String publisherId = String.fromEnvironment(
    'ADSENSE_PUBLISHER_ID',
    defaultValue: '',
  );

  /// [개발 단계 전용 — STEP F 레이아웃 검증용] 아직 승인/퍼블리셔 ID가
  /// 없어 실제 광고가 그려지지 않는 동안에도, "이 자리에 광고가 들어갈
  /// 것"임을 개발자가 눈으로 확인할 수 있도록 테두리+라벨만 있는 더미
  /// 자리표시자를 그린다(실제 광고 콘텐츠/클릭 영역이 아니다 — 진짜
  /// 광고가 아니므로 AdSense 정책과 무관).
  ///
  /// [주의] 이 값은 샌드박스 프리뷰 단계의 `flutter build web --release`
  /// 에서도 켜져 있어야 레이아웃을 확인할 수 있으므로 `kDebugMode`가
  /// 아니라 별도의 dart-define으로 분리했다. 운영 배포 시 실제
  /// 광고(enabled=true && publisherId 설정)가 켜지면 이 플레이스홀더
  /// 분기 자체가 호출되지 않으므로 신경 쓸 필요가 없고, 혹시 운영에서
  /// enabled=false 상태로 잠시 유지하는 기간이 있다면 그때는
  /// `--dart-define=WEB_AD_SHOW_PLACEHOLDER=false`로 꺼서 실제 사용자
  /// 화면에는 아무 것도 보이지 않게 한다.
  static const bool showPlaceholderWhenDisabled = bool.fromEnvironment(
    'WEB_AD_SHOW_PLACEHOLDER',
    defaultValue: true,
  );

  /// 서비스별 ON/OFF. 지시서 §10 STEP E~G 순서(정통사주 먼저 → 안정화
  /// 후 나머지)를 코드로 강제한다 — 아직 적용하지 않은 서비스는 이 맵에서
  /// false로 두면, 나중에 WebAdBanner 등을 그 화면에 심어도 광고가 뜨지
  /// 않아 안전하다(= "붙여놓고 나중에 서비스별로 켠다"가 가능한 구조).
  static const Map<WebAdSurface, bool> _surfaceEnabled = {
    // [STEP E] 정통사주를 1번 적용 대상으로 삼는다(지시서 §6 ①, §11).
    WebAdSurface.sajuRenewal: true,
    // [STEP G] 타로를 2번 적용 대상으로 전환한다(일반 AdSense만, Rewarded는
    // 별도로 보류 — WEB_AD_SCOPE_POLICY.md 참고).
    WebAdSurface.tarot: true,
    // [소원방 영구 제외 — 사용자 확정 지시, WEB_AD_SCOPE_POLICY.md]
    // 소원방(wishRoom)은 어떤 이유로도 true로 전환하지 않는다. 향후 전체
    // 웹 광고 확장 작업에서도 자동 적용 대상에 포함시키지 않는다.
    WebAdSurface.wishRoom: false,
    // 아직 안정화 전 — 추후 순서대로(귀인지도→관상→손금) true로 전환.
    WebAdSurface.home: false,
    WebAdSurface.guinji: false,
    WebAdSurface.face: false,
    WebAdSurface.palm: false,
  };

  /// 포맷별 ON/OFF(지시서 §5 "우선 일반 광고부터" — 보상형은 별도 축인
  /// [WebAdFormat]에 아예 존재하지 않으므로 이 맵에 넣을 수조차 없다).
  static const Map<WebAdFormat, bool> _formatEnabled = {
    WebAdFormat.banner: true,
    WebAdFormat.inPage: true,
    WebAdFormat.anchor: true,
    WebAdFormat.vignette: true,
  };

  /// 특정 서비스 화면에서 지금 광고를 그려도 되는지 최종 판단.
  /// enabled(전체 스위치) → publisherId 존재 → 서비스별 스위치 3단계를
  /// 모두 통과해야 true. 이 한 메서드만 호출부에서 체크하면 된다.
  static bool isSurfaceActive(WebAdSurface surface) {
    if (!enabled) return false;
    if (publisherId.isEmpty) return false;
    return _surfaceEnabled[surface] ?? false;
  }

  /// 특정 포맷이 전역적으로 활성화되어 있는지.
  static bool isFormatActive(WebAdFormat format) {
    if (!enabled) return false;
    if (publisherId.isEmpty) return false;
    return _formatEnabled[format] ?? false;
  }

  /// 서비스 + 포맷 둘 다 켜져 있어야 광고를 그린다(위젯에서 쓰는 단일
  /// 진입점 — [WebAdService.shouldShow] 가 이 메서드를 그대로 감싼다).
  static bool shouldShow(WebAdSurface surface, WebAdFormat format) {
    return isSurfaceActive(surface) && isFormatActive(format);
  }

  /// [STEP F 레이아웃 검증용] 서비스별 스위치가 "아직 적용 대상이
  /// 아님(false)"으로 꺼져 있는 화면에는 플레이스홀더도 보이지 않게
  /// 한다 — enabled/publisherId와 무관하게 서비스 스위치만 확인한다
  /// (enabled=false인 개발 단계에서도 "이 화면은 STEP E 적용 대상"
  /// 임을 미리 확인할 수 있어야 하므로).
  static bool isSurfacePlaceholderAllowed(WebAdSurface surface) {
    return _surfaceEnabled[surface] ?? false;
  }
}
