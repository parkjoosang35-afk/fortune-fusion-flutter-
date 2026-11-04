import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../auth/domain/user_model.dart';
import '../../home/domain/jeontong_eighty_report_builder.dart';
import '../../home/domain/manseryeok/saju_profile.dart';
import '../../home/domain/saju_engine.dart' show SajuResult;
import '../../home/domain/saju_interpreter.dart';
import '../../home/domain/user_profile_to_jeontong_adapter.dart';
import '../../guinji/domain/guinji_owner_saju_summary.dart';
import '../data/gunghap_repository.dart';
import '../domain/gunghap_saju_adapter.dart';

/// [멱등성 — requestKey 생성기] 직접 궁합 생성 "확인" 버튼을 누를 때마다
/// 새 UUID를 만든다. 동일 버튼 클릭의 네트워크 재시도는 호출부가 같은
/// 값을 재사용해야 하므로, UUID 생성 자체는 [GunghapProvider.createDirect]
/// 호출 시점(버튼 클릭 시점)에 1회만 수행한다 — Provider 내부에 캐시하지
/// 않고 매 호출마다 새로 생성하는 이유는, 호출부(화면)가 재시도 시 동일한
/// `createDirect()` 호출을 반복하는 것이 아니라 "동일 HTTP 요청"을 재시도
/// 하는 구조(http 패키지 수준 재시도 없음 — 수동 재시도 버튼만 존재)라서,
/// 화면이 재시도를 위해 같은 `requestKey` 문자열을 직접 들고 있다가
/// 동일 값으로 다시 [createDirect]를 호출해야 하기 때문이다(아래
/// [createDirect] 문서 참고 — `requestKey` 파라미터를 선택적으로 받아
/// 재사용 가능하게 설계했다).
const _uuid = Uuid();

/// 궁합지도(Gunghap Map) 전역 상태 — [GunghapRepository]를 감싸고,
/// 초대/게스트 제출/결과/잠금해제 화면들이 공유하는 상태를 관리한다.
///
/// [절대 원칙] 이 Provider는 결제·재화를 직접 다루지 않는다 — 100
/// 복주머니 차감은 전부 서버(`/unlock`) 트랜잭션 내부에서만 발생한다.
/// 이 Provider는 그 결과(`amountCharged`/`balanceAfter`)를 그대로
/// 전달할 뿐이며, 화면이 이후 `LuckPouchProvider.load()`를 호출해
/// 앱 전역에 표시되는 잔액을 재동기화한다([GuinjiProvider]와 동일한
/// 관례 — 재화 단일화 원칙).
///
/// [패턴 출처] 구조는 [GuinjiProvider]와 동일하다(§6 "기존 귀인지도
/// 엔진의 검증된 기능을 분석하여 재사용한다" 원칙).
class GunghapProvider extends ChangeNotifier {
  GunghapProvider(this._repository);

  final GunghapRepository _repository;

  bool _isLoading = false;
  String? _error;
  String? _errorCode;

  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get errorCode => _errorCode;

  /// 방금 생성한 초대의 토큰/공유경로(초대 화면이 카카오 공유에 사용).
  String? _inviteToken;
  String? _sharePath;
  String? get inviteToken => _inviteToken;
  String? get sharePath => _sharePath;

  /// [흐름 정합성] 초대자 본인의 실계산 사주 요약(결과 화면에서 "나는
  /// 어떤 사람인지" 등에 재사용 가능 — [GuinjiProvider]와 동일 패턴).
  GuinjiOwnerSajuSummary? _ownerSajuSummary;
  GuinjiOwnerSajuSummary? get ownerSajuSummary => _ownerSajuSummary;

  /// 마지막으로 조회/생성된 궁합 결과(그대로 결과 화면이 사용).
  Map<String, dynamic>? _result;
  Map<String, dynamic>? get result => _result;

  /// [Phase 4 — 궁합스토리] `GET /gunghap/my-results` 조회 결과(DIRECT +
  /// INVITE 통합, 서버가 이미 최신순 정렬해 반환). 마이페이지 궁합스토리
  /// 목록 화면이 그대로 사용한다 — 로컬 저장소/하드코딩 데이터가 아니라
  /// 항상 이 서버 응답만을 표시한다.
  List<Map<String, dynamic>> _myResults = const [];
  List<Map<String, dynamic>> get myResults => _myResults;
  bool _isLoadingMyResults = false;
  bool get isLoadingMyResults => _isLoadingMyResults;

  /// [Phase 4 — 직접 궁합 생성 진행 상태] 입력 화면이 중복 제출(연속
  /// 탭)을 막는 데 사용한다. [isLoading]과 분리한 이유는, 이 플래그가
  /// true인 동안에도 다른 화면(궁합스토리 목록 등)이 동시에
  /// [isLoading]을 관찰해 스피너를 켜는 일이 없도록 하기 위함이다.
  bool _isCreatingDirect = false;
  bool get isCreatingDirect => _isCreatingDirect;

  /// [Phase 4 — 삭제 진행 상태] 궁합스토리 목록에서 특정 항목 삭제 중인
  /// resultId. null이면 삭제 중인 항목이 없음 — 목록 화면이 이 값으로
  /// 개별 행의 로딩 상태를 표시한다(전체 목록을 다시 그리지 않고 해당
  /// 행만 비활성화할 수 있도록).
  String? _deletingResultId;
  String? get deletingResultId => _deletingResultId;

  /// [전수검수 원칙 — 계정 격리] 로그아웃/회원탈퇴 시 메모리 상태를
  /// 완전히 초기화한다(다른 Provider와 동일한 관례).
  void clearOnLogout() {
    _isLoading = false;
    _error = null;
    _errorCode = null;
    _inviteToken = null;
    _sharePath = null;
    _ownerSajuSummary = null;
    _result = null;
    _myResults = const [];
    _isLoadingMyResults = false;
    _isCreatingDirect = false;
    _deletingResultId = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    _errorCode = null;
    notifyListeners();
  }

  void _cacheOwnerSajuSummary(SajuResult saju) {
    final rules = SajuRules.cachedOrNull;
    if (rules == null) {
      debugPrint('[GunghapProvider] [_cacheOwnerSajuSummary] SajuRules 미로드 -> 요약 생략');
      return;
    }
    try {
      _ownerSajuSummary = GuinjiOwnerSajuSummary.fromSajuResult(saju, rules);
    } catch (e) {
      debugPrint('[GunghapProvider] [_cacheOwnerSajuSummary] 실패 -> $e');
    }
  }

  /// 로그인 회원 [UserModel]의 저장된 생년월일로 사주를 계산해 초대장을
  /// 생성한다(`POST /gunghap/invites`, 인증 필수).
  ///
  /// [금지사항 준수] 이 메서드는 상대방(게스트)의 생년월일을 어떤
  /// 형태로도 입력받지 않는다 — 오직 호출자 본인의 [UserModel] 저장
  /// 프로필만 사용한다.
  ///
  /// [2026-11 궁합 주제 반영 지시서 — Section 1] [majorId]/[subName]은
  /// 사용자가 초대 생성 전 화면(`GunghapMajorScreen`/`GunghapSubScreen`)
  /// 에서 고른 궁합 분야/세부 카테고리다. 둘 다 선택사항이지만, 지정하면
  /// 카카오 공유 메시지와 게스트/소유자 결과 화면이 모두 해당 주제
  /// 1개만 보여주게 된다(서버 측 필터링).
  ///
  /// 반환: 성공 시 true(이후 [inviteToken]/[sharePath] 사용 가능),
  /// 실패 시 false([error] 참고).
  Future<bool> createInviteForUser(
    UserModel user, {
    String? majorId,
    String? subName,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final jeontongInput = userModelToJeontongInput(user);
    if (jeontongInput == null) {
      _isLoading = false;
      _error = '생년월일 정보가 없어 사주를 계산할 수 없습니다. 마이페이지에서 프로필을 먼저 완성해 주세요.';
      notifyListeners();
      return false;
    }

    try {
      final kst = jeontongInput.birthDateTimeUtc.add(const Duration(hours: 9));
      final sajuGender = jeontongInput.gender == 'F' ? 'female' : 'male';
      final built = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
        kst: kst,
        gender: sajuGender,
        isLunar: jeontongInput.isLunar,
        isLeapMonth: jeontongInput.effectiveIsLeapMonth,
        referenceDate: DateTime.now(),
      );
      final SajuProfile profile = built.profile;
      final sajuJson = gunghapSajuInputFromProfile(profile);
      _cacheOwnerSajuSummary(built.saju);

      final result = await _repository.createInvite(
        ownerName: user.nickname,
        saju: sajuJson,
        majorId: majorId,
        subName: subName,
      );
      if (!result.success || result.data == null) {
        _isLoading = false;
        _error = result.errorMessage ?? '초대장 생성에 실패했습니다.';
        _errorCode = result.errorCode;
        notifyListeners();
        return false;
      }

      final data = result.data!;
      _inviteToken = data['token'] as String?;
      _sharePath = data['sharePath'] as String?;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _error = '사주 계산 중 오류가 발생했습니다: $e';
      notifyListeners();
      return false;
    }
  }

  /// GET /gunghap/g/{token} — 게스트 딥링크 진입 시 초대 토큰 유효성
  /// 확인(인증 불필요). 실패해도 화면 전체를 막지 않도록 null로 반환할
  /// 수 있다.
  ///
  /// 반환: {ownerName, joined, resultId} 또는 null(실패 시 [error] 참고).
  Future<Map<String, dynamic>?> fetchInviteToken(String token) async {
    _error = null;
    final result = await _repository.fetchInviteToken(token);
    if (!result.success || result.data == null) {
      _error = result.errorMessage ?? '초대 링크를 확인할 수 없습니다.';
      _errorCode = result.errorCode;
      notifyListeners();
      return null;
    }
    notifyListeners();
    return result.data;
  }

  /// POST /gunghap/g/{token}/join — 게스트(비로그인) 본인 사주정보 제출.
  ///
  /// [절대 원칙] [UserModel]이나 로그인 상태와 완전히 무관하게 호출
  /// 가능해야 한다(회원가입 불필요 원칙).
  ///
  /// 반환: 성공 시 결과 데이터(무료 등급 8개 분야 포함), 실패 시 null
  /// ([error] 참고).
  Future<Map<String, dynamic>?> joinAnonymous({
    required String token,
    required String name,
    required DateTime birthDate,
    bool isLunar = false,
    bool isLeapMonth = false,
    String? birthTime, // 'HH:mm' | null
    required String gender, // 'male' | 'female'
    required bool agreePolicy,
    required bool agreeAge14,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final birthDateStr =
        '${birthDate.year.toString().padLeft(4, '0')}-'
        '${birthDate.month.toString().padLeft(2, '0')}-'
        '${birthDate.day.toString().padLeft(2, '0')}';

    final result = await _repository.joinAnonymous(
      token: token,
      name: name,
      birthDate: birthDateStr,
      calendarType: isLunar ? 'lunar' : 'solar',
      isLeapMonth: isLunar ? isLeapMonth : false,
      birthTime: birthTime,
      gender: gender,
      agreePolicy: agreePolicy,
      agreeAge14: agreeAge14,
    );

    _isLoading = false;
    if (!result.success || result.data == null) {
      _error = result.errorMessage ?? '제출에 실패했습니다.';
      _errorCode = result.errorCode;
      notifyListeners();
      return null;
    }

    _result = result.data;
    notifyListeners();
    return result.data;
  }

  /// GET /gunghap/results/{resultId} — 궁합 결과 조회(초대자 본인 인증
  /// 필수). [_result]를 갱신한다.
  ///
  /// 반환: 성공 시 true([result] 참고), 실패 시 false([error]/[errorCode]
  /// 참고 — 'UNAUTHORIZED'면 로그인 유도, 'FORBIDDEN'이면 소유자가
  /// 아님을 의미).
  Future<bool> fetchResult(String resultId) async {
    _isLoading = true;
    _error = null;
    _errorCode = null;
    notifyListeners();

    final result = await _repository.fetchResult(resultId);
    _isLoading = false;
    if (!result.success || result.data == null) {
      _error = result.errorMessage ?? '궁합 결과 조회에 실패했습니다.';
      _errorCode = result.errorCode;
      notifyListeners();
      return false;
    }

    _result = result.data;
    notifyListeners();
    return true;
  }

  /// POST /gunghap/results/{resultId}/unlock — 상세 보고서 잠금해제(100
  /// 복주머니, 초대자 본인 인증 필수, 멱등).
  ///
  /// [잔액 부족] 서버가 `INSUFFICIENT_BALANCE`(400)를 반환하면 [error]에
  /// 그 메시지를, [errorCode]에 'INSUFFICIENT_BALANCE'를 담아 false를
  /// 반환한다 — 화면은 이 코드를 보고 "복주머니가 부족합니다" 안내를
  /// 표시해야 한다.
  ///
  /// 성공 시 [_result]에 `unlocked:true`와 `detail`(8개 분야 전체
  /// 서술)을 병합해 갱신한다(재조회 없이 화면이 바로 반영 가능).
  ///
  /// 반환: 성공 시 true, 실패 시 false.
  Future<bool> unlock(String resultId) async {
    _isLoading = true;
    _error = null;
    _errorCode = null;
    notifyListeners();

    final result = await _repository.unlock(resultId);
    _isLoading = false;
    if (!result.success || result.data == null) {
      _error = result.errorMessage ?? '잠금해제에 실패했습니다.';
      _errorCode = result.errorCode;
      notifyListeners();
      return false;
    }

    final data = result.data!;
    if (_result != null) {
      _result = {
        ..._result!,
        'unlocked': true,
        'detail': data['detail'],
      };
    }
    notifyListeners();
    return true;
  }

  /// [Phase 4 — 멱등성] 직접 궁합 생성 "확인" 버튼을 누르는 시점에
  /// 호출부(화면)가 1회 호출해 `requestKey`를 발급받는다. 화면은 이 값을
  /// 로컬 상태로 들고 있다가, 같은 버튼 클릭에 대한 네트워크 재시도에는
  /// 동일 값을 [createDirect]의 `requestKey` 인자로 재사용하고, 제출이
  /// 최종 성공하거나 사용자가 화면을 벗어나면 폐기해야 한다. 새로 "확인"을
  /// 누르는(=의도적으로 새 조회를 시작하는) 경우에는 이 메서드를 다시
  /// 호출해 새 값을 받아야 한다 — 그래야 서버가 "재시도"와 "새 조회"를
  /// 구분할 수 있다(`gunghap_repository.dart` [GunghapRepository.createDirect]
  /// 문서 참고).
  String newDirectRequestKey() => _uuid.v4();

  /// POST /gunghap/direct — 로그인 회원이 상대방에게 초대장을 보내지
  /// 않고 직접 상대방 정보를 입력해 즉시 궁합 결과를 생성한다.
  ///
  /// [B안 비대칭 신뢰 구조] 호출자([user]) 본인의 사주는
  /// [createInviteForUser]와 완전히 동일한 방식(`JeontongReportBuilder` +
  /// `gunghapSajuInputFromProfile`)으로 이 메서드 내부에서 계산한다 —
  /// 상대방 정보만 원본 그대로 서버에 전달한다.
  ///
  /// [절대 금지] 이 메서드는 어떤 경우에도 초대장을 생성하지 않는다 —
  /// `_repository.createInvite()`를 호출하지 않으며 [_inviteToken]을
  /// 건드리지 않는다.
  ///
  /// [requestKey] 호출부가 [newDirectRequestKey]로 미리 발급받은 값을
  /// 그대로 전달해야 한다(재시도 시에는 동일 값 재사용).
  ///
  /// 반환: 성공 시 결과 데이터(DIRECT, 무료 등급 8개 분야 포함 — [_result]에도
  /// 저장됨), 실패 시 null([error]/[errorCode] 참고).
  Future<Map<String, dynamic>?> createDirect({
    required UserModel user,
    required String requestKey,
    required String partnerName,
    required DateTime partnerBirthDate,
    bool partnerIsLunar = false,
    bool partnerIsLeapMonth = false,
    String? partnerBirthTime, // 'HH:mm' | null
    required String partnerGender, // 'male' | 'female'
    String? majorId,
    String? subName,
  }) async {
    _isCreatingDirect = true;
    _error = null;
    _errorCode = null;
    notifyListeners();

    final jeontongInput = userModelToJeontongInput(user);
    if (jeontongInput == null) {
      _isCreatingDirect = false;
      _error = '생년월일 정보가 없어 사주를 계산할 수 없습니다. 마이페이지에서 프로필을 먼저 완성해 주세요.';
      notifyListeners();
      return null;
    }

    try {
      final kst = jeontongInput.birthDateTimeUtc.add(const Duration(hours: 9));
      final sajuGender = jeontongInput.gender == 'F' ? 'female' : 'male';
      final built = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
        kst: kst,
        gender: sajuGender,
        isLunar: jeontongInput.isLunar,
        isLeapMonth: jeontongInput.effectiveIsLeapMonth,
        referenceDate: DateTime.now(),
      );
      final SajuProfile profile = built.profile;
      final mySajuJson = gunghapSajuInputFromProfile(profile);
      _cacheOwnerSajuSummary(built.saju);

      final partnerBirthDateStr =
          '${partnerBirthDate.year.toString().padLeft(4, '0')}-'
          '${partnerBirthDate.month.toString().padLeft(2, '0')}-'
          '${partnerBirthDate.day.toString().padLeft(2, '0')}';

      final result = await _repository.createDirect(
        requestKey: requestKey,
        mySaju: mySajuJson,
        myName: user.nickname,
        partnerName: partnerName,
        partnerBirthDate: partnerBirthDateStr,
        partnerCalendarType: partnerIsLunar ? 'lunar' : 'solar',
        partnerIsLeapMonth: partnerIsLunar ? partnerIsLeapMonth : false,
        partnerBirthTime: partnerBirthTime,
        partnerGender: partnerGender,
        majorId: majorId,
        subName: subName,
      );

      _isCreatingDirect = false;
      if (!result.success || result.data == null) {
        _error = result.errorMessage ?? '궁합 생성에 실패했습니다.';
        _errorCode = result.errorCode;
        notifyListeners();
        return null;
      }

      _result = result.data;
      notifyListeners();
      return result.data;
    } catch (e) {
      _isCreatingDirect = false;
      _error = '사주 계산 중 오류가 발생했습니다: $e';
      notifyListeners();
      return null;
    }
  }

  /// GET /gunghap/my-results — 궁합스토리: 로그인 회원 본인의 DIRECT +
  /// INVITE 궁합 결과를 모두 조회한다. [_myResults]를 갱신한다.
  ///
  /// [절대 원칙] 로컬 저장소나 하드코딩 데이터를 전혀 쓰지 않는다 —
  /// 항상 이 서버 호출 결과만을 [_myResults]에 반영한다.
  ///
  /// 반환: 성공 시 true([myResults] 참고), 실패 시 false([error]/[errorCode]
  /// 참고).
  Future<bool> fetchMyResults() async {
    _isLoadingMyResults = true;
    _error = null;
    _errorCode = null;
    notifyListeners();

    final result = await _repository.fetchMyResults();
    _isLoadingMyResults = false;
    if (!result.success || result.data == null) {
      _error = result.errorMessage ?? '궁합스토리를 불러오지 못했습니다.';
      _errorCode = result.errorCode;
      notifyListeners();
      return false;
    }

    final itemsRaw = result.data!['items'];
    _myResults = itemsRaw is List
        ? itemsRaw.whereType<Map<String, dynamic>>().toList()
        : const [];
    notifyListeners();
    return true;
  }

  /// DELETE /gunghap/results/{resultId} — 궁합스토리 항목 삭제(소프트
  /// 삭제, 소유자 전용). 성공 시 [_myResults]에서 해당 항목을 즉시
  /// 제거해 호출부가 별도로 [fetchMyResults]를 다시 부르지 않아도 목록이
  /// 바로 갱신되게 한다(다만 화면은 서버 진실을 재확인하고 싶으면
  /// [fetchMyResults]를 추가로 호출해도 무방 — §3 "삭제 후 목록 갱신"
  /// 요구사항은 이 로컬 제거만으로 이미 충족된다).
  ///
  /// 반환: 성공 시 true, 실패 시 false([error]/[errorCode] 참고 —
  /// 'NOT_FOUND'면 이미 삭제됨, 'FORBIDDEN'이면 소유자가 아님).
  Future<bool> deleteResult(String resultId) async {
    _deletingResultId = resultId;
    _error = null;
    _errorCode = null;
    notifyListeners();

    final result = await _repository.deleteResult(resultId);
    _deletingResultId = null;
    if (!result.success) {
      _error = result.errorMessage ?? '삭제하지 못했습니다.';
      _errorCode = result.errorCode;
      notifyListeners();
      return false;
    }

    _myResults = _myResults
        .where((item) => item['resultId'] != resultId)
        .toList();
    notifyListeners();
    return true;
  }
}
