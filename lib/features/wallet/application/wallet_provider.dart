import 'package:flutter/foundation.dart';
import '../data/wallet_repository.dart';
import '../domain/point_history_model.dart';

/// 07단계 §2.1 전역 Provider - WalletProvider(잔액 캐시, 최근 트랜잭션)
class WalletProvider extends ChangeNotifier {
  final WalletRepository _repository;
  WalletProvider(this._repository);

  int _balance = 0;
  List<PointHistoryModel> _history = [];
  bool _isLoading = false;

  int get balance => _balance;
  List<PointHistoryModel> get history => _history;
  bool get isLoading => _isLoading;

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
    _balance = await _repository.earn(amount, reason);
    await load();
  }

  Future<bool> spend(int amount, String reason) async {
    final ok = await _repository.spend(amount, reason);
    if (ok) await load();
    return ok;
  }
}
