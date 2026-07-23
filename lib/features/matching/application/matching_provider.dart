import 'package:flutter/foundation.dart';
import '../../../core/utils/load_state.dart';
import '../data/matching_repository.dart';
import '../domain/matching_model.dart';

/// 06§4.6 `/v1/matching` 대응 상태관리
/// - 내 프로필: `_profileState`(LoadState)
/// - 추천대상 목록: `_candidatesState`(LoadState)
/// - 매칭성사 목록: `_pairsState`(LoadState)
/// - 채팅 메시지: `_messagesByPairId`(pairId별 캐시, REST 폴링 Mock)
class MatchingProvider extends ChangeNotifier {
  final MatchingRepository _repository;
  MatchingProvider(this._repository);

  LoadState<MatchingProfileModel?> _profileState = const LoadState.initial();
  LoadState<MatchingProfileModel?> get profileState => _profileState;

  LoadState<List<MatchingCandidateModel>> _candidatesState =
      const LoadState.initial();
  LoadState<List<MatchingCandidateModel>> get candidatesState =>
      _candidatesState;

  LoadState<List<MatchingPairModel>> _pairsState = const LoadState.initial();
  LoadState<List<MatchingPairModel>> get pairsState => _pairsState;

  final Map<String, LoadState<List<ChatMessageModel>>> _messagesByPairId = {};
  LoadState<List<ChatMessageModel>> messagesOf(String pairId) =>
      _messagesByPairId[pairId] ?? const LoadState.initial();

  /// M-1 `matching_profiles` 등록/수정 - `POST /matching/profile`
  Future<bool> saveProfile({
    required bool isPublic,
    required String introText,
    required List<String> preferences,
  }) async {
    _profileState = LoadState.loading(previousData: _profileState.data);
    notifyListeners();
    final result = await _repository.saveProfile(
      isPublic: isPublic,
      introText: introText,
      preferences: preferences,
    );
    if (result.success && result.data != null) {
      _profileState = LoadState.success(result.data);
      notifyListeners();
      return true;
    }
    _profileState = LoadState.error(result.errorMessage ?? '프로필 저장에 실패했습니다.');
    notifyListeners();
    return false;
  }

  Future<void> loadMyProfile() async {
    _profileState = const LoadState.loading();
    notifyListeners();
    final result = await _repository.getMyProfile();
    if (result.success) {
      _profileState = LoadState.success(result.data);
    } else {
      _profileState = LoadState.error(
        result.errorMessage ?? '프로필을 불러오지 못했습니다.',
      );
    }
    notifyListeners();
  }

  /// `GET /matching/recommendations`
  Future<void> loadRecommendations() async {
    _candidatesState = LoadState.loading(previousData: _candidatesState.data);
    notifyListeners();
    final result = await _repository.getRecommendations();
    if (result.success && result.data != null) {
      _candidatesState = LoadState.success(result.data!);
    } else {
      _candidatesState = LoadState.error(
        result.errorMessage ?? '추천 대상을 불러오지 못했습니다.',
      );
    }
    notifyListeners();
  }

  /// `POST /matching/like` - 반환값 true면 즉시 매칭 성사(카드 넘김 후 성사 안내 표시용)
  Future<bool> like(String targetUserId) async {
    final result = await _repository.like(targetUserId);
    // 카드 스와이프 목록에서 제거(좋아요 처리된 대상은 추천목록에서 제외)
    final current = _candidatesState.data;
    if (current != null) {
      _candidatesState = LoadState.success(
        current.where((c) => c.userId != targetUserId).toList(),
      );
      notifyListeners();
    }
    if (result.success && result.data == true) {
      // 매칭 성사 시 성사 목록도 최신화
      await loadPairs();
      return true;
    }
    return false;
  }

  /// `POST /matching/request/:targetUserId`
  Future<bool> requestMatch(String targetUserId) async {
    final result = await _repository.requestMatch(targetUserId);
    if (result.success) {
      await loadPairs();
      return true;
    }
    return false;
  }

  /// `POST /matching/pairs/:id/accept`
  Future<bool> acceptPair(String pairId) async {
    final result = await _repository.acceptPair(pairId);
    if (!result.success || result.data == null) return false;
    _updatePairInState(result.data!);
    notifyListeners();
    return true;
  }

  /// `POST /matching/pairs/:id/end`
  Future<bool> endPair(String pairId, {String? reason}) async {
    final result = await _repository.endPair(pairId, reason: reason);
    if (!result.success || result.data == null) return false;
    _updatePairInState(result.data!);
    notifyListeners();
    return true;
  }

  /// `GET /matching/pairs`
  Future<void> loadPairs() async {
    _pairsState = LoadState.loading(previousData: _pairsState.data);
    notifyListeners();
    final result = await _repository.getPairs();
    if (result.success && result.data != null) {
      _pairsState = LoadState.success(result.data!);
    } else {
      _pairsState = LoadState.error(
        result.errorMessage ?? '매칭 목록을 불러오지 못했습니다.',
      );
    }
    notifyListeners();
  }

  /// `POST /matching/report`
  Future<bool> report(
    MatchingReportTargetType targetType,
    String targetId,
    String reason,
  ) async {
    final result = await _repository.report(targetType, targetId, reason);
    return result.success;
  }

  /// `GET /matching/chats/:pairId/messages` (REST 폴링, 06§11.2 간소화)
  Future<void> loadMessages(String pairId) async {
    _messagesByPairId[pairId] = LoadState.loading(
      previousData: _messagesByPairId[pairId]?.data,
    );
    notifyListeners();
    final result = await _repository.getMessages(pairId);
    if (result.success && result.data != null) {
      _messagesByPairId[pairId] = LoadState.success(result.data!);
    } else {
      _messagesByPairId[pairId] = LoadState.error(
        result.errorMessage ?? '메시지를 불러오지 못했습니다.',
      );
    }
    notifyListeners();
  }

  /// `POST /matching/chats/:pairId/messages`
  Future<bool> sendMessage(String pairId, String content) async {
    final result = await _repository.sendMessage(pairId, content);
    if (!result.success || result.data == null) return false;
    final current = _messagesByPairId[pairId]?.data ?? [];
    _messagesByPairId[pairId] = LoadState.success([...current, result.data!]);
    notifyListeners();
    return true;
  }

  void _updatePairInState(MatchingPairModel updated) {
    final current = _pairsState.data;
    if (current == null) return;
    final index = current.indexWhere((p) => p.id == updated.id);
    if (index == -1) return;
    final list = List<MatchingPairModel>.from(current);
    list[index] = updated;
    _pairsState = LoadState.success(list);
  }
}
