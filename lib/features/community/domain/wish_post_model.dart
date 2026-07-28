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

  /// [웹→앱 이식] 신통방통 wish.html "같은 목표를 가진 사람과 함께 응원받기(선택)" 목표태그.
  /// 04A 신규 원자단위 신설 없이 wishes 엔티티에 편의 필드로 포함(선택값, null 허용).
  final String? goalTag;

  // [소원성(Wish Castle) 확장] 촛불 성장 시스템 필드 - 기존 support_count(단순 응원
  // on/off)와는 완전히 별개의 신규 필드다. bokjuCount(복주머니)는 실제 포인트/지갑
  // 이동이 전혀 없는 상징적 응원 단위이며, candleLevel(0~4)은 서버가 bokjuCount와
  // wish_config 임계값을 기준으로 계산해 캐시해둔 값을 그대로 내려받는다.
  // 하위호환을 위해 전부 기본값을 둔다(과거 API 응답/Mock 데이터에 필드가 없어도 동작).
  final int candleLevel;
  final int bokjuCount;
  final DateTime? achievedAt;
  final bool isMilestoneShown;

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
    this.goalTag,
    this.candleLevel = 0,
    this.bokjuCount = 0,
    this.achievedAt,
    this.isMilestoneShown = false,
  });

  /// 기존 화면(community_screen.dart)에서 사용 중인 명칭과의 호환을 위한 별칭
  /// (04A 정식 필드명은 supportCount이며, 신규 코드는 supportCount를 사용할 것)
  int get likeCount => supportCount;

  /// 소원성(Wish Castle) 촛불 5레벨(0~4) 메타 - admin_web WISH_CANDLE_LEVELS와 대응.
  /// 최종 레벨(4) 도달 여부는 [isMaxLevel]로 판별한다.
  static const int maxCandleLevel = 4;
  bool get isMaxLevel => candleLevel >= maxCandleLevel;

  WishPostModel copyWith({
    int? supportCount,
    int? commentCount,
    bool? isSupportedByMe,
    int? candleLevel,
    int? bokjuCount,
    DateTime? achievedAt,
    bool? isMilestoneShown,
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
      goalTag: goalTag,
      candleLevel: candleLevel ?? this.candleLevel,
      bokjuCount: bokjuCount ?? this.bokjuCount,
      achievedAt: achievedAt ?? this.achievedAt,
      isMilestoneShown: isMilestoneShown ?? this.isMilestoneShown,
    );
  }
}

/// 소원성(Wish Castle) 촛불 5레벨(0~4) 이름/이모지 - admin_web
/// `src/lib/wish-config-meta.ts`의 WISH_CANDLE_LEVELS와 1:1 대응(하드코딩 동기화).
/// 관리자가 임계값(승급 기준)만 CMS에서 바꿀 수 있고, 레벨 이름/이모지는 고정 상수로 둔다
/// (03§9.2 과설계 방지 - 이름까지 서버에서 내려받을 필요는 없는 정적 메타데이터).
class WishCandleLevelMeta {
  final int level;
  final String name;
  final String emoji;
  const WishCandleLevelMeta({
    required this.level,
    required this.name,
    required this.emoji,
  });
}

const List<WishCandleLevelMeta> wishCandleLevels = [
  WishCandleLevelMeta(level: 0, name: '작은 촛불', emoji: '🕯️'),
  WishCandleLevelMeta(level: 1, name: '희망의 불꽃', emoji: '🔥'),
  WishCandleLevelMeta(level: 2, name: '따뜻한 불꽃', emoji: '🔥'),
  WishCandleLevelMeta(level: 3, name: '축복의 불꽃', emoji: '✨'),
  WishCandleLevelMeta(level: 4, name: '가장 밝은 불꽃', emoji: '🌟'),
];

WishCandleLevelMeta wishCandleLevelOf(int level) =>
    wishCandleLevels[level.clamp(0, wishCandleLevels.length - 1)];

/// [웹→앱 이식] 신통방통 wish.html "🏆 소원성 명예의 전당" 대응 - 응원을 많이 받은
/// 작성자 랭킹 항목(파생 데이터, 별도 API/원자단위 없이 posts로부터 클라이언트에서 집계).
class WishHallOfFameEntry {
  final String nickname;
  final int totalSupport;
  final int wishCount;

  const WishHallOfFameEntry({
    required this.nickname,
    required this.totalSupport,
    required this.wishCount,
  });
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
