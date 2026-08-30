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

  // [STEP04 PART2 §8] 현재 선택된 정렬 기준('latest'|'popular'). 화면이
  // 값을 바꾸면 [loadFeed]를 다시 호출해 서버에 새 sort로 재조회한다.
  String _sort = 'latest';
  String get sort => _sort;

  Future<void> loadFeed({String? sort}) async {
    if (sort != null) _sort = sort;
    _isLoading = true;
    notifyListeners();
    _feed = await _repository.fetchFeed(sort: _sort);
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

  /// [소원방 마무리 - Phase A] 응원 작성 + 서버가 실제 지급한 wish_comment
  /// 복주머니 금액을 함께 반환한다(markWishFulfilled와 동일한 패턴 — 서버
  /// 트랜잭션이 이미 지급을 확정했으므로 호출부는 이 값만 표시하면 된다).
  Future<({WishComment comment, int grantedAmount})> addCommentWithReward(
    String wishId,
    String text,
  ) {
    return _repository.createCommentWithReward(wishId, text);
  }

  Future<void> reportComment(String commentId, String reason) {
    return _repository.reportComment(commentId, reason);
  }

  /// 응원(♥) — 무료, 즉시 반영.
  ///
  /// [STEP04 PART2 §1] 서버가 최종 판단한 [WishPost.hasSupportedByMe]/
  /// [WishPost.supportCount]와 이번 호출이 신규 응원이었는지(alreadySupported)
  /// 여부를 그대로 반환한다. 호출부는 alreadySupported로 애니메이션/Haptic
  /// 실행 여부를 결정할 수 있다(이미 응원한 경우 재연출하지 않기 위함).
  Future<({WishPost wish, bool alreadySupported})> support(
    String wishId,
  ) async {
    final result = await _repository.support(wishId);
    _syncInLists(result.wish);
    notifyListeners();
    return result;
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
  ///
  /// [SECTION10 발견 UX 버그 수정 — 최소 침습] 서버(`/wishes/:id/bokju`)는
  /// 실패 사유를 두 가지로 구분해 반환한다:
  /// - INSUFFICIENT_BALANCE(400): "복주머니가 부족합니다."
  /// - amount 화이트리스트[1,5,10,50,100] 위반(400): "amount는 1/5/10/50/100
  ///   중 하나여야 합니다."
  /// 과거에는 이 둘을 구분하지 않고 `catch (_) { return false; }`로 삼켜서
  /// 호출부(blessing_bag_bottom_sheet.dart)가 실패 원인과 무관하게 항상
  /// "복주머니가 부족해요"로 표시했다. 서버/DB 정책(화이트리스트 값,
  /// Wallet/PointHistory/WishBokju 구조)은 그대로 두고, 여기서 예외 메시지
  /// 문자열만 검사해 원인을 구분해 반환한다(신규 API/서버 변경 없음).
  Future<({bool ok, String? reasonCode})> sendPouch(
    String wishId,
    int amount,
  ) async {
    try {
      final updated = await _repository.incrementPouch(wishId, amount);
      _syncInLists(updated);
      notifyListeners();
      return (ok: true, reasonCode: null);
    } catch (e) {
      final message = e.toString();
      if (message.contains('1/5/10/50/100')) {
        return (ok: false, reasonCode: 'invalidAmount');
      }
      if (message.contains('복주머니가 부족합니다') ||
          message.contains('INSUFFICIENT_BALANCE')) {
        return (ok: false, reasonCode: 'insufficientBalance');
      }
      return (ok: false, reasonCode: 'unknown');
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
    String? sealItemCode,
    String? candleItemCode,
    String? talismanItemCode,
  }) async {
    final result = await _repository.createWishWithReward(
      categoryId: categoryId,
      glassLevel: glassLevel,
      text: text,
      visibility: visibility,
      sealItemCode: sealItemCode,
      candleItemCode: candleItemCode,
      talismanItemCode: talismanItemCode,
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

  // ── [복주머니 확장 Phase02-A 클라이언트 연동] 소원함 상태머신 ──────────
  // 화면(wish_room_home_screen/wish_room_box_opening_screen/
  // wish_room_detail_screen)은 Repository를 직접 호출하지 않고 반드시 이
  // Provider 계층을 거친다(기존 다른 메서드들과 동일한 아키텍처 패턴).

  /// unlockAt이 지났고 아직 개봉 화면을 보여준 적 없는 내 소원 목록을
  /// 서버에서 조회한다. 실패(비로그인 등) 시 빈 목록을 반환한다 —
  /// 호출부(홈 화면 initState)가 예외로 전체 로딩을 막지 않도록.
  Future<List<WishPost>> fetchPendingBoxOpenings() async {
    try {
      return await _repository.fetchPendingBoxOpenings();
    } catch (_) {
      return const [];
    }
  }

  /// [wishId]의 07 개봉 화면을 봤음을 서버에 기록한다(idempotent).
  /// [소원방 마무리 - Phase B] 서버가 이 호출 안에서 wish_100days(+30,
  /// 소원당 1회) 지급을 함께 확정하므로 grantedAmount도 반환한다
  /// (markWishFulfilled와 동일한 패턴). 기록 자체가 실패하면(비로그인/
  /// 네트워크 오류) grantedAmount=0으로 조용히 무시한다(기존 실패 허용
  /// 정책과 동일 — 다음 방문에 pending-openings가 다시 후보로 돌려줌).
  Future<int> markBoxOpened(String wishId) async {
    try {
      final result = await _repository.markBoxOpened(wishId);
      if (result.wish != null) {
        _syncInLists(result.wish!);
        notifyListeners();
      }
      return result.grantedAmount;
    } catch (_) {
      return 0;
    }
  }

  /// [wishId] 소원을 "이뤄졌어요"로 표시하고, 실제 지급된 복주머니 금액을
  /// 함께 반환한다(idempotent — 이미 fulfilled면 grantedAmount=0).
  Future<({WishPost wish, int grantedAmount})> markWishFulfilled(
    String wishId,
  ) async {
    final result = await _repository.markWishFulfilled(wishId);
    _syncInLists(result.wish);
    notifyListeners();
    return result;
  }
}
