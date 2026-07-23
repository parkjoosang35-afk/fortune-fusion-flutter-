import 'package:flutter/foundation.dart';
import '../data/subscription_repository.dart';
import '../domain/subscription_model.dart';

/// 02§21/06§4.11 프리미엄 구독 상태관리
class SubscriptionProvider extends ChangeNotifier {
  final SubscriptionRepository _repository;
  SubscriptionProvider(this._repository);

  List<SubscriptionPlanModel> _plans = [];
  UserSubscriptionModel? _mySubscription;
  List<PaymentModel> _paymentHistory = [];
  bool _isLoadingPlans = false;
  bool _isLoadingSubscription = false;
  bool _isProcessing = false;

  List<SubscriptionPlanModel> get plans => _plans;
  UserSubscriptionModel? get mySubscription => _mySubscription;
  List<PaymentModel> get paymentHistory => _paymentHistory;
  bool get isLoadingPlans => _isLoadingPlans;
  bool get isLoadingSubscription => _isLoadingSubscription;
  bool get isProcessing => _isProcessing;

  /// 마이페이지/AI결과 화면 등에서 잠금해제 여부를 확인할 때 사용하는 편의 getter
  bool get isPremium => _mySubscription?.isActive ?? false;

  Future<void> loadPlans() async {
    _isLoadingPlans = true;
    notifyListeners();
    final result = await _repository.getPlans();
    if (result.success) _plans = result.data!;
    _isLoadingPlans = false;
    notifyListeners();
  }

  Future<void> loadMySubscription() async {
    _isLoadingSubscription = true;
    notifyListeners();
    final result = await _repository.getMySubscription();
    if (result.success) _mySubscription = result.data;
    _isLoadingSubscription = false;
    notifyListeners();
  }

  Future<({bool success, String? errorMessage})> subscribe(
    SubscriptionPlanModel plan,
  ) async {
    _isProcessing = true;
    notifyListeners();
    final result = await _repository.subscribe(plan);
    if (result.success) _mySubscription = result.data;
    _isProcessing = false;
    notifyListeners();
    return (success: result.success, errorMessage: result.errorMessage);
  }

  Future<bool> cancel() async {
    _isProcessing = true;
    notifyListeners();
    final result = await _repository.cancel();
    if (result.success) _mySubscription = result.data;
    _isProcessing = false;
    notifyListeners();
    return result.success;
  }

  Future<void> loadPaymentHistory() async {
    final result = await _repository.getPaymentHistory();
    if (result.success) _paymentHistory = result.data!;
    notifyListeners();
  }
}
