import 'package:flutter/foundation.dart';
import '../data/wish_post_repository.dart';
import '../domain/wish_post_model.dart';

class WishPostProvider extends ChangeNotifier {
  final WishPostRepository _repository;
  WishPostProvider(this._repository);

  List<WishPostModel> _posts = [];
  bool _isLoading = false;
  WishFeedTab _currentTab = WishFeedTab.all;

  final Map<String, List<WishCommentModel>> _commentsByWishId = {};
  final Set<String> _loadingCommentsFor = {};

  List<WishPostModel> get posts => _posts;
  bool get isLoading => _isLoading;
  WishFeedTab get currentTab => _currentTab;

  List<WishCommentModel> commentsOf(String wishId) =>
      _commentsByWishId[wishId] ?? const [];
  bool isLoadingCommentsOf(String wishId) =>
      _loadingCommentsFor.contains(wishId);

  Future<void> loadFeed({WishFeedTab? tab}) async {
    _currentTab = tab ?? _currentTab;
    _isLoading = true;
    notifyListeners();
    final result = await _repository.getFeed(tab: _currentTab);
    if (result.success) _posts = result.data!;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> changeTab(WishFeedTab tab) async {
    if (_currentTab == tab) return;
    await loadFeed(tab: tab);
  }

  Future<bool> createPost(
    String content, {
    String category = '기타',
    bool isAnonymous = false,
  }) async {
    final result = await _repository.createPost(
      content,
      category: category,
      isAnonymous: isAnonymous,
    );
    if (result.success) {
      await loadFeed();
      return true;
    }
    return false;
  }

  /// "행운 보내기" - Mock 단계 임시정책: 포인트 이동 없는 단순 응원 토글
  /// (03§10.3/§18/§570 정책 미확정 - 향후 포인트전송형 확정 시 WalletProvider.spend/earn
  /// orchestrate를 이 메서드에 추가하는 정도로 영향도 최소화되도록 설계)
  Future<void> toggleSupport(String wishId) async {
    final result = await _repository.toggleSupport(wishId);
    if (!result.success) return;
    final updated = result.data!;
    final index = _posts.indexWhere((p) => p.id == wishId);
    if (index != -1) {
      _posts[index] = updated;
      notifyListeners();
    }
  }

  Future<void> loadComments(String wishId) async {
    _loadingCommentsFor.add(wishId);
    notifyListeners();
    final result = await _repository.getComments(wishId);
    if (result.success) _commentsByWishId[wishId] = result.data!;
    _loadingCommentsFor.remove(wishId);
    notifyListeners();
  }

  Future<bool> addComment(String wishId, String content) async {
    final result = await _repository.addComment(wishId, content);
    if (!result.success) return false;
    await loadComments(wishId);
    final index = _posts.indexWhere((p) => p.id == wishId);
    if (index != -1) {
      _posts[index] = _posts[index].copyWith(
        commentCount: _posts[index].commentCount + 1,
      );
      notifyListeners();
    }
    return true;
  }

  Future<bool> report(
    ReportTargetType targetType,
    String targetId,
    String reason,
  ) async {
    final result = await _repository.report(targetType, targetId, reason);
    return result.success;
  }
}
