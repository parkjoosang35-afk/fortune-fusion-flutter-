import 'package:flutter/foundation.dart';
import '../data/giftcard_repository.dart';
import '../domain/giftcard_model.dart';

/// 06§4.10 `/v1/giftcards/*` 대응 Provider
/// LuckyBagProvider와 동일 패턴: Wallet spend는 호출측(화면)에서
/// WalletProvider와 함께 orchestrate한다(WalletService.spend 단일 인터페이스 원칙 - 02번§1.2).
/// Repository의 orderProduct()는 순수 Mock 발급 처리만 담당한다.
class GiftcardProvider extends ChangeNotifier {
  final GiftcardRepository _repository;
  GiftcardProvider(this._repository);

  List<GiftcardProductModel> _products = [];
  List<GiftcardIssueModel> _myOrders = [];
  bool _isProductsLoading = false;
  bool _isOrdering = false;
  bool _isMyOrdersLoading = false;
  String? _actionError;

  List<GiftcardProductModel> get products => _products;
  List<GiftcardIssueModel> get myOrders => _myOrders;
  bool get isProductsLoading => _isProductsLoading;
  bool get isOrdering => _isOrdering;
  bool get isMyOrdersLoading => _isMyOrdersLoading;
  String? get actionError => _actionError;

  /// GET /v1/giftcards/products
  Future<void> loadProducts() async {
    _isProductsLoading = true;
    notifyListeners();
    final result = await _repository.getProducts();
    if (result.success) _products = result.data ?? [];
    _isProductsLoading = false;
    notifyListeners();
  }

  /// POST /v1/giftcards/orders - 행복머니 차감(WalletProvider.spend)은
  /// 이 메서드 호출 전에 화면 레이어에서 먼저 성공을 확인한 뒤 호출해야 한다.
  /// 발급 실패(Mock 10%) 시에도 행복머니는 이미 차감되었으므로, 화면 레이어에서
  /// 실패 결과를 받으면 WalletProvider.earn()으로 환불 처리해야 한다(02§14 예외처리).
  Future<GiftcardIssueModel?> orderProduct(String productId) async {
    _actionError = null;
    _isOrdering = true;
    notifyListeners();
    final result = await _repository.orderProduct(productId);
    _isOrdering = false;
    if (result.success && result.data != null) {
      notifyListeners();
      return result.data;
    }
    _actionError = result.errorMessage;
    notifyListeners();
    return null;
  }

  /// GET /v1/giftcards/orders/my
  Future<void> loadMyOrders() async {
    _isMyOrdersLoading = true;
    notifyListeners();
    final result = await _repository.getMyOrders();
    if (result.success) _myOrders = result.data ?? [];
    _isMyOrdersLoading = false;
    notifyListeners();
  }

  /// POST /v1/giftcards/orders/:id/use - 사용처리(J-3 giftcard_usages 대응)
  Future<bool> useIssue(String issueId) async {
    _actionError = null;
    final result = await _repository.useIssue(issueId);
    if (result.success) {
      await loadMyOrders();
      return true;
    }
    _actionError = result.errorMessage;
    notifyListeners();
    return false;
  }
}
