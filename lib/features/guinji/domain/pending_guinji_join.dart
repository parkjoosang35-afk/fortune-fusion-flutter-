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

/// [버그 수정 — 사주 재입력] [GuinjiInputScreen]에서 사용자가 이미
/// 입력해 둔 폼 값(별명/생년월일/시간/양음력)을 로그인 리다이렉트 전에
/// 그대로 담아두는 불변 데이터 클래스. 사용자가 사주를 입력한 뒤 "다음"을
/// 눌렀을 때 비로그인이라는 이유만으로 로그인/회원가입 페이지로
/// 보내놓고, 완료 후 돌아왔을 때 입력값이 전부 사라져 처음부터 다시
/// 입력하라고 요구하는 것은 명백히 잘못된 UX다 — 이 클래스가 그 값을
/// 보존해 [GuinjiInputScreen]이 재진입 시 그대로 복원할 수 있게 한다.
class GuinjiMapEntryDraft {
  const GuinjiMapEntryDraft({
    required this.nickname,
    required this.year,
    required this.month,
    required this.day,
    required this.hour,
    required this.minute,
    required this.calendarIndex,
    required this.timeUnknown,
  });

  final String nickname;
  final String year;
  final String month;
  final String day;
  final String hour;
  final String minute;
  final int calendarIndex;
  final bool timeUnknown;
}

/// [2026 디자인 핸드오프 — `/guinji-map/*` 신규 8화면] 위
/// [PendingGuinjiOnboardingStore]와 동일한 목적(로그인/프로필 완성 후 원래
/// 하려던 화면으로 자동 복귀)이지만, 기존 `/guinji`(온보딩) 네임스페이스와
/// 완전히 분리된 신규 `/guinji-map/*` 플로우의 I(Input) 화면 전용 저장소다.
/// 두 네임스페이스는 파일/클래스/라우트를 절대 공유하지 않는다는 원칙에
/// 따라, 재진입 대상 화면도 [GuinjiOnboardingScreen]이 아닌
/// [GuinjiInputScreen]이어야 하므로 별도 스토어로 분리한다.
///
/// [버그 수정 — 사주 재입력] 기존에는 단순 `bool` 플래그만 저장해 재진입
/// 시 완전히 빈 [GuinjiInputScreen]을 새로 띄웠고, 사용자가 이미 입력한
/// 별명/생년월일/시간이 전부 사라져 "로그인 후 사주를 또 넣으라고 한다"는
/// 버그 리포트의 원인이 되었다. 이제 [GuinjiMapEntryDraft]로 실제 폼 값을
/// 함께 저장해, 재진입 시 그대로 복원한다.
class PendingGuinjiMapEntryStore {
  PendingGuinjiMapEntryStore._();

  static GuinjiMapEntryDraft? _draft;

  /// [하위 호환] draft 없이 단순 플래그로만 저장하고 싶은 호출부를 위해
  /// 남겨둔다(현재는 [GuinjiInputScreen]이 항상 draft를 채워 호출한다).
  static void save([GuinjiMapEntryDraft? draft]) {
    _draft = draft ??
        const GuinjiMapEntryDraft(
          nickname: '',
          year: '',
          month: '',
          day: '',
          hour: '',
          minute: '',
          calendarIndex: 0,
          timeUnknown: false,
        );
  }

  /// 저장된 draft를 꺼내면서 동시에 비운다(1회성 소비 — 중복 재실행 방지).
  /// 대기 중인 요청이 없으면 null을 반환한다.
  static GuinjiMapEntryDraft? consume() {
    final draft = _draft;
    _draft = null;
    return draft;
  }

  static void clear() {
    _draft = null;
  }
}
