import 'package:flutter/foundation.dart';

import '../data/shop_repository.dart';
import '../domain/shop_models.dart';
import '../../luckpouch/application/luck_pouch_provider.dart';

/// 상점(Shop) 전역 Provider — bokjumeoni-plan §03 Provider 아키텍처
/// `ShopProvider`(카탈로그 fetch + 구매 액션 · 낙관적 업데이트 → 서버 확인
/// → rollback)에 대응.
///
/// [재화 절대 원칙] 이 Provider는 복주머니 잔액을 직접 보유하지 않는다.
/// 구매 후 잔액 갱신은 반드시 [LuckPouchProvider] → [WalletProvider] 경로를
/// 통해서만 반영된다(새 화폐/잔액 캐시 생성 금지). 구매 성공 시
/// [LuckPouchProvider.load]를 호출해 서버 원장을 다시 조회한다.
class ShopProvider extends ChangeNotifier {
  final ShopRepository _repo;
  final LuckPouchProvider _pouch;

  ShopProvider(this._repo, this._pouch);

  List<ShopCatalogItem> _seals = const [];
  List<ShopCatalogItem> _candles = const [];
  List<ShopCatalogItem> _talismans = const [];
  List<InventoryItem> _inventory = const [];

  bool _isLoading = false;
  String? _error;

  /// 구매 진행 중인 itemCode 집합 — 중복 탭 방지 및 개별 타일 로딩 표시용.
  final Set<String> _purchasingCodes = {};

  List<ShopCatalogItem> get seals => _seals;
  List<ShopCatalogItem> get candles => _candles;
  List<ShopCatalogItem> get talismans => _talismans;
  List<InventoryItem> get inventory => _inventory;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool isPurchasing(String itemCode) => _purchasingCodes.contains(itemCode);

  /// 3개 카탈로그(인장/촛불/부적) + 인벤토리를 함께 로드하고, 인벤토리
  /// 보유 여부를 각 카탈로그 항목의 [ShopCatalogItem.owned]에 반영한다.
  Future<void> loadAll() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _repo.fetchSeals(),
        _repo.fetchCandles(),
        _repo.fetchTalismans(),
        _fetchInventorySafely(),
      ]);
      // [상점 기획 결함 수정] 인장/촛불도 기간제로 바뀌었으므로, 만료된
      // 항목(isExpired=true)은 "보유 중"으로 치지 않는다 — 그래야 기간이
      // 끝난 뒤 같은 품목을 다시 구매(재사용)할 수 있다. 인벤토리 자체는
      // 이력으로 남지만(append-only), owned 판정에는 유효한 것만 반영.
      final ownedCodes = (results[3] as List<InventoryItem>)
          .where((e) => !e.isExpired)
          .map((e) => e.itemCode)
          .toSet();
      _seals = (results[0] as List<ShopCatalogItem>)
          .map((e) => e.copyWith(owned: ownedCodes.contains(e.itemCode)))
          .toList();
      _candles = (results[1] as List<ShopCatalogItem>)
          .map((e) => e.copyWith(owned: ownedCodes.contains(e.itemCode)))
          .toList();
      _talismans = (results[2] as List<ShopCatalogItem>)
          .map((e) => e.copyWith(owned: ownedCodes.contains(e.itemCode)))
          .toList();
      _inventory = results[3] as List<InventoryItem>;
    } catch (e) {
      _error = '상점 목록을 불러오지 못했습니다.';
      debugPrint('[ShopProvider] loadAll 실패 -> $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 비로그인 상태에서는 인벤토리 조회가 401을 던진다. 카탈로그 열람
  /// 자체는(비로그인도 허용) 계속 되어야 하므로 조용히 빈 목록으로 대체.
  Future<List<InventoryItem>> _fetchInventorySafely() async {
    try {
      return await _repo.fetchInventory();
    } catch (_) {
      return const [];
    }
  }

  /// 보물함 화면 전용 — 인벤토리만 다시 로드.
  Future<void> loadInventory() async {
    try {
      _inventory = await _repo.fetchInventory();
      notifyListeners();
    } catch (e) {
      debugPrint('[ShopProvider] loadInventory 실패 -> $e');
    }
  }

  /// 구매 액션 — 낙관적 업데이트(즉시 owned=true 반영) → 서버 확인 →
  /// 실패 시 rollback(원래 owned 상태로 되돌림).
  ///
  /// 성공 시 true, 실패 시 false를 반환하고 [lastPurchaseError]에 사용자
  /// 표시용 메시지를 남긴다.
  String? lastPurchaseError;

  Future<bool> purchase(ShopCatalogItem item) async {
    if (_purchasingCodes.contains(item.itemCode)) return false;
    lastPurchaseError = null;

    _purchasingCodes.add(item.itemCode);
    // 낙관적 업데이트: 해당 카탈로그 목록에서 owned=true로 즉시 반영.
    _applyOwned(item.itemCode, true);
    notifyListeners();

    try {
      final result = await _repo.purchase(
        itemType: item.itemType,
        itemCode: item.itemCode,
      );
      // 서버 확인 성공: 인벤토리에 새 항목 반영 + 복주머니 잔액 재조회.
      _inventory = [result.item, ..._inventory];
      _purchasingCodes.remove(item.itemCode);
      notifyListeners();
      // [재화 절대 원칙] 잔액은 LuckPouchProvider(→WalletProvider) 경로로만
      // 갱신한다 — 서버가 확정한 값을 다시 조회해 신뢰한다.
      await _pouch.load();
      return true;
    } on ShopException catch (e) {
      // rollback: 낙관적으로 켰던 owned를 원래대로 되돌린다.
      _applyOwned(item.itemCode, false);
      lastPurchaseError = e.message;
      _purchasingCodes.remove(item.itemCode);
      notifyListeners();
      return false;
    } catch (e) {
      _applyOwned(item.itemCode, false);
      lastPurchaseError = '구매 처리 중 오류가 발생했습니다.';
      _purchasingCodes.remove(item.itemCode);
      notifyListeners();
      debugPrint('[ShopProvider] purchase 실패 -> $e');
      return false;
    }
  }

  void _applyOwned(String itemCode, bool owned) {
    _seals = _seals
        .map((e) => e.itemCode == itemCode ? e.copyWith(owned: owned) : e)
        .toList();
    _candles = _candles
        .map((e) => e.itemCode == itemCode ? e.copyWith(owned: owned) : e)
        .toList();
    _talismans = _talismans
        .map((e) => e.itemCode == itemCode ? e.copyWith(owned: owned) : e)
        .toList();
  }
}
