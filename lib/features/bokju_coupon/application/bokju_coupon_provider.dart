import 'package:flutter/foundation.dart';
import '../data/bokju_coupon_repository.dart';
import '../domain/bokju_coupon_model.dart';
import '../../wallet/application/wallet_provider.dart';

/// [복주머니 마케팅 쿠폰] 등록(QR 스캔/딥링크→미리보기→등록) 플로우 전용
/// Provider. `wallet/application/wallet_provider.dart`와 마찬가지로
/// ChangeNotifier 기반 단순 상태 보관 패턴을 따른다.
///
/// [WalletProvider 연동] 등록(redeem) 성공 시 서버가 이미 복주머니를
/// 적립했으므로(바로 그 `earnLuckPouch()` 결과가 [BokjuCouponRedeemResult]에
/// 담겨온다), 이 Provider는 지갑 잔액을 직접 가감하지 않고 대신
/// [WalletProvider.load]를 호출해 홈/지갑 화면의 잔액 표시가 재조회를 통해
/// 서버와 정확히 일치하도록 한다(WalletRepository.earn()과 동일한
/// "서버-확정 재조회" 패턴 — 클라이언트가 임의로 잔액을 더하지 않음).
enum BokjuCouponFlowStatus {
  idle,
  resolving,
  previewReady,
  redeeming,
  success,
  error,
}

class BokjuCouponProvider extends ChangeNotifier {
  final BokjuCouponRepository _repository;
  final WalletProvider? _walletProvider;

  BokjuCouponProvider(this._repository, [this._walletProvider]);

  BokjuCouponFlowStatus _status = BokjuCouponFlowStatus.idle;
  BokjuCouponFlowStatus get status => _status;

  String? _token;
  String? get token => _token;

  BokjuCouponPreview? _preview;
  BokjuCouponPreview? get preview => _preview;

  BokjuCouponRedeemResult? _result;
  BokjuCouponRedeemResult? get result => _result;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _errorCode;
  String? get errorCode => _errorCode;

  /// 등록(redeem) 중 네트워크 오류로 재시도할 때도 같은 요청으로 서버가
  /// 인식하도록, token당 1개의 멱등키를 발급 시점에 고정해 재사용한다.
  String? _idempotencyKey;

  List<BokjuCouponHistoryItem> _history = [];
  List<BokjuCouponHistoryItem> get history => _history;
  bool _historyLoading = false;
  bool get historyLoading => _historyLoading;

  /// 화면 재진입/초기화 시 이전 흐름 상태를 비운다.
  void reset() {
    _status = BokjuCouponFlowStatus.idle;
    _token = null;
    _preview = null;
    _result = null;
    _errorMessage = null;
    _errorCode = null;
    _idempotencyKey = null;
    notifyListeners();
  }

  /// QR 스캔/딥링크/수동 코드입력으로 얻은 [token]을 미리보기 조회한다.
  Future<void> loadPreview(String token) async {
    _token = token;
    _status = BokjuCouponFlowStatus.resolving;
    _errorMessage = null;
    _errorCode = null;
    notifyListeners();

    final result = await _repository.resolve(token);
    if (!result.success) {
      _status = BokjuCouponFlowStatus.error;
      _errorMessage = result.errorMessage ?? '쿠폰을 조회하지 못했습니다.';
      _errorCode = result.errorCode;
      notifyListeners();
      return;
    }

    _preview = result.data;
    _status = BokjuCouponFlowStatus.previewReady;
    notifyListeners();
  }

  /// 미리보기 화면의 "등록하기" 버튼에서 호출한다. [preview.redeemable]이
  /// false면 호출부가 먼저 막아야 하지만, 방어적으로 여기서도 재확인한다.
  Future<bool> redeem() async {
    final token = _token;
    if (token == null) return false;

    _idempotencyKey ??= BokjuCouponRepository.generateIdempotencyKey();
    _status = BokjuCouponFlowStatus.redeeming;
    _errorMessage = null;
    _errorCode = null;
    notifyListeners();

    final result = await _repository.redeem(
      token,
      idempotencyKey: _idempotencyKey!,
    );

    if (!result.success) {
      _status = BokjuCouponFlowStatus.error;
      _errorMessage = result.errorMessage ?? '쿠폰 등록에 실패했습니다.';
      _errorCode = result.errorCode;
      notifyListeners();
      return false;
    }

    _result = result.data;
    _status = BokjuCouponFlowStatus.success;
    notifyListeners();

    // 지갑 화면/홈 상단 잔액 표시가 최신 상태를 반영하도록 재조회.
    await _walletProvider?.load();
    return true;
  }

  Future<void> loadHistory() async {
    _historyLoading = true;
    notifyListeners();
    final result = await _repository.getMyHistory();
    if (result.success) {
      _history = result.data ?? [];
    }
    _historyLoading = false;
    notifyListeners();
  }
}
