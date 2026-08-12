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

  /// 오늘의 기도(✧) — 무료, 하루 1회. 성공 시 복주머니 +1 지급.
  Future<WishPost> pray(String wishId) async {
    final updated = await _repository.submitDailyPrayer(wishId);
    await _policy.earnDailyPrayerBonus();
    _syncInLists(updated);
    notifyListeners();
    return updated;
  }

  /// 복주머니(✨) 보내기 — 실제 재화 소비를 거쳐야 하는 유일한 액션.
  /// 성공 시에만 서버(mock)측 pouchCount를 올린다.
  Future<bool> sendPouch(String wishId, int amount) async {
    final wish = await _repository.fetchDetail(wishId);
    if (wish == null) return false;
    final ok = await _policy.sendPouch(target: wish, amount: amount);
    if (!ok) return false;
    final updated = await _repository.incrementPouch(wishId, amount);
    _syncInLists(updated);
    notifyListeners();
    return true;
  }

  /// 새 소원 작성(5-step compose 완료) — 성공 시 복주머니 +5 자동 지급.
  Future<WishPost> createWish({
    required WishCategory categoryId,
    required double glassLevel,
    required String text,
    required WishVisibility visibility,
  }) async {
    final wish = await _repository.createWish(
      categoryId: categoryId,
      glassLevel: glassLevel,
      text: text,
      visibility: visibility,
    );
    await _policy.earnWishCreatedBonus();
    if (visibility != WishVisibility.private) {
      _feed = [wish, ..._feed];
    }
    _myWishes = [wish, ..._myWishes];
    notifyListeners();
    return wish;
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
