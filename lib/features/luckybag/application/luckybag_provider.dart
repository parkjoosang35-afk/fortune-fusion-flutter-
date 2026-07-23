import 'package:flutter/foundation.dart';
import '../data/luckybag_repository.dart';
import '../domain/luckybag_model.dart';
import '../domain/luckybag_open_log_model.dart';
import '../domain/luckybag_product_model.dart';
import '../domain/luckybag_reward_model.dart';

/// 06단계 §4.9 `/v1/luckybags/*` 대응 Provider
/// 기존 summary(홈배너 요약)는 유지하고, Phase10에서 상점/확률공개/개봉/이력/보상요약 기능을 확장한다.
class LuckyBagProvider extends ChangeNotifier {
  final LuckyBagRepository _repository;
  LuckyBagProvider(this._repository);

  // ── 기존(홈 배너 요약) - 변경 없음 ──
  LuckyBagSummary? _summary;
  bool _isLoading = false;

  LuckyBagSummary? get summary => _summary;
  bool get isLoading => _isLoading;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    final result = await _repository.getPendingSummary();
    if (result.success) _summary = result.data;
    _isLoading = false;
    notifyListeners();
  }

  // ── Phase10: 상점/확률공개/개봉/이력/보상요약 ──
  List<LuckyBagProductModel> _products = [];
  List<LuckyBagRewardPoolModel> _probabilities = [];
  List<LuckyBagOpenLogModel> _history = [];
  List<LuckyBagRewardSummaryEntry> _rewardSummary = [];
  bool _isProductsLoading = false;
  bool _isProbabilitiesLoading = false;
  bool _isHistoryLoading = false;
  bool _isOpening = false;
  String? _actionError;

  List<LuckyBagProductModel> get products => _products;
  List<LuckyBagRewardPoolModel> get probabilities => _probabilities;
  List<LuckyBagOpenLogModel> get history => _history;
  List<LuckyBagRewardSummaryEntry> get rewardSummary => _rewardSummary;
  bool get isProductsLoading => _isProductsLoading;
  bool get isProbabilitiesLoading => _isProbabilitiesLoading;
  bool get isHistoryLoading => _isHistoryLoading;
  bool get isOpening => _isOpening;
  String? get actionError => _actionError;

  Future<void> loadProducts() async {
    _isProductsLoading = true;
    notifyListeners();
    final result = await _repository.getProducts();
    if (result.success) _products = result.data ?? [];
    _isProductsLoading = false;
    notifyListeners();
  }

  /// GET /:id/probabilities - 확률 공개(투명성, 법적 요건)
  Future<void> loadProbabilities(String productId) async {
    _isProbabilitiesLoading = true;
    _probabilities = [];
    notifyListeners();
    final result = await _repository.getProbabilities(productId);
    if (result.success) _probabilities = result.data ?? [];
    _isProbabilitiesLoading = false;
    notifyListeners();
  }

  /// POST /:id/open - 개봉(구매+추첨). Wallet spend/earn은 호출측(화면)에서
  /// WalletProvider와 함께 orchestrate한다(WalletService.earn/spend 단일 인터페이스 원칙 - 02번 §1.2).
  Future<LuckyBagOpenResult?> open(
    String productId,
    int remainingBalance,
  ) async {
    _actionError = null;
    _isOpening = true;
    notifyListeners();
    final result = await _repository.open(productId, remainingBalance);
    _isOpening = false;
    if (result.success && result.data != null) {
      notifyListeners();
      return result.data;
    }
    _actionError = result.errorMessage;
    notifyListeners();
    return null;
  }

  Future<void> loadHistory() async {
    _isHistoryLoading = true;
    notifyListeners();
    final result = await _repository.getHistory();
    if (result.success) _history = result.data ?? [];
    _isHistoryLoading = false;
    notifyListeners();
  }

  Future<void> loadRewardSummary() async {
    final result = await _repository.getRewardSummary();
    if (result.success) _rewardSummary = result.data ?? [];
    notifyListeners();
  }
}
