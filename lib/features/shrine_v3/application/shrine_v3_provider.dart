import 'package:flutter/foundation.dart';
import '../data/shrine_v3_repository.dart';
import '../domain/shrine_order.dart';
import '../domain/talisman_item.dart';

/// 신당(THE SHRINE) v3 전역 상태 — 부적 카탈로그/부적함 조회 상태만 담당한다.
/// (app.dart/app_shell.dart가 요구하는 `hasOwnedTalismans`/`clearOnLogout`
/// 인터페이스를 충족한다.) 결제/차감은 이 Provider가 아니라 기존
/// ResultAccessProvider + ShrineV3Repository.createOrder()가 담당한다.
class ShrineV3Provider extends ChangeNotifier {
  ShrineV3Provider(this._repository);

  final ShrineV3Repository _repository;

  bool _isLoading = false;
  String? _error;
  String? _errorCode;

  List<TalismanItem> _catalog = const [];
  List<ShrineOrder> _boxItems = const [];
  ShrineBoxSummary? _boxSummary;

  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get errorCode => _errorCode;
  List<TalismanItem> get catalog => _catalog;
  List<ShrineOrder> get boxItems => _boxItems;
  ShrineBoxSummary? get boxSummary => _boxSummary;

  /// 하단바 "신당부적" 탭 배지(§3.2) — 보관 중(만료 포함)인 부적이 1건이라도
  /// 있으면 true. 부적함을 아직 조회하지 않은 세션에서는 false로 시작한다.
  bool get hasOwnedTalismans => _boxItems.isNotEmpty;

  Future<void> loadCatalog({String? category}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    final result = await _repository.getTalismans(category: category);
    _isLoading = false;
    if (result.success) {
      _catalog = result.data ?? const [];
    } else {
      _error = result.errorMessage;
      _errorCode = result.errorCode;
    }
    notifyListeners();
  }

  Future<bool> loadBox() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    final result = await _repository.getBox();
    _isLoading = false;
    if (result.success) {
      _boxItems = result.data!.items;
      _boxSummary = result.data!.summary;
      notifyListeners();
      return true;
    }
    _error = result.errorMessage;
    _errorCode = result.errorCode;
    notifyListeners();
    return false;
  }

  /// 05→07 "부탁하기" — 결제 게이트(ResultAccessGateSheet)가 이미 차감을
  /// 확정한 뒤에만 호출해야 한다. 성공 시 부적함 캐시에도 반영해 09 배지가
  /// 즉시 갱신되도록 한다.
  Future<ShrineOrder?> createOrder({
    required String talismanSlug,
    required String wish,
    required String paymentMethod,
    required String transactionId,
  }) async {
    final result = await _repository.createOrder(
      talismanSlug: talismanSlug,
      wish: wish,
      paymentMethod: paymentMethod,
      transactionId: transactionId,
    );
    if (!result.success || result.data == null) {
      _error = result.errorMessage;
      _errorCode = result.errorCode;
      notifyListeners();
      return null;
    }
    final order = result.data!;
    _boxItems = [order, ..._boxItems];
    notifyListeners();
    return order;
  }

  /// 10 화면용 상세 조회 — 부적함 캐시를 건드리지 않는 단발성 조회.
  Future<ShrineOrderDetail?> getBoxDetailPublic(int orderId) async {
    final result = await _repository.getBoxDetail(orderId);
    if (!result.success || result.data == null) {
      _error = result.errorMessage;
      _errorCode = result.errorCode;
      notifyListeners();
      return null;
    }
    return result.data;
  }

  Future<ShrineIncenseResult?> lightIncense(int orderId) async {
    final result = await _repository.lightIncense(orderId);
    if (!result.success || result.data == null) {
      _error = result.errorMessage;
      _errorCode = result.errorCode;
      notifyListeners();
      return null;
    }
    // 부적함 캐시도 함께 갱신(목록으로 돌아갔을 때 즉시 반영되도록).
    await loadBox();
    return result.data;
  }

  /// [계정 격리] 로그아웃 시 서버 상태를 다시 물어야 하므로 클라이언트
  /// 캐시만 비운다(서버 재호출은 다음 진입 화면의 initState가 담당).
  void clearOnLogout() {
    _catalog = const [];
    _boxItems = const [];
    _boxSummary = null;
    _error = null;
    _errorCode = null;
    notifyListeners();
  }
}
