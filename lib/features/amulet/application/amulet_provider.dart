import 'package:flutter/foundation.dart';
import '../data/amulet_repository.dart';
import '../domain/amulet_item_model.dart';
import '../domain/amulet_model.dart';
import '../domain/user_amulet_model.dart';

/// 06단계 §4.8 `/v1/amulets/*` 대응 Provider
/// 기존 summary(홈배너 요약)는 유지하고, Phase9에서 상점/보유목록/사용/장착/생성/선물 기능을 확장한다.
class AmuletProvider extends ChangeNotifier {
  final AmuletRepository _repository;
  AmuletProvider(this._repository);

  // ── 기존(홈 배너 요약) - 변경 없음 ──
  AmuletSummary? _summary;
  bool _isLoading = false;

  AmuletSummary? get summary => _summary;
  bool get isLoading => _isLoading;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    final result = await _repository.getActiveSummary();
    if (result.success) _summary = result.data;
    _isLoading = false;
    notifyListeners();
  }

  // ── Phase9: 상점/보유목록 ──
  List<AmuletItemModel> _shopItems = [];
  List<UserAmuletModel> _myAmulets = [];
  bool _isShopLoading = false;
  bool _isMyAmuletsLoading = false;
  String? _actionError;

  List<AmuletItemModel> get shopItems => _shopItems;
  List<UserAmuletModel> get myAmulets => _myAmulets;
  bool get isShopLoading => _isShopLoading;
  bool get isMyAmuletsLoading => _isMyAmuletsLoading;
  String? get actionError => _actionError;

  UserAmuletModel? get equippedAmulet =>
      _myAmulets.where((a) => a.isEquipped).firstOrNull;

  /// 04A `amulet_collections`(H-6) 대응 - 도감 진행률.
  /// 별도 API 호출 없이 이미 로드된 [_myAmulets]를 item.id 기준으로 그룹화하여 파생한다.
  /// (Mock 단계: GET /my 응답 하나로 보유목록+도감을 동시에 구성 - 불필요한 API 증설 방지)
  List<AmuletCollectionEntry> get collection {
    final byItemId = <String, List<UserAmuletModel>>{};
    for (final a in _myAmulets) {
      byItemId.putIfAbsent(a.item.id, () => []).add(a);
    }
    final entries = byItemId.values.map((list) {
      list.sort((a, b) => a.acquiredAt.compareTo(b.acquiredAt));
      return AmuletCollectionEntry(
        item: list.first.item,
        firstAcquiredAt: list.first.acquiredAt,
        totalCount: list.length,
      );
    }).toList();
    entries.sort(
      (a, b) => a.item.grade.sortOrder.compareTo(b.item.grade.sortOrder),
    );
    return entries;
  }

  Future<void> loadShop() async {
    _isShopLoading = true;
    notifyListeners();
    final result = await _repository.getShopItems();
    if (result.success) _shopItems = result.data ?? [];
    _isShopLoading = false;
    notifyListeners();
  }

  Future<void> loadMyAmulets() async {
    _isMyAmuletsLoading = true;
    notifyListeners();
    final result = await _repository.getMyAmulets();
    if (result.success) _myAmulets = result.data ?? [];
    _isMyAmuletsLoading = false;
    notifyListeners();
  }

  /// 구매 - Wallet spend는 호출측(화면)에서 WalletProvider.spend와 함께 orchestrate.
  /// (WalletService.earn/spend 단일 인터페이스 원칙 - 02번 §1.2 준수, 여기서 직접 포인트 차감 안 함)
  Future<UserAmuletModel?> purchase(String itemId) async {
    _actionError = null;
    final result = await _repository.purchase(itemId);
    if (result.success && result.data != null) {
      await loadMyAmulets();
      return result.data;
    }
    _actionError = result.errorMessage;
    notifyListeners();
    return null;
  }

  Future<bool> use(String userAmuletId) async {
    _actionError = null;
    final result = await _repository.use(userAmuletId);
    if (result.success) {
      await loadMyAmulets();
      return true;
    }
    _actionError = result.errorMessage;
    notifyListeners();
    return false;
  }

  Future<bool> equip(String userAmuletId) async {
    _actionError = null;
    final result = await _repository.equip(userAmuletId);
    if (result.success) {
      await loadMyAmulets();
      return true;
    }
    _actionError = result.errorMessage;
    notifyListeners();
    return false;
  }

  Future<UserAmuletModel?> generate(String baseItemId) async {
    _actionError = null;
    final result = await _repository.generate(baseItemId);
    if (result.success && result.data != null) {
      await loadMyAmulets();
      return result.data;
    }
    _actionError = result.errorMessage;
    notifyListeners();
    return null;
  }

  Future<bool> gift(
    String userAmuletId,
    String toUserNickname,
    String? message,
  ) async {
    _actionError = null;
    final result = await _repository.gift(
      userAmuletId,
      toUserNickname,
      message,
    );
    if (result.success) {
      await loadMyAmulets();
      return true;
    }
    _actionError = result.errorMessage;
    notifyListeners();
    return false;
  }
}
