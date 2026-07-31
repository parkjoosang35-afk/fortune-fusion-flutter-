import 'package:flutter/foundation.dart';
import '../data/pass_repository.dart';
import '../domain/pass_model.dart';

/// 열림패스(AlarmPass) 전역 Provider — 홈 화면 상태바 + 열림패스 섹션에서 공유.
/// [문서5 홈화면섹션구조표 승인 반영] 홈 상단 상태바에 remainingSec 카운트다운 노출,
/// 열림패스 섹션에서 정책 목록(CTA 카드) + 발급/게이트체크 액션을 제공한다.
class PassProvider extends ChangeNotifier {
  final PassRepository _repository;
  PassProvider(this._repository);

  List<PassPolicyModel> _policies = [];
  PassStatusModel _status = PassStatusModel.inactive();
  bool _isLoading = false;
  String? _lastError;

  List<PassPolicyModel> get policies => _policies;
  PassStatusModel get status => _status;
  bool get isActive => _status.isActive;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;

  /// 홈 화면 진입 시 정책 목록 + 현재 활성 상태를 동시에 로드한다.
  Future<void> load() async {
    _isLoading = true;
    notifyListeners();

    final policiesResult = await _repository.getPolicies();
    final statusResult = await _repository.getStatus();

    if (policiesResult.success) _policies = policiesResult.data!;
    if (statusResult.success) _status = statusResult.data!;

    _isLoading = false;
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
