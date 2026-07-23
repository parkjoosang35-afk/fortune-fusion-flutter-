/// 04A 도메인M `matching_profiles`(M-1) 대응 모델
class MatchingProfileModel {
  final String userId;
  final bool isPublic;
  final String introText;
  final List<String> preferences; // 이상형 조건 태그(간소화)

  const MatchingProfileModel({
    required this.userId,
    this.isPublic = true,
    this.introText = '',
    this.preferences = const [],
  });

  MatchingProfileModel copyWith({
    bool? isPublic,
    String? introText,
    List<String>? preferences,
  }) {
    return MatchingProfileModel(
      userId: userId,
      isPublic: isPublic ?? this.isPublic,
      introText: introText ?? this.introText,
      preferences: preferences ?? this.preferences,
    );
  }
}

/// `GET /matching/recommendations` 대응 - 추천 대상 카드 표시용 모델
/// (matching_profiles + users 조인 결과를 화면 표시용으로 간소화한 DTO)
class MatchingCandidateModel {
  final String userId;
  final String nickname;
  final int age;
  final String introText;
  final List<String> preferences;
  final String emoji; // 이미지 대신 이모지로 Mock 표현(03§9.2 과설계 방지)
  final bool likedByMe;

  const MatchingCandidateModel({
    required this.userId,
    required this.nickname,
    required this.age,
    required this.introText,
    required this.preferences,
    required this.emoji,
    this.likedByMe = false,
  });

  MatchingCandidateModel copyWith({bool? likedByMe}) {
    return MatchingCandidateModel(
      userId: userId,
      nickname: nickname,
      age: age,
      introText: introText,
      preferences: preferences,
      emoji: emoji,
      likedByMe: likedByMe ?? this.likedByMe,
    );
  }
}

/// 04A `matching_pairs`(M-3) 대응 - status(Base): active/unmatched
enum MatchingPairStatus { pendingAccept, active, unmatched }

class MatchingPairModel {
  final String id;
  final String partnerUserId;
  final String partnerNickname;
  final String partnerEmoji;
  final MatchingPairStatus status;
  final DateTime matchedAt;
  final String? lastMessage;

  const MatchingPairModel({
    required this.id,
    required this.partnerUserId,
    required this.partnerNickname,
    required this.partnerEmoji,
    required this.status,
    required this.matchedAt,
    this.lastMessage,
  });

  MatchingPairModel copyWith({
    MatchingPairStatus? status,
    String? lastMessage,
  }) {
    return MatchingPairModel(
      id: id,
      partnerUserId: partnerUserId,
      partnerNickname: partnerNickname,
      partnerEmoji: partnerEmoji,
      status: status ?? this.status,
      matchedAt: matchedAt,
      lastMessage: lastMessage ?? this.lastMessage,
    );
  }
}

/// `chat_rooms`(M-6)+`chat_messages` 대응 - 간소화 메시지 모델
/// 06§11.2: 스펙상 WebSocket이나, 인프라 도입 전 Mock 단계는 REST 폴링으로 간소화
class ChatMessageModel {
  final String id;
  final String pairId;
  final bool isMine;
  final String content;
  final DateTime sentAt;

  const ChatMessageModel({
    required this.id,
    required this.pairId,
    required this.isMine,
    required this.content,
    required this.sentAt,
  });
}

/// 06§4.6 `POST /matching/report` 폴리모픽 신고 - community의 ReportTargetType과
/// 별개 enum(도메인 경계 분리, 04A reports는 공용테이블이나 Dart 타입은 기능별 유지)
enum MatchingReportTargetType { candidate, pair, chatMessage }
