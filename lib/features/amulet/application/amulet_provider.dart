import 'package:flutter/foundation.dart';
import '../data/amulet_repository.dart';
import '../domain/amulet_item_model.dart';
import '../domain/amulet_model.dart';
import '../domain/user_amulet_model.dart';

/// 06단계 §4.8 `/v1/amulets/*` 대응 Provider — admin_web 공개 API 실 연동.
///
/// [실API 전환 - 갭 처리] admin_web UserAmulet 스키마에는 isEquipped 컬럼이 없어
/// "장착" 기능에 대응하는 서버 API가 없다([문서2 mock/실연동 현황표] 승인 반영).
/// [equip]은 서버 호출 없이 클라이언트 로컬 상태([_equippedUserAmuletId])로만 유지하며,
/// 앱 재시작 시 초기화된다(향후 서버 컬럼 추가가 필요하면 별도 논의).
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

  // ── 상점/보유목록 ──
  List<AmuletItemModel> _shopItems = [];
  List<UserAmuletModel> _rawMyAmulets = [];
  String? _equippedUserAmuletId; // [갭] 서버 미지원 - 클라이언트 로컬 상태
  bool _isShopLoading = false;
  bool _isMyAmuletsLoading = false;
  String? _actionError;

  /// 최근 구매/생성 성공 시 서버가 반환한 지갑 잔액(중복 차감 방지용 동기화에 사용).
  int? lastBalanceAfter;

  List<AmuletItemModel> get shopItems => _shopItems;

  /// 로컬 [_equippedUserAmuletId] 상태를 반영해 노출한다(서버 응답 자체는 isEquipped 없음).
  List<UserAmuletModel> get myAmulets => _rawMyAmulets
      .map((a) => a.copyWith(isEquipped: a.id == _equippedUserAmuletId))
      .toList();

  bool get isShopLoading => _isShopLoading;
  bool get isMyAmuletsLoading => _isMyAmuletsLoading;
  String? get actionError => _actionError;

  UserAmuletModel? get equippedAmulet =>
      myAmulets.where((a) => a.isEquipped).firstOrNull;

  /// 04A `amulet_collections`(H-6) 대응 - 도감 진행률.
  /// 별도 API 호출 없이 이미 로드된 [_rawMyAmulets]를 item.id 기준으로 그룹화하여 파생한다.
  List<AmuletCollectionEntry> get collection {
    final byItemId = <String, List<UserAmuletModel>>{};
    for (final a in _rawMyAmulets) {
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
    if (result.success) _rawMyAmulets = result.data ?? [];
    // 장착중인 항목이 더 이상 목록에 없으면(사용/선물됨) 로컬 장착 상태 해제.
    if (_equippedUserAmuletId != null &&
        !_rawMyAmulets.any(
          (a) =>
              a.id == _equippedUserAmuletId &&
              a.status == UserAmuletStatus.held,
        )) {
      _equippedUserAmuletId = null;
    }
    _isMyAmuletsLoading = false;
    notifyListeners();
  }

  /// 구매 — 서버(`POST /amulets/purchase`)가 지갑 차감+부적 발급을 트랜잭션으로 처리한다.
  /// 성공 시 [lastBalanceAfter]에 차감 후 잔액을 담아두며, 호출측(화면)은 이 값을
  /// 사용해 WalletProvider.load()로 잔액만 새로고침해야 한다(중복 차감 방지 —
  /// WalletProvider.spend()를 다시 호출하지 않는다).
  Future<bool> purchase(String itemId) async {
    _actionError = null;
    final result = await _repository.purchase(itemId);
    if (result.success && result.data != null) {
      lastBalanceAfter = result.data!['balanceAfter'] as int?;
      await loadMyAmulets();
      return true;
    }
    _actionError = result.errorMessage;
    notifyListeners();
    return false;
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

  /// [갭 처리] 서버 API 없음 — 클라이언트 로컬 상태로만 "장착"을 표시한다.
  Future<bool> equip(String userAmuletId) async {
    _actionError = null;
    final target = _rawMyAmulets.where((a) => a.id == userAmuletId).firstOrNull;
    if (target == null || target.status != UserAmuletStatus.held) {
      _actionError = '장착할 수 없는 부적입니다.';
      notifyListeners();
      return false;
    }
    _equippedUserAmuletId = userAmuletId;
    notifyListeners();
    return true;
  }

  /// AI 생성 — [갭 처리] 서버(`POST /amulets/generate`)는 아직 무료 지급이므로
  /// (LLM/이미지생성 인프라 미구현), 호출측(화면)이 여전히 WalletProvider.spend()로
  /// 선차감 후 이 메서드를 호출해야 한다(amulet_generate_screen.dart 참조).
  Future<bool> generate(String baseItemId) async {
    _actionError = null;
    final result = await _repository.generate(baseItemId);
    if (result.success && result.data != null) {
      await loadMyAmulets();
      return true;
    }
    _actionError = result.errorMessage;
    notifyListeners();
    return false;
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
