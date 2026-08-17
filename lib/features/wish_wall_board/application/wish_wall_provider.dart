import 'package:flutter/foundation.dart';

import '../data/wish_wall_repository.dart';
import '../domain/wish_wall_models.dart';
import 'blessing_bag_policy_adapter.dart';

/// 소원벽게시판 전역 상태.
///
/// Wall(피드)/Detail(상세)/My(내 소원병) 화면이 공유하는 데이터 소스.
/// 복주머니 적립/차감은 전부 [BlessingBagPolicyAdapter]를 통해서만 수행하며,
/// 이 Provider 자체는 새로운 화폐를 만들지 않는다.
class WishWallProvider extends ChangeNotifier {
  WishWallProvider(this._repository, this._policy);

  final WishWallRepository _repository;
  final BlessingBagPolicyAdapter _policy;

  List<WishPost> _feed = [];
  List<WishPost> _myWishes = [];
  bool _isLoading = false;
  bool _loaded = false;

  List<WishPost> get feed => _feed;
  List<WishPost> get myWishes => _myWishes;
  bool get isLoading => _isLoading;
  bool get loaded => _loaded;
  BlessingBagPolicyAdapter get policy => _policy;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await loadFeed();
  }

  Future<void> loadFeed() async {
    _isLoading = true;
    notifyListeners();
    _feed = await _repository.fetchFeed();
    _isLoading = false;
    _loaded = true;
    notifyListeners();
  }

  Future<void> loadMyWishes() async {
    _myWishes = await _repository.fetchMyWishes();
    notifyListeners();
  }

  Future<WishPost?> fetchDetail(String wishId) {
    return _repository.fetchDetail(wishId);
  }

  Future<List<WishComment>> fetchComments(String wishId) {
    return _repository.fetchComments(wishId);
  }

  Future<WishComment> addComment(String wishId, String text) {
    return _repository.createComment(wishId, text);
  }

  /// 응원(♥) — 무료, 즉시 반영.
  Future<WishPost> support(String wishId) async {
    final updated = await _repository.support(wishId);
    _syncInLists(updated);
    notifyListeners();
    return updated;
  }

  /// 오늘의 기도(✧) — 무료, 하루 1회.
  ///
  /// [6-1-F 최종 결정] 기도는 이번 단계에서 DB/API로 저장하지 않고 daily_prayer
  /// 복주머니 정책도 사용하지 않는다. [_repository.submitDailyPrayer]가
  /// (ApiWishWallRepository에서) 서버 호출 없이 로컬 상태만 토글해 UI 피드백을
  /// 제공하며, 여기서 [_policy.earnDailyPrayerBonus]를 호출해 Wallet을
  /// 적립하지 않는다(daily_prayer PointPolicy 미등록 상태 유지).
  Future<WishPost> pray(String wishId) async {
    final updated = await _repository.submitDailyPrayer(wishId);
    _syncInLists(updated);
    notifyListeners();
    return updated;
  }

  /// 복주머니(✨) 보내기 — 실제 재화 소비를 거쳐야 하는 유일한 액션.
  ///
  /// [6-1-F 최종 결정 - 이중차감 방지] 서버 `/wishes/:id/bokju` API가
  /// `spendLuckPouch()`로 Wallet 차감 + WishBokju 기록 + Wish.bokjuCount 증가를
  /// 하나의 트랜잭션으로 이미 원자 처리하므로, 여기서는 [_repository.incrementPouch]
  /// (=bokju API) 단 한 번만 호출한다. 과거에는 [_policy.sendPouch]가 먼저
  /// `WalletRepository.spend()`(`/wallet/spend`)를 직접 호출해 이중 차감이
  /// 발생했으므로 그 호출을 제거했다. [_policy.validateSend]는 UI 버튼
  /// 활성화/에러 표시 판단용으로만 계속 사용된다(blessing_bag_bottom_sheet.dart).
  /// 실패(예: 잔액 부족 400) 시 서버 응답 그대로 실패를 반환하며, Mock으로
  /// 몰래 대체하지 않는다.
  Future<bool> sendPouch(String wishId, int amount) async {
    try {
      final updated = await _repository.incrementPouch(wishId, amount);
      _syncInLists(updated);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 새 소원 작성(5-step compose 완료) — 성공 시 서버 정책(wish_reward,
  /// 1일 1회 +2)에 따라 실제 지급된 금액만큼 복주머니가 이미 적립된다.
  ///
  /// [6-1-F] 적립 자체는 서버 `/wishes` POST 트랜잭션 안에서 `earnLuckPouch()`로
  /// 완료되므로(ApiWishWallRepository.createWish가 grantedAmount를 반환),
  /// 여기서 클라이언트가 별도로 [_policy.earnWishCreatedBonus]를 호출해 중복
  /// 지급을 요청하지 않는다. 반환값은 화면(WishWallSuccessScreen)에서
  /// grantedAmount를 동적으로 표시할 수 있도록 (WishPost, grantedAmount) 튜플로
  /// 감싼다.
  Future<({WishPost wish, int grantedAmount})> createWish({
    required WishCategory categoryId,
    required double glassLevel,
    required String text,
    required WishVisibility visibility,
  }) async {
    final result = await _repository.createWishWithReward(
      categoryId: categoryId,
      glassLevel: glassLevel,
      text: text,
      visibility: visibility,
    );
    if (visibility != WishVisibility.private) {
      _feed = [result.wish, ..._feed];
    }
    _myWishes = [result.wish, ..._myWishes];
    notifyListeners();
    return result;
  }

  Future<void> reportWish(String wishId, String reason) {
    return _repository.reportWish(wishId, reason);
  }

  Future<void> hideWish(String wishId) async {
    await _repository.hideWish(wishId);
    _feed.removeWhere((w) => w.id == wishId);
    notifyListeners();
  }

  Future<void> blockUser(String authorId) async {
    await _repository.blockUser(authorId);
    _feed.removeWhere((w) => w.authorId == authorId);
    notifyListeners();
  }

  void _syncInLists(WishPost updated) {
    final feedIdx = _feed.indexWhere((w) => w.id == updated.id);
    if (feedIdx != -1) _feed[feedIdx] = updated;
    final myIdx = _myWishes.indexWhere((w) => w.id == updated.id);
    if (myIdx != -1) _myWishes[myIdx] = updated;
  }
}
