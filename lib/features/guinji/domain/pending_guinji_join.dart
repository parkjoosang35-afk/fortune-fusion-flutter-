/// [귀인지도 딥링크 비로그인 진입 버그 수정] 카톡 등으로 공유 링크를 받은
/// 지인이 앱에 로그인하지 않은 상태로 `/g/{token}` 딥링크에 진입하면,
/// 서버(`_shared.ts` requireUser)가 모든 귀인지도 API에 로그인을 강제하므로
/// `fetchInvite`가 401을 반환한다. 이 저장소는 그 시점의 토큰을 잠시
/// 보관했다가, 로그인 완료 후 원래 진입하려던 참여 화면으로 자동 복귀시키는
/// 용도로 쓰인다.
///
/// [PendingPassRequestStore와 분리하는 이유] `pending_pass_request.dart`의
/// 저장소는 `replayPendingPassRequest()`가 항상 `navigateWithPassGate(...,
/// requiresPass: true)`로 재생하도록 고정되어 있어, 재생 시 열림패스
/// 소비(PassProvider.consume) 로직을 함께 태운다. 귀인지도 참여는 결제도
/// 패스 소비도 없는 완전 별개 플로우이므로(절대 원칙: 결제없음), 그 로직에
/// 얹지 않고 전용의 가벼운 저장소를 따로 둔다.
class PendingGuinjiJoinStore {
  PendingGuinjiJoinStore._();

  static String? _token;

  static void save(String token) {
    _token = token;
  }

  /// 저장된 토큰을 꺼내면서 동시에 비운다(1회성 소비 — 중복 재실행 방지).
  static String? consume() {
    final token = _token;
    _token = null;
    return token;
  }

  static void clear() {
    _token = null;
  }
}

/// [버그 수정 — 온보딩 비로그인/프로필 미완성 진입] 위 [PendingGuinjiJoinStore]와
/// 동일한 목적(로그인/프로필 완성 후 원래 하려던 화면으로 자동 복귀)이지만,
/// "지인 초대 참여(토큰 필요)"가 아니라 "본인이 직접 지도 만들기(온보딩,
/// 토큰 없음)"를 시도했던 경우를 위한 전용 저장소다. 토큰 대신 단순 플래그만
/// 저장한다 — 온보딩 재진입은 어떤 파라미터도 필요 없이 `/guinji`로 돌아가기만
/// 하면 되기 때문이다.
class PendingGuinjiOnboardingStore {
  PendingGuinjiOnboardingStore._();

  static bool _pending = false;

  static void save() {
    _pending = true;
  }

  /// 저장된 플래그를 소비하면서 동시에 비운다(1회성 소비 — 중복 재실행 방지).
  static bool consume() {
    final pending = _pending;
    _pending = false;
    return pending;
  }

  static void clear() {
    _pending = false;
  }
}
