import 'package:flutter/foundation.dart';
import '../data/wallet_repository.dart';
import '../domain/point_history_model.dart';

/// 07단계 §2.1 전역 Provider - WalletProvider(잔액 캐시, 최근 트랜잭션)
/// Phase2-1b: 04A §A-5 등급 배율(point_earn_multiplier)을 earn() 단일 지점에 적용.
/// app.dart에서 ChangeNotifierProxyProvider로 AuthProvider.pointEarnMultiplier를
/// 주입받아 [updateMultiplier]를 호출한다 - 각 화면의 earn() 호출부는 무변경.
class WalletProvider extends ChangeNotifier {
  final WalletRepository _repository;
  WalletProvider(this._repository);

  int _balance = 0;
  List<PointHistoryModel> _history = [];
  bool _isLoading = false;
  double _multiplier = 1.0;

  int get balance => _balance;
  List<PointHistoryModel> get history => _history;
  bool get isLoading => _isLoading;

  /// AuthProvider의 등급 배율을 반영한다(값이 바뀔 때만 갱신하여 불필요한 rebuild 방지).
  void updateMultiplier(double multiplier) {
    if (_multiplier == multiplier) return;
    _multiplier = multiplier;
  }

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    final balanceResult = await _repository.getBalance();
    final historyResult = await _repository.getHistory();
    if (balanceResult.success) _balance = balanceResult.data!;
    if (historyResult.success) _history = historyResult.data!;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> earn(int amount, String reason) async {
    final finalAmount = (amount * _multiplier).round();
    final appliedReason = _multiplier > 1.0
        ? '$reason (등급 $_multiplier배 적용)'
        : reason;
    _balance = await _repository.earn(finalAmount, appliedReason);
    await load();
  }

  Future<bool> spend(int amount, String reason) async {
    final ok = await _repository.spend(amount, reason);
    if (ok) await load();
    return ok;
  }

  /// [Phase22 - 복주머니 경제철학 이식] "복 나누기" — 성공 시 (환급액, 오늘 남은 송금가능액)을
  /// 반환하고, 실패 시 null을 반환한다(에러 메시지는 [lastSendError]로 확인).
  String? lastSendError;

  /// [Phase22-3] 닉네임 -> userId 조회(황금률 출구버튼에서 sendBok() 호출 전 사용).
  /// 실패 시 null을 반환하고 [lastSendError]에 에러 메시지를 남긴다.
  Future<({int userId, String nickname})?> lookupUserByNickname(
    String nickname,
  ) async {
    final result = await _repository.lookupUserByNickname(nickname);
    if (!result.success) {
      lastSendError = result.errorMessage;
      return null;
    }
    lastSendError = null;
    return result.data;
  }

  Future<({int refundAmount, int dailySendRemaining})?> sendBok({
    required int toUserId,
    required int amount,
    String memo = '복 나누기',
  }) async {
    final result = await _repository.sendBok(
      toUserId: toUserId,
      amount: amount,
      memo: memo,
    );
    if (!result.success) {
      lastSendError = result.errorMessage;
      return null;
    }
    lastSendError = null;
    await load();
    return result.data;
  }
}
