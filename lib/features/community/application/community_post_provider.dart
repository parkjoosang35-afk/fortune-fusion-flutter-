import 'package:flutter/foundation.dart';
import '../data/community_post_repository.dart';
import '../domain/community_post_model.dart';
import '../domain/wish_post_model.dart' show ReportTargetType;

/// 02§12/06§4.12 리워드 커뮤니티(자유게시판형) 상태관리
/// 소원게시판(WishPostProvider)과 별개 Provider로 두어 서로 결합되지 않도록 한다.
class CommunityPostProvider extends ChangeNotifier {
  final CommunityPostRepository _repository;
  CommunityPostProvider(this._repository);

  List<CommunityBoardModel> _boards = [];
  List<CommunityPostModel> _posts = [];
  bool _isLoadingBoards = false;
  bool _isLoadingPosts = false;
  String? _currentBoardId;

  final Map<String, List<CommunityCommentModel>> _commentsByPostId = {};
  final Set<String> _loadingCommentsFor = {};

  List<CommunityBoardModel> get boards => _boards;
  List<CommunityPostModel> get posts => _posts;
  bool get isLoadingBoards => _isLoadingBoards;
  bool get isLoadingPosts => _isLoadingPosts;
  String? get currentBoardId => _currentBoardId;

  List<CommunityCommentModel> commentsOf(String postId) =>
      _commentsByPostId[postId] ?? const [];
  bool isLoadingCommentsOf(String postId) =>
      _loadingCommentsFor.contains(postId);

  Future<void> loadBoards() async {
    _isLoadingBoards = true;
    notifyListeners();
    final result = await _repository.getBoards();
    if (result.success) _boards = result.data!;
    _isLoadingBoards = false;
    notifyListeners();
  }

  Future<void> loadPosts({String? boardId, bool sortByPopular = false}) async {
    _currentBoardId = boardId;
    _isLoadingPosts = true;
    notifyListeners();
    final result = await _repository.getPosts(
      boardId: boardId,
      sortByPopular: sortByPopular,
    );
    if (result.success) _posts = result.data!;
    _isLoadingPosts = false;
    notifyListeners();
  }

  Future<bool> createPost({
    required String boardId,
    required String title,
    required String content,
  }) async {
    final result = await _repository.createPost(
      boardId: boardId,
      title: title,
      content: content,
    );
    if (result.success) {
      await loadPosts(boardId: _currentBoardId);
      return true;
    }
    return false;
  }

  Future<void> toggleLike(String postId) async {
    final result = await _repository.toggleLike(postId);
    if (!result.success) return;
    final updated = result.data!;
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index != -1) {
      _posts[index] = updated;
      notifyListeners();
    }
  }

  Future<void> loadComments(String postId) async {
    _loadingCommentsFor.add(postId);
    notifyListeners();
    final result = await _repository.getComments(postId);
    if (result.success) _commentsByPostId[postId] = result.data!;
    _loadingCommentsFor.remove(postId);
    notifyListeners();
  }

  Future<bool> addComment(String postId, String content) async {
    final result = await _repository.addComment(postId, content);
    if (!result.success) return false;
    await loadComments(postId);
    final index = _posts.indexWhere((p) => p.id == postId);
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
