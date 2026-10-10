/// [신통방통 앱·웹 비회원 둘러보기 및 로그인 연속성 — 정통사주 리뉴얼]
/// 귀인지도(`pending_guinji_join.dart`의 `PendingGuinjiMapEntryStore`/
/// `GuinjiMapEntryDraft`)와 완전히 동일한 목적·구조의 전용 저장소다.
///
/// [문제] 기존에는 `SajuRenewalHomeScreen._start()`가 02(출생정보 입력,
/// [BirthInputScreen]) 화면에 진입하기 *전*에 로그인을 강제했다. 그런데
/// 02 화면은 "사주 분석 시작하기"를 누르는 *제출 시점*에만 서버 저장
/// ([AuthProvider.updateProfile])이 필요하므로, 02 화면 자체는 게스트도
/// 자유롭게 입력할 수 있어야 한다(귀인지도 패턴과 동일). 진입 시점에 로그인을
/// 강제하면 게스트가 입력을 전혀 시작해 볼 수 없고, 설령 입력 중간에
/// 로그인 페이지로 보내더라도 기존에는 그 입력값을 전혀 보존하지 않아
/// 로그인 완료 후 처음부터 다시 입력해야 하는 UX 결함이 있었다.
///
/// [해결] 로그인 게이트를 02 화면 "진입 시점"에서 "제출 시점"
/// ([BirthInputScreen._submit])으로 옮기고, 비로그인 상태로 제출을
/// 시도하면 그 시점까지 입력된 값을 이 저장소에 담아 두었다가, 로그인/
/// 회원가입 완료 후 [BirthInputScreen]을 `initialDraft`로 다시 열어 그대로
/// 복원한다 — 사용자는 어떤 값도 다시 입력할 필요가 없다.
class SajuEntryDraft {
  const SajuEntryDraft({
    required this.nickname,
    required this.year,
    required this.month,
    required this.day,
    required this.timeRangeStart,
    required this.gender,
    required this.isLunar,
    required this.birthPlace,
  });

  final String nickname;
  final int year;
  final int month;
  final int day;

  /// `BirthdayPickerTimeValue.rangeStart`(12지신 시간대 시작 시) 또는
  /// null(="시간 모름"). [BirthInputScreen._zhiTimeForHour]로 그대로
  /// 역변환할 수 있어, 전체 [BirthdayPickerTimeValue]를 직렬화하지 않고도
  /// 복원이 가능하다.
  final int? timeRangeStart;

  /// 'male' | 'female'
  final String gender;
  final bool isLunar;
  final String birthPlace;
}

/// [PendingGuinjiMapEntryStore와 동일한 1회성 메모리 저장소 패턴] 정통사주
/// 02(출생정보 입력) 화면 전용. 앱 프로세스가 완전히 종료되는 경우(예: 외부
/// 브라우저로 이동했다가 OS가 메모리 확보를 위해 kill)까지는 대비하지
/// 않는다 — 로그인은 앱 내부 네비게이션(`/login`)만으로 완료되므로
/// 귀인지도와 동일하게 메모리 static 필드로 충분하다.
class PendingSajuEntryStore {
  PendingSajuEntryStore._();

  static SajuEntryDraft? _draft;

  static void save(SajuEntryDraft draft) {
    _draft = draft;
  }

  /// 저장된 draft를 꺼내면서 동시에 비운다(1회성 소비 — 중복 재실행 방지).
  /// 대기 중인 요청이 없으면 null을 반환한다.
  static SajuEntryDraft? consume() {
    final draft = _draft;
    _draft = null;
    return draft;
  }

  static void clear() {
    _draft = null;
  }
}
