import '../../../core/api/api_result.dart';
import '../../../core/utils/mock_delay.dart';
import '../domain/wish_post_model.dart';

/// 06단계 §4.12(소원게시판/커뮤니티) `/v1/wishes/*` 대응 Mock Repository
///
/// 대응 API:
/// - GET  /wishes/feed            -> getFeed()
/// - GET  /wishes/popular         -> getFeed(tab: popular) 로 통합 처리(Mock 단순화)
/// - POST /wishes                 -> createPost()
/// - POST /wishes/:id/support     -> toggleSupport() ("행운 보내기" 임시정책: 포인트이동 없는 단순 응원카운트,
///                                    03§10.3/§18/§570 정책 미확정 사항 - 향후 포인트전송형 확정 시
///                                    amount 파라미터만 추가하면 되도록 인터페이스 설계)
/// - GET  /wishes/:id (댓글포함)   -> getComments()
/// - POST /wishes/:id/comments    -> addComment()
/// - POST /{targetType}/:id/report -> report() (폴리모픽 공용신고, L-6 대응)
class WishPostRepository {
  final List<WishPostModel> _posts = [
    WishPostModel(
      id: 'wp_1',
      authorNickname: '별빛달빛',
      content: '올해는 꼭 이사가 잘 되길 소원해봅니다 🙏',
      category: '이사/이동',
      isAnonymous: false,
      supportCount: 12,
      commentCount: 3,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    WishPostModel(
      id: 'wp_2',
      authorNickname: '익명',
      content: '다음 달 시험 꼭 붙게 해주세요! AI 사주에서도 좋다고 나왔어요',
      category: '학업/시험',
      isAnonymous: true,
      supportCount: 8,
      commentCount: 1,
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    WishPostModel(
      id: 'wp_3',
      authorNickname: '초심자',
      content: '오늘 타로 결과가 너무 정확해서 놀랐어요 다들 해보세요',
      category: '기타',
      isAnonymous: false,
      supportCount: 21,
      commentCount: 7,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  final Map<String, List<WishCommentModel>> _comments = {
    'wp_1': [
      WishCommentModel(
        id: 'wc_1',
        wishId: 'wp_1',
        authorNickname: '행운가득',
        content: '꼭 이루어지길 바라요!',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
    ],
  };

  final List<Map<String, String>> _reports = [];

  int _commentSeq = 2;
  int _postSeq = 4;

  Future<ApiResult<List<WishPostModel>>> getFeed({
    WishFeedTab tab = WishFeedTab.all,
  }) async {
    await mockDelay(ms: 500);
    var list = List<WishPostModel>.from(_posts);
    switch (tab) {
      case WishFeedTab.popular:
        list.sort((a, b) => b.supportCount.compareTo(a.supportCount));
        break;
      case WishFeedTab.mine:
        list = list.where((p) => p.isMine).toList();
        break;
      case WishFeedTab.all:
        break;
    }
    return ApiResult.ok(List.unmodifiable(list));
  }

  Future<ApiResult<WishPostModel>> createPost(
    String content, {
    String category = '기타',
    bool isAnonymous = false,
  }) async {
    await mockDelay(ms: 400);
    if (content.trim().isEmpty) return ApiResult.fail('내용을 입력해 주세요.');
    final post = WishPostModel(
      id: 'wp_${_postSeq++}',
      authorNickname: isAnonymous ? '익명' : '나',
      content: content.trim(),
      category: category,
      isAnonymous: isAnonymous,
      supportCount: 0,
      commentCount: 0,
      isMine: true,
      createdAt: DateTime.now(),
    );
    _posts.insert(0, post);
    return ApiResult.ok(post);
  }

  /// "행운 보내기" - 포인트 이동 없는 단순 응원(support) 토글
  Future<ApiResult<WishPostModel>> toggleSupport(String wishId) async {
    await mockDelay(ms: 250);
    final index = _posts.indexWhere((p) => p.id == wishId);
    if (index == -1) return ApiResult.fail('게시글을 찾을 수 없습니다.');
    final current = _posts[index];
    final nextSupported = !current.isSupportedByMe;
    final updated = current.copyWith(
      supportCount: current.supportCount + (nextSupported ? 1 : -1),
      isSupportedByMe: nextSupported,
    );
    _posts[index] = updated;
    return ApiResult.ok(updated);
  }

  Future<ApiResult<List<WishCommentModel>>> getComments(String wishId) async {
    await mockDelay(ms: 300);
    return ApiResult.ok(List.unmodifiable(_comments[wishId] ?? const []));
  }

  Future<ApiResult<WishCommentModel>> addComment(
    String wishId,
    String content,
  ) async {
    await mockDelay(ms: 300);
    if (content.trim().isEmpty) return ApiResult.fail('댓글 내용을 입력해 주세요.');
    final comment = WishCommentModel(
      id: 'wc_${_commentSeq++}',
      wishId: wishId,
      authorNickname: '나',
      content: content.trim(),
      createdAt: DateTime.now(),
    );
    _comments.putIfAbsent(wishId, () => []).add(comment);
    final postIndex = _posts.indexWhere((p) => p.id == wishId);
    if (postIndex != -1) {
      final current = _posts[postIndex];
      _posts[postIndex] = current.copyWith(
        commentCount: current.commentCount + 1,
      );
    }
    return ApiResult.ok(comment);
  }

  /// 06§4.12 `POST /{targetType}/:id/report` 공용 신고(L-6, 폴리모픽)
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
