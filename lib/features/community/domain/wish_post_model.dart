/// 04A 도메인L `wishes`(L-3) 대응 모델(Mock 단계)
///
/// 04A 스펙 필드 매핑:
/// - content, category, is_anonymous, support_count(캐시) 반영
/// - is_supported_by_me / is_mine 은 실제 API에서도 흔히 조회 시점에
///   현재 사용자 기준으로 함께 내려주는 echo 필드(별도 원자단위 신설 없이
///   기존 wishes 엔티티에 편의 필드로 포함) - 03§9.2 과설계 방지 원칙 준수
class WishPostModel {
  final String id;
  final String authorNickname;
  final String content;
  final String category;
  final bool isAnonymous;
  final int supportCount;
  final int commentCount;
  final bool isSupportedByMe;
  final bool isMine;
  final DateTime createdAt;

  const WishPostModel({
    required this.id,
    required this.authorNickname,
    required this.content,
    required this.category,
    required this.isAnonymous,
    required this.supportCount,
    required this.commentCount,
    required this.createdAt,
    this.isSupportedByMe = false,
    this.isMine = false,
  });

  /// 기존 화면(community_screen.dart)에서 사용 중인 명칭과의 호환을 위한 별칭
  /// (04A 정식 필드명은 supportCount이며, 신규 코드는 supportCount를 사용할 것)
  int get likeCount => supportCount;

  WishPostModel copyWith({
    int? supportCount,
    int? commentCount,
    bool? isSupportedByMe,
  }) {
    return WishPostModel(
      id: id,
      authorNickname: authorNickname,
      content: content,
      category: category,
      isAnonymous: isAnonymous,
      supportCount: supportCount ?? this.supportCount,
      commentCount: commentCount ?? this.commentCount,
      isSupportedByMe: isSupportedByMe ?? this.isSupportedByMe,
      isMine: isMine,
      createdAt: createdAt,
    );
  }
}

/// 04A 도메인L `comments`(L-4, 폴리모픽) 대응 모델
/// - 이번 소단위는 targetType='wish' 고정 범위로 단순화(향후 게시글 댓글 확장 시
///   targetType 파라미터만 재사용, 신규 원자단위 추가 불필요)
class WishCommentModel {
  final String id;
  final String wishId;
  final String authorNickname;
  final String content;
  final DateTime createdAt;

  const WishCommentModel({
    required this.id,
    required this.wishId,
    required this.authorNickname,
    required this.content,
    required this.createdAt,
  });
}

/// 소원게시판 피드 탭 상태 - 03§7.7 [전체/인기/내소원] 탭 대응
enum WishFeedTab { all, popular, mine }

/// 04A 도메인L `reports`(L-6, 폴리모픽) 대응 - 신고 대상 유형
/// - 06§4.12 `POST /{targetType}/:id/report` 공용 신고 API에 대응
enum ReportTargetType { wish, communityPost, comment }
