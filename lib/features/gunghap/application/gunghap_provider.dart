import 'package:flutter/foundation.dart';

import '../../auth/domain/user_model.dart';
import '../../home/domain/jeontong_eighty_report_builder.dart';
import '../../home/domain/manseryeok/saju_profile.dart';
import '../../home/domain/saju_engine.dart' show SajuResult;
import '../../home/domain/saju_interpreter.dart';
import '../../home/domain/user_profile_to_jeontong_adapter.dart';
import '../../guinji/domain/guinji_owner_saju_summary.dart';
import '../data/gunghap_repository.dart';
import '../domain/gunghap_saju_adapter.dart';

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
  /// 반환: 성공 시 true(이후 [inviteToken]/[sharePath] 사용 가능),
  /// 실패 시 false([error] 참고).
  Future<bool> createInviteForUser(UserModel user) async {
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
}
