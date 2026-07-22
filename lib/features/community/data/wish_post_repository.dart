import '../../../core/api/api_result.dart';
import '../../../core/utils/mock_delay.dart';
import '../domain/wish_post_model.dart';

/// 06단계 §4.9(커뮤니티) `/v1/community/wish-posts` 대응 Mock Repository
class WishPostRepository {
  final List<WishPostModel> _posts = [
    WishPostModel(
      id: 'wp_1',
      authorNickname: '별빛달빛',
      content: '올해는 꼭 이사가 잘 되길 소원해봅니다 🙏',
      likeCount: 12,
      commentCount: 3,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    WishPostModel(
      id: 'wp_2',
      authorNickname: '행운가득',
      content: '다음 달 시험 꼭 붙게 해주세요! AI 사주에서도 좋다고 나왔어요',
      likeCount: 8,
      commentCount: 1,
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    WishPostModel(
      id: 'wp_3',
      authorNickname: '초심자',
      content: '오늘 타로 결과가 너무 정확해서 놀랐어요 다들 해보세요',
      likeCount: 21,
      commentCount: 7,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  Future<ApiResult<List<WishPostModel>>> getFeed() async {
    await mockDelay(ms: 500);
    return ApiResult.ok(List.unmodifiable(_posts));
  }

  Future<ApiResult<WishPostModel>> createPost(String content) async {
    await mockDelay(ms: 400);
    if (content.trim().isEmpty) return ApiResult.fail('내용을 입력해 주세요.');
    final post = WishPostModel(
      id: 'wp_${_posts.length + 1}',
      authorNickname: '나',
      content: content.trim(),
      likeCount: 0,
      commentCount: 0,
      createdAt: DateTime.now(),
    );
    _posts.insert(0, post);
    return ApiResult.ok(post);
  }
}
