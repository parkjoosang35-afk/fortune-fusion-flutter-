import '../../../core/api/api_result.dart';
import '../../../core/utils/mock_delay.dart';
import '../domain/matching_model.dart';

/// 06§4.6 `/v1/matching` 대응 Mock Repository
///
/// 대응 API:
/// - POST /matching/profile              -> saveProfile()
/// - GET  /matching/recommendations      -> getRecommendations()
/// - POST /matching/like                 -> like()
/// - POST /matching/request/:targetUserId -> requestMatch()
/// - POST /matching/pairs/:id/accept     -> acceptPair()
/// - POST /matching/pairs/:id/end        -> endPair()
/// - GET  /matching/pairs                -> getPairs()
/// - POST /matching/report               -> report()
/// - GET/POST /matching/chats/:pairId/messages -> getMessages()/sendMessage()
///   (06§11.2: 스펙상 WebSocket, Mock 단계는 REST 폴링으로 간소화)
class MatchingRepository {
  MatchingProfileModel? _myProfile;

  final List<MatchingCandidateModel> _candidates = [
    const MatchingCandidateModel(
      userId: 'u_101',
      nickname: '별빛나래',
      age: 28,
      introText: '조용한 카페에서 책 읽는 걸 좋아해요',
      preferences: ['독서', '카페투어'],
      emoji: '🌙',
    ),
    const MatchingCandidateModel(
      userId: 'u_102',
      nickname: '해달별',
      age: 31,
      introText: '주말엔 등산, 평일엔 요리해요',
      preferences: ['등산', '요리'],
      emoji: '⭐',
    ),
    const MatchingCandidateModel(
      userId: 'u_103',
      nickname: '초록숲',
      age: 26,
      introText: '반려식물 12개 키우는 집사입니다',
      preferences: ['식물', '산책'],
      emoji: '🌿',
    ),
    const MatchingCandidateModel(
      userId: 'u_104',
      nickname: '커피한잔',
      age: 29,
      introText: '핸드드립 커피 내리는 게 취미예요',
      preferences: ['커피', '음악감상'],
      emoji: '☕',
    ),
    const MatchingCandidateModel(
      userId: 'u_105',
      nickname: '여행자K',
      age: 33,
      introText: '이번엔 어디로 떠나볼까 고민중',
      preferences: ['여행', '사진'],
      emoji: '✈️',
    ),
  ];

  final List<MatchingPairModel> _pairs = [];
  final Map<String, List<ChatMessageModel>> _messages = {};
  final List<Map<String, String>> _reports = [];
  int _pairSeq = 1;
  int _msgSeq = 1;

  Future<ApiResult<MatchingProfileModel>> saveProfile({
    required bool isPublic,
    required String introText,
    required List<String> preferences,
  }) async {
    await mockDelay(ms: 400);
    _myProfile = MatchingProfileModel(
      userId: 'me',
      isPublic: isPublic,
      introText: introText,
      preferences: preferences,
    );
    return ApiResult.ok(_myProfile!);
  }

  Future<ApiResult<MatchingProfileModel?>> getMyProfile() async {
    await mockDelay(ms: 200);
    return ApiResult.ok(_myProfile);
  }

  Future<ApiResult<List<MatchingCandidateModel>>> getRecommendations() async {
    await mockDelay(ms: 500);
    final list = _candidates.where((c) => !c.likedByMe).toList();
    return ApiResult.ok(List.unmodifiable(list));
  }

  /// 좋아요/스와이프(관심표시) - matching_likes(M-2) 대응
  /// 반환값 matched=true면 상호관심 확인(양쪽 다 좋아요 상태 시뮬레이션은 Mock 단순화를
  /// 위해 30% 확률로 즉시 매칭 성사 처리)
  Future<ApiResult<bool>> like(String targetUserId) async {
    await mockDelay(ms: 300);
    final index = _candidates.indexWhere((c) => c.userId == targetUserId);
    if (index == -1) return ApiResult.fail('대상을 찾을 수 없습니다.');
    _candidates[index] = _candidates[index].copyWith(likedByMe: true);
    final seed = targetUserId.hashCode.abs() % 10;
    final matched = seed < 3; // 30% 확률 즉시 성사(Mock 간소화)
    if (matched) {
      final candidate = _candidates[index];
      _pairs.insert(
        0,
        MatchingPairModel(
          id: 'pair_${_pairSeq++}',
          partnerUserId: candidate.userId,
          partnerNickname: candidate.nickname,
          partnerEmoji: candidate.emoji,
          status: MatchingPairStatus.pendingAccept,
          matchedAt: DateTime.now(),
        ),
      );
    }
    return ApiResult.ok(matched);
  }

  Future<ApiResult<MatchingPairModel>> requestMatch(String targetUserId) async {
    await mockDelay(ms: 300);
    final candidate = _candidates.where((c) => c.userId == targetUserId);
    if (candidate.isEmpty) return ApiResult.fail('대상을 찾을 수 없습니다.');
    final pair = MatchingPairModel(
      id: 'pair_${_pairSeq++}',
      partnerUserId: candidate.first.userId,
      partnerNickname: candidate.first.nickname,
      partnerEmoji: candidate.first.emoji,
      status: MatchingPairStatus.pendingAccept,
      matchedAt: DateTime.now(),
    );
    _pairs.insert(0, pair);
    return ApiResult.ok(pair);
  }

  Future<ApiResult<MatchingPairModel>> acceptPair(String pairId) async {
    await mockDelay(ms: 300);
    final index = _pairs.indexWhere((p) => p.id == pairId);
    if (index == -1) return ApiResult.fail('매칭을 찾을 수 없습니다.');
    final updated = _pairs[index].copyWith(status: MatchingPairStatus.active);
    _pairs[index] = updated;
    return ApiResult.ok(updated);
  }

  Future<ApiResult<MatchingPairModel>> endPair(
    String pairId, {
    String? reason,
  }) async {
    await mockDelay(ms: 300);
    final index = _pairs.indexWhere((p) => p.id == pairId);
    if (index == -1) return ApiResult.fail('매칭을 찾을 수 없습니다.');
    final updated = _pairs[index].copyWith(
      status: MatchingPairStatus.unmatched,
    );
    _pairs[index] = updated;
    return ApiResult.ok(updated);
  }

  Future<ApiResult<List<MatchingPairModel>>> getPairs() async {
    await mockDelay(ms: 400);
    return ApiResult.ok(List.unmodifiable(_pairs));
  }

  Future<ApiResult<void>> report(
    MatchingReportTargetType targetType,
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

  Future<ApiResult<List<ChatMessageModel>>> getMessages(String pairId) async {
    await mockDelay(ms: 300);
    return ApiResult.ok(List.unmodifiable(_messages[pairId] ?? const []));
  }

  Future<ApiResult<ChatMessageModel>> sendMessage(
    String pairId,
    String content,
  ) async {
    await mockDelay(ms: 250);
    if (content.trim().isEmpty) return ApiResult.fail('메시지를 입력해 주세요.');
    final message = ChatMessageModel(
      id: 'msg_${_msgSeq++}',
      pairId: pairId,
      isMine: true,
      content: content.trim(),
      sentAt: DateTime.now(),
    );
    _messages.putIfAbsent(pairId, () => []).add(message);
    final pairIndex = _pairs.indexWhere((p) => p.id == pairId);
    if (pairIndex != -1) {
      _pairs[pairIndex] = _pairs[pairIndex].copyWith(
        lastMessage: message.content,
      );
    }
    return ApiResult.ok(message);
  }
}
