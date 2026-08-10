import 'package:flutter/foundation.dart';
import '../../../core/domain/assets/open_pass_state.dart';
import '../data/pass_repository.dart';
import '../domain/pass_model.dart';
import '../domain/open_pass_models.dart';

/// 열림패스(AlarmPass) 전역 Provider — 홈 화면 상태바 + 열림패스 섹션에서 공유.
/// [문서5 홈화면섹션구조표 승인 반영] 홈 상단 상태바에 remainingSec 카운트다운 노출,
/// 열림패스 섹션에서 정책 목록(CTA 카드) + 발급/게이트체크 액션을 제공한다.
///
/// [열림패스/복주머니/복주머니 통합정책 §7 테스트 가능 상태] [debugForceState]로
/// 실 서버 호출 없이 강제 ON/OFF/만료 상태를 만들 수 있다. 개발자 QA 전용이며,
/// 호출부(마이페이지 테스트 패널)에서 kDebugMode로 노출 여부를 가드한다.
class PassProvider extends ChangeNotifier {
  final PassRepository _repository;
  PassProvider(this._repository);

  List<PassPolicyModel> _policies = [];
  PassStatusModel _status = PassStatusModel.inactive();
  bool _isLoading = false;
  String? _lastError;
  // [STEP8 - Flutter categoryKey 연동] 마지막 consume() 실패의 서버측 reason
  // ('NO_ACTIVE_PASS' | 'CATEGORY_LIMIT_REACHED'). 화면단에서 카테고리 한도
  // 초과 안내를 일반 "패스 없음" 안내와 다르게 보여줄 때 사용(선택적).
  String? _lastErrorReason;

  /// true이면 [load]가 실 API 응답으로 [_status]를 덮어쓰지 않는다
  /// (테스트 모드에서 강제 지정한 상태를 유지하기 위함).
  bool _debugOverride = false;

  List<PassPolicyModel> get policies => _policies;
  PassStatusModel get status => _status;
  bool get isActive => _status.isActive;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
  String? get lastErrorReason => _lastErrorReason;

  /// [OpenPassState](inactive/active/expired + 남은 시간)로 정규화한 값.
  /// 화면/AccessChecker는 이 값 또는 AccessChecker를 통해서만 상태를 본다.
  OpenPassState get openPassState => OpenPassState.fromModel(_status);

  bool get isDebugOverrideActive => _debugOverride;

  /// 홈 화면 진입 시 정책 목록 + 현재 활성 상태를 동시에 로드한다.
  Future<void> load() async {
    _isLoading = true;
    notifyListeners();

    final policiesResult = await _repository.getPolicies();
    if (policiesResult.success) _policies = policiesResult.data!;

    if (!_debugOverride) {
      final statusResult = await _repository.getStatus();
      if (statusResult.success) _status = statusResult.data!;
    }

    _isLoading = false;
    notifyListeners();
  }

  /// [열림패스 테스트 모드] 실 서버 호출 없이 상태를 강제 지정한다.
  /// - [OpenPassStatus.active] + [remaining]으로 "강제 ON"(임의 남은시간)
  /// - [OpenPassStatus.inactive]로 "강제 OFF"(발급 이력 없음)
  /// - [OpenPassStatus.expired]로 "강제 만료"(발급 이력은 있으나 시간 종료)
  ///
  /// 이후 [clearDebugOverride]를 호출하기 전까지 [load]는 실 서버 상태로
  /// 덮어쓰지 않는다(QA 중 화면 전환/새로고침에도 테스트 상태 유지).
  void debugForceState(
    OpenPassStatus status, {
    Duration remaining = const Duration(minutes: 60),
    String policyName = '[테스트] 프리패스',
  }) {
    _debugOverride = true;
    switch (status) {
      case OpenPassStatus.active:
        final expiresAt = DateTime.now().add(remaining);
        _status = PassStatusModel(
          isActive: true,
          policyName: policyName,
          activatedAt: DateTime.now(),
          expiresAt: expiresAt,
          remainingSec: remaining.inSeconds,
        );
        break;
      case OpenPassStatus.expired:
        final expiredAt = DateTime.now().subtract(const Duration(minutes: 1));
        _status = PassStatusModel(
          isActive: false,
          policyName: policyName,
          activatedAt: expiredAt.subtract(const Duration(hours: 1)),
          expiresAt: expiredAt,
          remainingSec: 0,
        );
        break;
      case OpenPassStatus.inactive:
        _status = PassStatusModel.inactive();
        break;
    }
    notifyListeners();
  }

  /// 테스트 모드 종료 — 이후 [load] 호출 시 다시 실 서버 상태를 반영한다.
  void clearDebugOverride() {
    _debugOverride = false;
    notifyListeners();
  }

  /// 광고 시청 완료 콜백 — 성공 시 상태를 즉시 갱신한다.
  Future<bool> claimAd({int? policyId}) async {
    final result = await _repository.claimAd(policyId: policyId);
    if (!result.success) {
      _lastError = result.errorMessage;
      notifyListeners();
      return false;
    }
    _status = result.data!;
    _lastError = null;
    notifyListeners();
    return true;
  }

  /// 파트너 랜딩 방문 완료 콜백 — 성공 시 상태를 즉시 갱신한다.
  Future<bool> claimPartner({int? policyId}) async {
    final result = await _repository.claimPartner(policyId: policyId);
    if (!result.success) {
      _lastError = result.errorMessage;
      notifyListeners();
      return false;
    }
    _status = result.data!;
    _lastError = null;
    notifyListeners();
    return true;
  }

  /// [열림패스 첨부/광고소스 연동] `/api/public/open-pass/reward-complete`
  /// 응답(실제 어드민 광고소스 바인딩을 거쳐 지급된 결과)을 즉시 상태에 반영한다.
  /// claimAd()(레거시 `/api/public/pass/claim-ad`)와 달리, 이 경로는
  /// 어드민이 등록한 광고소스별 쿨다운/일일한도/idempotency 검증을 통과한
  /// 결과이므로 서버가 내려준 값을 그대로 신뢰하고 재검증하지 않는다.
  void applyOpenPassRewardGrant(OpenPassRewardGrantModel grant) {
    _status = PassStatusModel(
      isActive: true,
      userPassId: grant.userPassId,
      policyId: grant.policyId,
      policyName: grant.policyName,
      passType: PassType.ad,
      expiresAt: grant.expiresAt,
      remainingSec: grant.remainingSec,
    );
    _lastError = null;
    notifyListeners();
  }

  // [자율 정리 - 죽은 기능 제거] 과거 "복주머니로 프리패스 구매"
  // (loadPurchaseOptions/purchaseWithLuckPouch)는 백엔드/Repository까지
  // 구현되었으나 Flutter UI 어디에서도 호출되지 않았다("프리패스는 시간제
  // 이용권, 복주머니는 재화"라는 정책상 재화로 프리패스를 사는 경로 자체를
  // 열지 않기로 확정). 실사용자 데이터에 영향이 없는 순수 죽은 코드였으므로
  // 자율적으로 제거한다(Repository의 대응 메서드도 함께 정리).

  /// [로그아웃 시 프리패스 초기화 — 서버측 강제 만료 반영]
  /// 로그아웃하면 이유를 막론하고(사용자 명시적 로그아웃/토큰 만료 등) 현재 활성
  /// 프리패스를 서버 DB에서 즉시, 영구적으로 만료시켜야 한다. 과거에는 클라이언트
  /// 메모리 상태만 초기화하고 서버 발급 이력은 그대로 두어, 재로그인 시 서버가
  /// 여전히 유효하다고 판단해 잔여시간이 복원되는 버그가 있었다(사용자 리포트로
  /// 확인). 이제는 [_repository.expireOnLogout]을 먼저 호출해 서버 DB의
  /// UserPass.status를 revoked로 전환(expiresAt=now)한 뒤 화면 상태를 지운다.
  ///
  /// 이 메서드를 호출하는 쪽(예: 마이페이지 로그아웃 버튼)은 반드시 인증 토큰이
  /// 아직 살아있는 시점(= AuthProvider.logout()/AuthTokenStore.clear() 호출 이전)에
  /// 이 메서드를 먼저 실행해야 한다. 그렇지 않으면 userId를 얻을 수 없어 서버측
  /// 만료 요청이 올바른 사용자에게 적용되지 않는다.
  ///
  /// 서버 호출이 실패(네트워크 오류 등)하더라도 로그아웃 자체를 막지는 않는다
  /// (화면 상태는 항상 초기화한다) — 다만 실패 로그를 남겨 추후 원인 추적이
  /// 가능하도록 한다.
  Future<void> resetOnLogout() async {
    final result = await _repository.expireOnLogout();
    if (!result.success) {
      debugPrint(
        '[PassProvider] [resetOnLogout] 서버측 프리패스 만료 실패(화면 초기화는 계속 진행) -> ${result.errorMessage}',
      );
    }
    _status = PassStatusModel.inactive();
    _policies = [];
    _lastError = null;
    _debugOverride = false;
    notifyListeners();
  }

  /// 시간제 콘텐츠 열람 직전 게이트체크. 유효한 열림패스가 없으면 false를 반환하고
  /// [lastError]에 안내 메시지를 남긴다(화면단에서 발급 유도 UI 노출용).
  ///
  /// [STEP8 - Flutter categoryKey 연동] [categoryKey]를 넘기면 서버가
  /// "카테고리별 최대 2회" 제한도 함께 확인한다(초과 시 [lastErrorReason]이
  /// 'CATEGORY_LIMIT_REACHED'). categoryKey가 null이면(기존 호출부) 기존과
  /// 동일하게 활성 패스 여부만 확인한다.
  Future<bool> consume({
    required String contentType,
    dynamic contentId,
    String? categoryKey,
  }) async {
    final result = await _repository.consume(
      contentType: contentType,
      contentId: contentId,
      categoryKey: categoryKey,
    );
    if (!result.success) {
      _lastError = result.errorMessage;
      _lastErrorReason = result.errorCode;
      notifyListeners();
      return false;
    }
    _lastError = null;
    _lastErrorReason = null;
    return true;
  }
}
