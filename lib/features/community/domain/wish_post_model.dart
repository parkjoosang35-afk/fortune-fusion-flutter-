/// 04A 도메인 F `wish_posts` 대응 모델(Mock 단계 간소화)
class WishPostModel {
  final String id;
  final String authorNickname;
  final String content;
  final int likeCount;
  final int commentCount;
  final DateTime createdAt;

  const WishPostModel({
    required this.id,
    required this.authorNickname,
    required this.content,
    required this.likeCount,
    required this.commentCount,
    required this.createdAt,
  });
}
