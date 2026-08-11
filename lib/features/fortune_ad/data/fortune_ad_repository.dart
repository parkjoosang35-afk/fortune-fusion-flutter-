import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/api/api_result.dart';
import '../../../core/auth/auth_token_store.dart';
import '../../../core/config/env_config.dart';
import '../domain/fortune_ad_model.dart';

/// [신통방통 복주머니 광고 적립 시스템] admin_web 공개 API
/// (`GET /api/ads/fortune`, `POST /api/ads/{adId}/start`,
/// `POST /api/ads/{adId}/complete`, `GET /api/ads/{adId}/today-status`)를
/// 호출한다. WalletRepository와 동일하게 userId는 AuthTokenStore(폴백 1)를 사용한다.
class FortuneAdRepository {
  /// 노출 가능한 광고 목록 조회.
  Future<ApiResult<List<FortuneAdModel>>> getAds() async {
    final userId = await AuthTokenStore.getCurrentUserId();
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/ads/fortune',
    ).replace(queryParameters: {'userId': '$userId'});
    debugPrint('[FortuneAdRepository] [list] 요청 -> $uri');

    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '광고 목록을 불러오지 못했습니다.';
        debugPrint('[FortuneAdRepository] [list] 실패 -> $error');
        return ApiResult.fail(error);
      }
      final list = (decoded['data'] as List<dynamic>? ?? [])
          .map((e) => FortuneAdModel.fromJson(e as Map<String, dynamic>))
          .toList();
      return ApiResult.ok(list);
    } catch (e) {
      debugPrint('[FortuneAdRepository] [list] 예외 -> $e');
      return ApiResult.fail('광고 목록을 불러오지 못했습니다: $e');
    }
  }

  /// 광고 1건의 오늘 시청 현황 재조회(다이얼로그 열기 전 사전 확인용).
  Future<ApiResult<FortuneAdModel>> getTodayStatus(FortuneAdModel ad) async {
    final userId = await AuthTokenStore.getCurrentUserId();
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/ads/${ad.id}/today-status',
    ).replace(queryParameters: {'userId': '$userId'});

    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '현황 조회에 실패했습니다.';
        return ApiResult.fail(error);
      }
      final data = decoded['data'] as Map<String, dynamic>;
      return ApiResult.ok(
        ad.copyWith(
          todayWatchedCount: data['todayWatchedCount'] as int? ?? ad.todayWatchedCount,
          todayRemainingCount: data['todayRemainingCount'] as int? ?? ad.todayRemainingCount,
          watchable: data['watchable'] as bool? ?? ad.watchable,
        ),
      );
    } catch (e) {
      debugPrint('[FortuneAdRepository] [today-status] 예외 -> $e');
      return ApiResult.fail('현황 조회 중 오류가 발생했습니다: $e');
    }
  }

  /// 시청 시작 — 서버가 자격을 재확인하고 PENDING 세션을 발급한다.
  Future<ApiResult<FortuneAdWatchSession>> start(int adId) async {
    final userId = await AuthTokenStore.getCurrentUserId();
    final uri = Uri.parse('${EnvConfig.adminApiBaseUrl}/api/ads/$adId/start');
    debugPrint('[FortuneAdRepository] [start] 요청 -> adId=$adId, userId=$userId');

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
        final error = decoded['error'] as String? ?? '지금은 시청할 수 없습니다.';
        debugPrint('[FortuneAdRepository] [start] 실패 -> $error');
        return ApiResult.fail(error, code: decoded['reason'] as String?);
      }
      final session = FortuneAdWatchSession.fromJson(
        decoded['data'] as Map<String, dynamic>,
      );
      return ApiResult.ok(session);
    } catch (e) {
      debugPrint('[FortuneAdRepository] [start] 예외 -> $e');
      return ApiResult.fail('시청 시작 중 오류가 발생했습니다: $e');
    }
  }

  /// 시청 완료 — 서버가 최종 검증 후 복주머니를 지급한다(서버 최종 지급 원칙).
  /// 동일 [sessionId]로 재호출해도 서버가 idempotency로 중복 지급을 막는다.
  Future<ApiResult<FortuneAdRewardResult>> complete({
    required int adId,
    required String sessionId,
    int? watchSeconds,
  }) async {
    final userId = await AuthTokenStore.getCurrentUserId();
    final uri = Uri.parse('${EnvConfig.adminApiBaseUrl}/api/ads/$adId/complete');
    debugPrint(
      '[FortuneAdRepository] [complete] 요청 -> adId=$adId, sessionId=$sessionId',
    );

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              'sessionId': sessionId,
              if (watchSeconds != null) 'watchSeconds': watchSeconds,
            }),
          )
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '보상 지급에 실패했습니다.';
        debugPrint('[FortuneAdRepository] [complete] 실패 -> $error');
        return ApiResult.fail(error, code: decoded['reason'] as String?);
      }
      final result = FortuneAdRewardResult.fromJson(
        decoded,
        idempotent: decoded['idempotent'] as bool? ?? false,
      );
      return ApiResult.ok(result);
    } catch (e) {
      debugPrint('[FortuneAdRepository] [complete] 예외 -> $e');
      return ApiResult.fail('보상 지급 처리 중 오류가 발생했습니다: $e');
    }
  }
}
