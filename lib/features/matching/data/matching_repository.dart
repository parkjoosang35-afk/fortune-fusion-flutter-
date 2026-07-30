import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/api/api_result.dart';
import '../../../core/auth/auth_token_store.dart';
import '../../../core/config/env_config.dart';
import '../domain/matching_model.dart';

/// 06§4.6 `/v1/matching` 대응 Repository — admin_web 공개 API
/// (`/api/public/matching/*`)를 호출한다. [방법 A] 로그인 시스템이 아직 없어
/// 테스트 유저(userId=1)를 고정으로 사용한다(wallet_repository.dart와 동일 패턴).
class MatchingRepository {
  static String get _base => '${EnvConfig.adminApiBaseUrl}/api/public/matching';

  Future<ApiResult<MatchingProfileModel>> saveProfile({
    required bool isPublic,
    required String introText,
    required List<String> preferences,
  }) async {
    final userId = await AuthTokenStore.getCurrentUserId();
    final uri = Uri.parse('$_base/profile');
    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              'isPublic': isPublic,
              'introText': introText,
              'preferences': preferences,
            }),
          )
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        return ApiResult.fail(decoded['error'] as String? ?? '프로필 저장에 실패했습니다.');
      }
      return ApiResult.ok(
        _profileFromJson(decoded['data'] as Map<String, dynamic>),
      );
    } catch (e) {
      debugPrint('[MatchingRepository] [saveProfile] 예외 -> $e');
      return ApiResult.fail('프로필 저장 중 오류가 발생했습니다: $e');
    }
  }

  Future<ApiResult<MatchingProfileModel?>> getMyProfile() async {
    final userId = await AuthTokenStore.getCurrentUserId();
    final uri = Uri.parse('$_base/profile?userId=$userId');
    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        return ApiResult.fail(
          decoded['error'] as String? ?? '프로필을 불러오지 못했습니다.',
        );
      }
      final data = decoded['data'];
      if (data == null) return ApiResult.ok(null);
      return ApiResult.ok(_profileFromJson(data as Map<String, dynamic>));
    } catch (e) {
      debugPrint('[MatchingRepository] [getMyProfile] 예외 -> $e');
      return ApiResult.fail('프로필을 불러오지 못했습니다: $e');
    }
  }

  Future<ApiResult<List<MatchingCandidateModel>>> getRecommendations() async {
    final userId = await AuthTokenStore.getCurrentUserId();
    final uri = Uri.parse('$_base/recommendations?userId=$userId');
    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        return ApiResult.fail(
          decoded['error'] as String? ?? '추천 대상을 불러오지 못했습니다.',
        );
      }
      final list = (decoded['data'] as List<dynamic>)
          .map((e) => _candidateFromJson(e as Map<String, dynamic>))
          .toList();
      return ApiResult.ok(list);
    } catch (e) {
      debugPrint('[MatchingRepository] [getRecommendations] 예외 -> $e');
      return ApiResult.fail('추천 대상을 불러오지 못했습니다: $e');
    }
  }

  /// 좋아요 - 서버가 상호확인 시 즉시 matching_pairs를 active로 생성한다
  /// (Mock의 pendingAccept 개념은 실API에서 사용하지 않음 - 설계결정 참조).
  ///
  /// [3단계 - 복주머니 소비: 운명의 동행] admin_web이 point_policies.matching_like
  /// 정책에 따라 관심표시 1건당 복주머니를 차감하고, 차감 후 잔액(balanceAfter)을
  /// 함께 내려준다(정책이 없으면 무료라 balanceAfter=null). 호출부가 WalletProvider의
  /// 잔액 캐시를 서버 결과값으로 즉시 동기화할 수 있도록 amulet_repository.purchase()와
  /// 동일한 "서버가 먼저 처리한 결과를 클라이언트가 반영만" 패턴을 따른다.
  Future<ApiResult<({bool matched, int? balanceAfter})>> like(
    String targetUserId,
  ) async {
    final userId = await AuthTokenStore.getCurrentUserId();
    final uri = Uri.parse('$_base/like');
    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'userId': userId, 'targetUserId': targetUserId}),
          )
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        return ApiResult.fail(decoded['error'] as String? ?? '좋아요 처리에 실패했습니다.');
      }
      return ApiResult.ok((
        matched: decoded['data'] as bool? ?? false,
        balanceAfter: (decoded['balanceAfter'] as num?)?.toInt(),
      ));
    } catch (e) {
      debugPrint('[MatchingRepository] [like] 예외 -> $e');
      return ApiResult.fail('좋아요 처리 중 오류가 발생했습니다: $e');
    }
  }

  /// UI에서 미사용(코드상 존재하나 호출부 없음) - like()가 상호확인을 자동 처리.
  Future<ApiResult<MatchingPairModel>> requestMatch(String targetUserId) async {
    return ApiResult.fail('지원하지 않는 기능입니다.');
  }

  Future<ApiResult<MatchingPairModel>> acceptPair(String pairId) async {
    final userId = await AuthTokenStore.getCurrentUserId();
    final uri = Uri.parse('$_base/pairs/$pairId/accept');
    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'userId': userId}),
          )
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        return ApiResult.fail(decoded['error'] as String? ?? '매칭을 찾을 수 없습니다.');
      }
      return ApiResult.ok(
        _pairFromJson(decoded['data'] as Map<String, dynamic>),
      );
    } catch (e) {
      debugPrint('[MatchingRepository] [acceptPair] 예외 -> $e');
      return ApiResult.fail('매칭 수락 중 오류가 발생했습니다: $e');
    }
  }

  Future<ApiResult<MatchingPairModel>> endPair(
    String pairId, {
    String? reason,
  }) async {
    final userId = await AuthTokenStore.getCurrentUserId();
    final uri = Uri.parse('$_base/pairs/$pairId/end');
    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'userId': userId, 'reason': reason}),
          )
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        return ApiResult.fail(decoded['error'] as String? ?? '매칭을 찾을 수 없습니다.');
      }
      return ApiResult.ok(
        _pairFromJson(decoded['data'] as Map<String, dynamic>),
      );
    } catch (e) {
      debugPrint('[MatchingRepository] [endPair] 예외 -> $e');
      return ApiResult.fail('매칭 종료 중 오류가 발생했습니다: $e');
    }
  }

  Future<ApiResult<List<MatchingPairModel>>> getPairs() async {
    final userId = await AuthTokenStore.getCurrentUserId();
    final uri = Uri.parse('$_base/pairs?userId=$userId');
    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        return ApiResult.fail(
          decoded['error'] as String? ?? '매칭 목록을 불러오지 못했습니다.',
        );
      }
      final list = (decoded['data'] as List<dynamic>)
          .map((e) => _pairFromJson(e as Map<String, dynamic>))
          .toList();
      return ApiResult.ok(list);
    } catch (e) {
      debugPrint('[MatchingRepository] [getPairs] 예외 -> $e');
      return ApiResult.fail('매칭 목록을 불러오지 못했습니다: $e');
    }
  }

  Future<ApiResult<void>> report(
    MatchingReportTargetType targetType,
    String targetId,
    String reason,
  ) async {
    final userId = await AuthTokenStore.getCurrentUserId();
    if (reason.trim().isEmpty) return ApiResult.fail('신고 사유를 입력해 주세요.');
    final uri = Uri.parse('$_base/report');
    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              'targetType': targetType.name,
              'targetId': targetId,
              'reason': reason.trim(),
            }),
          )
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        return ApiResult.fail(decoded['error'] as String? ?? '신고 접수에 실패했습니다.');
      }
      return ApiResult.ok(null);
    } catch (e) {
      debugPrint('[MatchingRepository] [report] 예외 -> $e');
      return ApiResult.fail('신고 접수 중 오류가 발생했습니다: $e');
    }
  }

  Future<ApiResult<List<ChatMessageModel>>> getMessages(String pairId) async {
    final userId = await AuthTokenStore.getCurrentUserId();
    final uri = Uri.parse('$_base/chats/$pairId/messages?userId=$userId');
    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        return ApiResult.fail(
          decoded['error'] as String? ?? '메시지를 불러오지 못했습니다.',
        );
      }
      final list = (decoded['data'] as List<dynamic>)
          .map((e) => _messageFromJson(e as Map<String, dynamic>))
          .toList();
      return ApiResult.ok(list);
    } catch (e) {
      debugPrint('[MatchingRepository] [getMessages] 예외 -> $e');
      return ApiResult.fail('메시지를 불러오지 못했습니다: $e');
    }
  }

  Future<ApiResult<ChatMessageModel>> sendMessage(
    String pairId,
    String content,
  ) async {
    final userId = await AuthTokenStore.getCurrentUserId();
    if (content.trim().isEmpty) return ApiResult.fail('메시지를 입력해 주세요.');
    final uri = Uri.parse('$_base/chats/$pairId/messages');
    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'userId': userId, 'content': content.trim()}),
          )
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        return ApiResult.fail(decoded['error'] as String? ?? '메시지 전송에 실패했습니다.');
      }
      return ApiResult.ok(
        _messageFromJson(decoded['data'] as Map<String, dynamic>),
      );
    } catch (e) {
      debugPrint('[MatchingRepository] [sendMessage] 예외 -> $e');
      return ApiResult.fail('메시지 전송 중 오류가 발생했습니다: $e');
    }
  }

  MatchingProfileModel _profileFromJson(Map<String, dynamic> j) {
    return MatchingProfileModel(
      userId: j['userId'] as String,
      isPublic: j['isPublic'] as bool? ?? true,
      introText: j['introText'] as String? ?? '',
      preferences: (j['preferences'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList(),
    );
  }

  MatchingCandidateModel _candidateFromJson(Map<String, dynamic> j) {
    return MatchingCandidateModel(
      userId: j['userId'] as String,
      nickname: j['nickname'] as String,
      age: j['age'] as int,
      introText: j['introText'] as String? ?? '',
      preferences: (j['preferences'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList(),
      emoji: j['emoji'] as String? ?? '🙂',
      likedByMe: j['likedByMe'] as bool? ?? false,
    );
  }

  MatchingPairModel _pairFromJson(Map<String, dynamic> j) {
    return MatchingPairModel(
      id: j['id'] as String,
      partnerUserId: j['partnerUserId'] as String,
      partnerNickname: j['partnerNickname'] as String,
      partnerEmoji: j['partnerEmoji'] as String? ?? '🙂',
      // 서버는 pendingAccept를 절대 반환하지 않음(설계결정 - 서버 like API 참조)
      status: (j['status'] as String) == 'unmatched'
          ? MatchingPairStatus.unmatched
          : MatchingPairStatus.active,
      matchedAt: DateTime.parse(j['matchedAt'] as String),
      lastMessage: j['lastMessage'] as String?,
    );
  }

  ChatMessageModel _messageFromJson(Map<String, dynamic> j) {
    return ChatMessageModel(
      id: j['id'] as String,
      pairId: j['pairId'] as String,
      isMine: j['isMine'] as bool? ?? false,
      content: j['content'] as String,
      sentAt: DateTime.parse(j['sentAt'] as String),
    );
  }
}
