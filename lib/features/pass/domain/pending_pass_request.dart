/// [STEP8-2 로그인 필수 UI] 비로그인 상태에서 프리패스가 필요한 카테고리를
/// 탭했을 때 "원래 하려던 요청"을 잠시 보관해두는 값 객체.
///
/// [navigateWithPassGate]/`_openMatrixEntry`가 로그인 필요 안내를 띄우기
/// 직전에 이 값을 [PendingPassRequestStore]에 저장하고, 로그인 성공 후
/// ProfileCheckScreen이 홈으로 이동을 완료하면 저장된 요청을 그대로
/// 재실행한다(사용자가 다시 카테고리를 찾아 탭할 필요가 없도록).
class PendingPassRequest {
  const PendingPassRequest({
    required this.title,
    required this.route,
    this.arguments,
    this.categoryKey,
  });

  /// 프리패스 게이트에 표시할 카테고리/화면 이름(안내 문구용).
  final String title;

  /// 로그인 완료 후 이동할 라우트.
  final String route;

  /// [route]로 이동할 때 함께 전달할 인자(딥링크용, 선택).
  final Object? arguments;

  /// 서버 카테고리별 이용횟수 검증에 사용할 categoryKey(선택).
  final String? categoryKey;
}

/// 앱 전역에서 하나만 존재하는 pending 요청 보관소.
///
/// 화면 전환(Provider 재생성 등)에도 살아있어야 하므로 static 필드로 둔다.
/// 동시에 하나의 요청만 대기할 수 있으면 충분하다(사용자가 로그인 화면으로
/// 이동한 이후에는 원래 화면과의 상호작용이 불가능하므로 큐가 필요 없음).
class PendingPassRequestStore {
  PendingPassRequestStore._();

  static PendingPassRequest? _pending;

  static void save(PendingPassRequest request) {
    _pending = request;
  }

  /// 저장된 요청을 꺼내면서 동시에 비운다(1회성 소비 — 중복 재실행 방지).
  static PendingPassRequest? consume() {
    final request = _pending;
    _pending = null;
    return request;
  }

  static void clear() {
    _pending = null;
  }
}
