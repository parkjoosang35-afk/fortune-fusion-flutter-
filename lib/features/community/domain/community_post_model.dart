/// 04A 도메인L `community_boards`(L-1, 마스터) 대응 모델(Mock 단계)
class CommunityBoardModel {
  final String id;
  final String code;
  final String name;
  final String? description;
  final int sortOrder;

  const CommunityBoardModel({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    this.sortOrder = 0,
  });
}

/// 04A 도메인L `community_posts`(L-2) 대응 모델(Mock 단계)
///
/// 04A 스펙 필드 매핑:
/// - board_id, title, content, like_count, comment_count, is_pinned 반영
/// - linked_fortune_result_id는 P1 확장범위(AI 결과 카드 첨부)로 이번 소단위 제외
///   (03§9.2 과설계 방지 원칙 - 필요 시점에 nullable 필드만 추가하면 되므로 지금 신설하지 않음)
/// - isLikedByMe/isMine은 L-3(wishes)와 동일하게 조회시점 echo 필드로 포함
class CommunityPostModel {
  final String id;
  final String boardId;
  final String boardName;
  final String authorNickname;
  final String title;
  final String content;
  final int likeCount;
  final int commentCount;
  final bool isPinned;
  final bool isLikedByMe;
  final bool isMine;
  final DateTime createdAt;

  const CommunityPostModel({
    required this.id,
    required this.boardId,
    required this.boardName,
    required this.authorNickname,
    required this.title,
    required this.content,
    required this.createdAt,
    this.likeCount = 0,
    this.commentCount = 0,
    this.isPinned = false,
    this.isLikedByMe = false,
    this.isMine = false,
  });

  CommunityPostModel copyWith({
    int? likeCount,
    int? commentCount,
    bool? isLikedByMe,
  }) {
    return CommunityPostModel(
      id: id,
      boardId: boardId,
      boardName: boardName,
      authorNickname: authorNickname,
      title: title,
      content: content,
      createdAt: createdAt,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      isPinned: isPinned,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
      isMine: isMine,
    );
  }
}

/// 04A 도메인L `comments`(L-4, 폴리모픽 target_type='post') 대응 모델
/// - wish_post_model.dart의 WishCommentModel과 별개 클래스로 두어 게시판 종류간
///   결합을 만들지 않는다(각 Provider가 자신의 댓글만 관리 - 03§9.2 원칙).
class CommunityCommentModel {
  final String id;
  final String postId;
  final String authorNickname;
  final String content;
  final DateTime createdAt;

  const CommunityCommentModel({
    required this.id,
    required this.postId,
    required this.authorNickname,
    required this.content,
    required this.createdAt,
  });
}
