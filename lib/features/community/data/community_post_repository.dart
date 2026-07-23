import '../../../core/api/api_result.dart';
import '../../../core/utils/mock_delay.dart';
import '../domain/community_post_model.dart';
import '../domain/wish_post_model.dart' show ReportTargetType;

/// 06단계 §4.12(리워드 커뮤니티) `/v1/community/*` 대응 Mock Repository
///
/// 대응 API:
/// - GET  /community/boards           -> getBoards()
/// - GET  /community/posts?board_id=  -> getPosts()
/// - GET  /community/posts/popular    -> getPosts(sortByPopular: true) (Mock 단순화)
/// - POST /community/posts            -> createPost()
/// - POST /{targetType}/:id/report(폴리모픽, targetType=communityPost) -> report()
///   (좋아요/댓글은 L-5/L-4 폴리모픽 테이블을 소원게시판과 공유하는 설계이므로,
///    이 Repository 내부에 동일한 모양의 toggleLike/getComments/addComment를
///    별도 상태로 구현한다 - Provider 간 결합은 만들지 않음)
class CommunityPostRepository {
  final List<CommunityBoardModel> _boards = const [
    CommunityBoardModel(
      id: 'board_free',
      code: 'free',
      name: '자유게시판',
      sortOrder: 0,
    ),
    CommunityBoardModel(
      id: 'board_saju_share',
      code: 'saju_share',
      name: '사주공유',
      sortOrder: 1,
    ),
    CommunityBoardModel(
      id: 'board_tarot_share',
      code: 'tarot_share',
      name: '타로공유',
      sortOrder: 2,
    ),
    CommunityBoardModel(
      id: 'board_compat_proof',
      code: 'compat_proof',
      name: '궁합인증',
      sortOrder: 3,
    ),
  ];

  final List<CommunityPostModel> _posts = [
    CommunityPostModel(
      id: 'cp_1',
      boardId: 'board_free',
      boardName: '자유게시판',
      authorNickname: '행운가득',
      title: '다들 오늘 운세 어떠셨나요?',
      content: '저는 오늘 사주 결과가 너무 좋게 나와서 기분 좋은 하루였어요! 다들 좋은 하루 보내세요~',
      likeCount: 15,
      commentCount: 4,
      isPinned: true,
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    CommunityPostModel(
      id: 'cp_2',
      boardId: 'board_saju_share',
      boardName: '사주공유',
      authorNickname: '별빛달빛',
      title: '사주 결과 공유해요 (재물운 대박)',
      content: '이번 달 재물운 사주 결과가 정말 신기하게 잘 맞아서 공유합니다.',
      likeCount: 9,
      commentCount: 2,
      createdAt: DateTime.now().subtract(const Duration(hours: 6)),
    ),
    CommunityPostModel(
      id: 'cp_3',
      boardId: 'board_tarot_share',
      boardName: '타로공유',
      authorNickname: '초심자',
      title: '타로 3카드 스프레드 결과 후기',
      content: '연애운 관련해서 뽑아봤는데 결과가 정말 인상적이었습니다.',
      likeCount: 21,
      commentCount: 6,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    CommunityPostModel(
      id: 'cp_4',
      boardId: 'board_compat_proof',
      boardName: '궁합인증',
      authorNickname: '커플행복',
      title: '저희 궁합 결과 인증합니다 (feat. 사귄지 1년)',
      content: '1년 전 이 앱으로 궁합 봤었는데 결과가 딱 맞았어서 다시 인증하러 왔어요.',
      likeCount: 33,
      commentCount: 11,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];

  final Map<String, List<CommunityCommentModel>> _comments = {
    'cp_1': [
      CommunityCommentModel(
        id: 'cc_1',
        postId: 'cp_1',
        authorNickname: '행운나눔',
        content: '저도 오늘 운세 좋았어요! 공감합니다',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
    ],
  };

  final List<Map<String, String>> _reports = [];

  int _postSeq = 5;
  int _commentSeq = 2;

  Future<ApiResult<List<CommunityBoardModel>>> getBoards() async {
    await mockDelay(ms: 400);
    final sorted = List<CommunityBoardModel>.from(_boards)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return ApiResult.ok(List.unmodifiable(sorted));
  }

  Future<ApiResult<List<CommunityPostModel>>> getPosts({
    String? boardId,
    bool sortByPopular = false,
  }) async {
    await mockDelay(ms: 500);
    var list = List<CommunityPostModel>.from(_posts);
    if (boardId != null) {
      list = list.where((p) => p.boardId == boardId).toList();
    }
    if (sortByPopular) {
      list.sort((a, b) => b.likeCount.compareTo(a.likeCount));
    } else {
      list.sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return b.createdAt.compareTo(a.createdAt);
      });
    }
    return ApiResult.ok(List.unmodifiable(list));
  }

  Future<ApiResult<CommunityPostModel>> createPost({
    required String boardId,
    required String title,
    required String content,
  }) async {
    await mockDelay(ms: 400);
    if (title.trim().isEmpty || content.trim().isEmpty) {
      return ApiResult.fail('제목과 내용을 모두 입력해 주세요.');
    }
    final board = _boards.firstWhere(
      (b) => b.id == boardId,
      orElse: () => _boards.first,
    );
    final post = CommunityPostModel(
      id: 'cp_${_postSeq++}',
      boardId: board.id,
      boardName: board.name,
      authorNickname: '나',
      title: title.trim(),
      content: content.trim(),
      isMine: true,
      createdAt: DateTime.now(),
    );
    _posts.insert(0, post);
    return ApiResult.ok(post);
  }

  Future<ApiResult<CommunityPostModel>> toggleLike(String postId) async {
    await mockDelay(ms: 250);
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index == -1) return ApiResult.fail('게시글을 찾을 수 없습니다.');
    final current = _posts[index];
    final next = !current.isLikedByMe;
    final updated = current.copyWith(
      likeCount: current.likeCount + (next ? 1 : -1),
      isLikedByMe: next,
    );
    _posts[index] = updated;
    return ApiResult.ok(updated);
  }

  Future<ApiResult<List<CommunityCommentModel>>> getComments(
    String postId,
  ) async {
    await mockDelay(ms: 300);
    return ApiResult.ok(List.unmodifiable(_comments[postId] ?? const []));
  }

  Future<ApiResult<CommunityCommentModel>> addComment(
    String postId,
    String content,
  ) async {
    await mockDelay(ms: 300);
    if (content.trim().isEmpty) return ApiResult.fail('댓글 내용을 입력해 주세요.');
    final comment = CommunityCommentModel(
      id: 'cc_${_commentSeq++}',
      postId: postId,
      authorNickname: '나',
      content: content.trim(),
      createdAt: DateTime.now(),
    );
    _comments.putIfAbsent(postId, () => []).add(comment);
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index != -1) {
      _posts[index] = _posts[index].copyWith(
        commentCount: _posts[index].commentCount + 1,
      );
    }
    return ApiResult.ok(comment);
  }

  /// 06§4.12 `POST /{targetType}/:id/report` 공용 신고(L-6, 폴리모픽)
  /// targetType='communityPost'로 소원게시판과 동일한 폴리모픽 신고 인터페이스 재사용
  Future<ApiResult<void>> report(
    ReportTargetType targetType,
    String targetId,
    String reason,
  ) async {
    await mockDelay(ms: 300);
    if (reason.trim().isEmpty) return ApiResult.fail('신고 사유를 입력해 주세요.');
    _reports.add({
      'targetType': targetType.name,
      'targetId': targetId,
      'reason': reason.trim(),
    });
    return ApiResult.ok(null);
  }
}
