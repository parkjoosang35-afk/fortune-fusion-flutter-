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

  // [재화 구조 정리] "복주머니로 구매" 가능한 프리패스 옵션 목록(마이페이지 전용).
  List<PassPurchaseOptionModel> _purchaseOptions = [];
  bool _isPurchaseLoading = false;

  /// true이면 [load]가 실 API 응답으로 [_status]를 덮어쓰지 않는다
  /// (테스트 모드에서 강제 지정한 상태를 유지하기 위함).
  bool _debugOverride = false;

  List<PassPolicyModel> get policies => _policies;
  PassStatusModel get status => _status;
  bool get isActive => _status.isActive;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
  List<PassPurchaseOptionModel> get purchaseOptions => _purchaseOptions;
  bool get isPurchaseLoading => _isPurchaseLoading;

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

  /// [재화 구조 정리] 마이페이지 프리패스 영역 "복주머니로 구매" 진입 시 옵션 목록 로드.
  Future<void> loadPurchaseOptions() async {
    _isPurchaseLoading = true;
    notifyListeners();

    final result = await _repository.getPurchaseOptions();
    if (result.success) _purchaseOptions = result.data!;

    _isPurchaseLoading = false;
    notifyListeners();
  }

  /// [재화 구조 정리] 복주머니 차감으로 프리패스 즉시 구매. 성공 시 상태를 즉시
  /// 갱신한다. 잔액 부족 등의 사유는 [lastError]에 담겨 화면단에서 안내한다.
  /// (지갑 잔액 갱신은 호출부에서 WalletProvider.load()를 함께 호출해야 한다.)
  Future<bool> purchaseWithLuckPouch({required int policyId}) async {
    final result = await _repository.purchaseWithLuckPouch(policyId: policyId);
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

  /// 시간제 콘텐츠 열람 직전 게이트체크. 유효한 열림패스가 없으면 false를 반환하고
  /// [lastError]에 안내 메시지를 남긴다(화면단에서 발급 유도 UI 노출용).
  Future<bool> consume({required String contentType, dynamic contentId}) async {
    final result = await _repository.consume(
      contentType: contentType,
      contentId: contentId,
    );
    if (!result.success) {
      _lastError = result.errorMessage;
      notifyListeners();
      return false;
    }
    _lastError = null;
    return true;
  }
}
